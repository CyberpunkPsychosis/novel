import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { verifyAppleIdentityToken } from "../auth/apple.js";
import { serializeUser } from "../serialize.js";
import { addCredits, notify } from "../platform.js";

// 新用户落地：注册送墨滴 + 欢迎通知（服务端发，跨设备一致）。
async function welcomeNewUser(userId: string) {
  await addCredits(userId, 100, "signup", "欢迎加入书艺之阁");
  await notify(userId, "system", "欢迎来到书艺之阁，记得每天来签到领墨滴。");
}

// 生成一个不冲突的 handle。
async function uniqueHandle(base: string): Promise<string> {
  const clean = (base || "reader").toLowerCase().replace(/[^a-z0-9_]/g, "") || "reader";
  let h = clean;
  let n = 0;
  while (await prisma.user.findUnique({ where: { handle: h } })) {
    n += 1;
    h = `${clean}${n}`;
  }
  return h;
}

export async function authRoutes(app: FastifyInstance) {
  // POST /auth/apple  { identityToken, penName? } -> { token, user }
  app.post("/auth/apple", async (req, reply) => {
    const body = (req.body ?? {}) as { identityToken?: string; penName?: string };
    if (!body.identityToken) return reply.code(400).send({ error: "缺少 identityToken" });

    const bundleId = process.env.APPLE_BUNDLE_ID || "com.yumeng.xumo";
    let id;
    try {
      id = await verifyAppleIdentityToken(body.identityToken, bundleId);
    } catch (e) {
      req.log.warn({ e }, "apple token 验证失败");
      return reply.code(401).send({ error: "Apple 登录校验失败" });
    }

    let user = await prisma.user.findUnique({ where: { appleSub: id.sub } });
    if (!user) {
      const penName = (body.penName || "").trim() || `读者${id.sub.slice(0, 4)}`;
      const handle = await uniqueHandle(body.penName || `reader${id.sub.slice(0, 6)}`);
      user = await prisma.user.create({
        data: { appleSub: id.sub, email: id.email ?? null, handle, penName },
      });
      await welcomeNewUser(user.id);
    }

    const token = app.signToken(user.id);
    return { token, user: serializeUser(user) };
  });

  // 开发期临时邮箱登录通道（没有 Apple 开发者账号时用）。DEV_EMAIL_LOGIN=false 时关闭。
  // POST /auth/dev  { email, penName? } -> { token, user }
  app.post("/auth/dev", async (req, reply) => {
    if (process.env.DEV_EMAIL_LOGIN !== "true") {
      return reply.code(404).send({ error: "not found" });
    }
    const body = (req.body ?? {}) as { email?: string; penName?: string };
    const email = (body.email || "").trim().toLowerCase();
    if (!email) return reply.code(400).send({ error: "缺少 email" });

    let user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      const penName = (body.penName || "").trim() || email.split("@")[0];
      const handle = await uniqueHandle(body.penName || email.split("@")[0]);
      user = await prisma.user.create({ data: { email, handle, penName } });
      await welcomeNewUser(user.id);
    }

    const token = app.signToken(user.id);
    return { token, user: serializeUser(user) };
  });

  // GET /me -> User
  app.get("/me", { preHandler: [app.authenticate] }, async (req, reply) => {
    const user = await prisma.user.findUnique({ where: { id: req.userId! } });
    if (!user) return reply.code(404).send({ error: "用户不存在" });
    return serializeUser(user);
  });
}
