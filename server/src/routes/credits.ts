import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeCheckin, serializeCreditTxn } from "../serialize.js";
import { addCredits, balanceOf, dayKey, notify } from "../platform.js";

export async function creditRoutes(app: FastifyInstance) {
  // GET /me/credits -> { balance, txns:[...], checkin:{lastDate,streak} }
  app.get("/me/credits", { preHandler: [app.authenticate] }, async (req) => {
    const [txns, checkin, balance] = await Promise.all([
      prisma.creditTxn.findMany({ where: { userId: req.userId! }, orderBy: { createdAt: "desc" } }),
      prisma.dailyCheckin.findUnique({ where: { userId: req.userId! } }),
      balanceOf(req.userId!),
    ]);
    return { balance, txns: txns.map(serializeCreditTxn), checkin: serializeCheckin(checkin) };
  });

  // POST /me/checkin -> { award, streak }（每日一次）
  app.post("/me/checkin", { preHandler: [app.authenticate] }, async (req) => {
    const today = dayKey(new Date());
    const cur = await prisma.dailyCheckin.findUnique({ where: { userId: req.userId! } });
    if (cur?.lastDate === today) return { award: 0, streak: cur.streak };

    const yesterday = dayKey(new Date(Date.now() - 86400_000));
    const streak = cur?.lastDate === yesterday ? cur.streak + 1 : 1;
    await prisma.dailyCheckin.upsert({
      where: { userId: req.userId! },
      create: { userId: req.userId!, lastDate: today, streak },
      update: { lastDate: today, streak },
    });
    const award = 10 + Math.min(streak, 7) * 2;
    await addCredits(req.userId!, award, "checkin", `连续签到 ${streak} 天`);
    await notify(req.userId!, "checkin", `签到成功 +${award} 墨滴（连续 ${streak} 天）`);
    return { award, streak };
  });

  // POST /me/credits/buy { amount } -> { balance }（里程碑3 换 StoreKit）
  app.post("/me/credits/buy", { preHandler: [app.authenticate] }, async (req, reply) => {
    const amount = Number((req.body as { amount?: number })?.amount ?? 0);
    if (amount <= 0) return reply.code(400).send({ error: "金额非法" });
    await addCredits(req.userId!, amount, "buy", `购买 ${amount} 墨滴`);
    return { balance: await balanceOf(req.userId!) };
  });
}
