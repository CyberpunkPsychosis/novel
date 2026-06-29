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

  // POST /me/checkin { day? } -> { award, streak }（每日一次）
  // day 由客户端按其本地时区传入；用条件更新做原子化，防并发双发奖励。
  app.post("/me/checkin", { preHandler: [app.authenticate] }, async (req) => {
    const bodyDay = String((req.body as { day?: string })?.day ?? "");
    const today = /^\d{4}-\d{2}-\d{2}$/.test(bodyDay) ? bodyDay : dayKey(new Date());
    const cur = await prisma.dailyCheckin.findUnique({ where: { userId: req.userId! } });
    if (cur?.lastDate === today) return { award: 0, streak: cur.streak };

    const yesterday = dayKey(new Date(new Date(`${today}T00:00:00Z`).getTime() - 86400_000));
    const streak = cur?.lastDate === yesterday ? cur.streak + 1 : 1;

    if (cur) {
      // 原子：仅当 lastDate 仍是旧值时才更新成功，避免并发双发。
      const r = await prisma.dailyCheckin.updateMany({
        where: { userId: req.userId!, lastDate: cur.lastDate },
        data: { lastDate: today, streak },
      });
      if (r.count === 0) return { award: 0, streak };
    } else {
      try {
        await prisma.dailyCheckin.create({ data: { userId: req.userId!, lastDate: today, streak } });
      } catch {
        return { award: 0, streak: 1 }; // 并发下另一个请求已创建
      }
    }
    const award = 10 + Math.min(streak, 7) * 2;
    await addCredits(req.userId!, award, "checkin", `连续签到 ${streak} 天`);
    await notify(req.userId!, "checkin", `签到成功 +${award} 墨滴（连续 ${streak} 天）`);
    return { award, streak };
  });

  // 注：原 POST /me/credits/buy（无校验直接发币）已删除，仅保留 StoreKit 的 /me/credits/purchase。
}
