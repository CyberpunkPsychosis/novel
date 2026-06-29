import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeBook } from "../serialize.js";
import { addCredits, balanceOf, logActivity } from "../platform.js";

// StoreKit 商品 → 墨滴 映射（与 iOS .storekit 配置一致）。
const PRODUCTS: Record<string, number> = {
  "com.example.xumo.molzi.60": 60,
  "com.example.xumo.molzi.330": 330,
  "com.example.xumo.molzi.800": 800,
  "com.example.xumo.molzi.1600": 1600,
};

async function optUid(req: any): Promise<string | null> {
  try { return ((await req.jwtVerify()) as { uid: string }).uid; } catch { return null; }
}

export async function discoverRoutes(app: FastifyInstance) {
  // GET /rankings -> [Book]  按综合热度排序（fork数 *3 + 解锁数 *2 + 评分均值 *2 + 评分数）
  app.get("/rankings", async (req) => {
    const me = await optUid(req);
    const books = await prisma.book.findMany({
      where: { moderationStatus: "approved" },
      include: { chapters: true, ratings: true, unlocks: true },
    });
    const forkCount = new Map<string, number>();
    for (const b of books) {
      if (b.forkOf) forkCount.set(b.forkOf, (forkCount.get(b.forkOf) ?? 0) + 1);
    }
    const scored = books.map((b) => {
      const avg = b.ratings.length
        ? b.ratings.reduce((s, r) => s + r.value, 0) / b.ratings.length : 0;
      const hot = (forkCount.get(b.id) ?? 0) * 3 + b.unlocks.length * 2 + avg * 2 + b.ratings.length;
      return { b, hot };
    });
    scored.sort((x, y) => y.hot - x.hot);
    return scored.map((s) => serializeBook(s.b, me));
  });

  // POST /books/:id/rating { value:1..5 } -> { ratingAvg, ratingCount, mine }
  app.post<{ Params: { id: string } }>(
    "/books/:id/rating", { preHandler: [app.authenticate] }, async (req, reply) => {
      const value = Math.round(Number((req.body as { value?: number })?.value ?? 0));
      if (value < 1 || value > 5) return reply.code(400).send({ error: "评分需 1..5" });
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });

      // 是否首次评分（改分不再刷活动流）
      const prior = await prisma.rating.findUnique({
        where: { userId_bookId: { userId: req.userId!, bookId: book.id } },
      });
      await prisma.rating.upsert({
        where: { userId_bookId: { userId: req.userId!, bookId: book.id } },
        create: { userId: req.userId!, bookId: book.id, value },
        update: { value },
      });
      if (!prior) {
        await logActivity(req.userId!, "rate", `给《${book.title}》打了 ${value} 星`, book.id);
      }
      const ratings = await prisma.rating.findMany({ where: { bookId: book.id } });
      const count = ratings.length;
      const avg = count ? ratings.reduce((s, r) => s + r.value, 0) / count : 0;
      return { ratingAvg: Math.round(avg * 10) / 10, ratingCount: count, mine: value };
    });

  // DELETE /books/:id/rating  取消我的评分 -> { ratingAvg, ratingCount, mine:0 }
  app.delete<{ Params: { id: string } }>(
    "/books/:id/rating", { preHandler: [app.authenticate] }, async (req) => {
      await prisma.rating.deleteMany({ where: { userId: req.userId!, bookId: req.params.id } });
      const ratings = await prisma.rating.findMany({ where: { bookId: req.params.id } });
      const count = ratings.length;
      const avg = count ? ratings.reduce((s, r) => s + r.value, 0) / count : 0;
      return { ratingAvg: Math.round(avg * 10) / 10, ratingCount: count, mine: 0 };
    });

  // GET /me/ratings -> { bookId: value }  我打过的分
  app.get("/me/ratings", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.rating.findMany({ where: { userId: req.userId! } });
    const out: Record<string, number> = {};
    for (const r of rows) out[r.bookId] = r.value;
    return out;
  });

  // POST /me/credits/purchase { productId, transactionId } -> { balance, credited }
  // StoreKit 客户端校验交易后调用；transactionId 幂等，避免重复入账。
  app.post("/me/credits/purchase", { preHandler: [app.authenticate] }, async (req, reply) => {
    const b = (req.body ?? {}) as { productId?: string; transactionId?: string };
    if (!b.productId || !b.transactionId) {
      return reply.code(400).send({ error: "缺少 productId / transactionId" });
    }
    const credits = PRODUCTS[b.productId];
    if (!credits) return reply.code(400).send({ error: "未知商品" });

    // 幂等：同一交易已入账则直接返回当前余额。
    const existing = await prisma.purchase.findUnique({ where: { transactionId: b.transactionId } });
    if (existing) {
      return { balance: await balanceOf(req.userId!), credited: 0 };
    }
    await prisma.purchase.create({
      data: { userId: req.userId!, transactionId: b.transactionId, productId: b.productId, credits },
    });
    await addCredits(req.userId!, credits, "buy", `充值 ${credits} 墨滴`);
    return { balance: await balanceOf(req.userId!), credited: credits };
  });
}
