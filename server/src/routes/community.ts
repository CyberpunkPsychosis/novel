import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { logActivity, notify, relativeTime } from "../platform.js";

const typeLabel: Record<string, string> = {
  publish: "发布", fork: "改编", rate: "评分", review: "书评",
};

export async function communityRoutes(app: FastifyInstance) {
  // POST /books/:id/reviews { text } -> Review
  app.post<{ Params: { id: string } }>(
    "/books/:id/reviews", { preHandler: [app.authenticate] }, async (req, reply) => {
      const me = await prisma.user.findUnique({ where: { id: req.userId! } });
      if (!me) return reply.code(401).send({ error: "未登录" });
      const text = String((req.body as { text?: string })?.text ?? "").trim();
      if (!text) return reply.code(400).send({ error: "书评不能为空" });
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });

      // 一书一条书评（可改）；仅首次记活动，防刷屏。
      const prior = await prisma.review.findUnique({
        where: { userId_bookId: { userId: me.id, bookId: book.id } },
      });
      const r = await prisma.review.upsert({
        where: { userId_bookId: { userId: me.id, bookId: book.id } },
        create: { userId: me.id, bookId: book.id, text },
        update: { text },
        include: { user: true, likes: true },
      });
      if (!prior) {
        await logActivity(me.id, "review", `评论《${book.title}》：${text.slice(0, 20)}`, book.id);
      }
      return serializeReview(r, me.id);
    });

  // GET /books/:id/reviews -> [Review]（含作者、点赞数、我是否赞过）
  app.get<{ Params: { id: string } }>("/books/:id/reviews", async (req) => {
    const me = await currentUserId(app, req);
    const rows = await prisma.review.findMany({
      where: { bookId: req.params.id },
      include: { user: true, likes: true },
      orderBy: { createdAt: "desc" },
    });
    return rows.map((r) => serializeReview(r, me));
  });

  // GET /me/reviews -> [Review]（我写的）
  app.get("/me/reviews", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.review.findMany({
      where: { userId: req.userId! },
      include: { user: true, likes: true },
      orderBy: { createdAt: "desc" },
    });
    return rows.map((r) => serializeReview(r, req.userId!));
  });

  // POST /reviews/:id/like -> { liked, likeCount }（切换）
  app.post<{ Params: { id: string } }>(
    "/reviews/:id/like", { preHandler: [app.authenticate] }, async (req, reply) => {
      const review = await prisma.review.findUnique({ where: { id: req.params.id }, include: { user: true } });
      if (!review) return reply.code(404).send({ error: "书评不存在" });
      const existing = await prisma.reviewLike.findUnique({
        where: { userId_reviewId: { userId: req.userId!, reviewId: review.id } },
      });
      let liked: boolean;
      if (existing) {
        await prisma.reviewLike.delete({ where: { id: existing.id } });
        liked = false;
      } else {
        await prisma.reviewLike.create({ data: { userId: req.userId!, reviewId: review.id } });
        liked = true;
        if (review.userId !== req.userId) {
          const me = await prisma.user.findUnique({ where: { id: req.userId! } });
          await notify(review.userId, "system", `${me?.penName ?? "有人"} 赞了你的书评`, me?.penName ?? "");
        }
      }
      const likeCount = await prisma.reviewLike.count({ where: { reviewId: review.id } });
      return { liked, likeCount };
    });

  // DELETE /reviews/:id （删自己的书评）
  app.delete<{ Params: { id: string } }>(
    "/reviews/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const r = await prisma.review.findUnique({ where: { id: req.params.id } });
      if (!r) return reply.code(404).send({ error: "书评不存在" });
      if (r.userId !== req.userId) return reply.code(403).send({ error: "只能删自己的书评" });
      await prisma.review.delete({ where: { id: r.id } });
      return { ok: true };
    });

  // GET /feed -> [{who, avatarColorHex, avatarUrl, text, meta, bookId}]  全站近期动态
  app.get("/feed", async () => {
    const rows = await prisma.activity.findMany({
      include: { user: true },
      orderBy: { createdAt: "desc" },
      take: 80,
    });
    // 过滤掉指向"未通过审核"书的活动（Activity 无 book 关系，故代码侧过滤）
    const bookIds = [...new Set(rows.map((a) => a.bookId).filter((x): x is string => !!x))];
    const rejected = new Set(
      (await prisma.book.findMany({
        where: { id: { in: bookIds }, moderationStatus: { not: "approved" } },
        select: { id: true },
      })).map((b) => b.id)
    );
    return rows
      .filter((a) => !a.bookId || !rejected.has(a.bookId))
      .slice(0, 40)
      .map((a) => ({
        id: a.id,
        who: a.user.penName,
        avatarColorHex: a.user.avatarColorHex,
        avatarUrl: a.user.avatarUrl ?? null,
        text: a.text,
        meta: `${relativeTime(a.createdAt)} · ${typeLabel[a.type] ?? a.type}`,
        bookId: a.bookId,
      }));
  });

  // GET /me/stats -> { creations, reviews, likesReceived }
  app.get("/me/stats", { preHandler: [app.authenticate] }, async (req) => {
    const [creations, reviews, likesReceived] = await Promise.all([
      prisma.book.count({ where: { ownerId: req.userId!, isUserCreated: true } }),
      prisma.review.count({ where: { userId: req.userId! } }),
      prisma.reviewLike.count({ where: { review: { userId: req.userId! } } }),
    ]);
    return { creations, reviews, likesReceived };
  });
}

// 没鉴权也允许读书评：尝试解析 token 拿 uid，失败返回 null。
async function currentUserId(app: FastifyInstance, req: any): Promise<string | null> {
  try {
    const d = (await req.jwtVerify()) as { uid: string };
    return d.uid;
  } catch {
    return null;
  }
}

function serializeReview(
  r: { id: string; text: string; createdAt: Date; bookId: string;
       user: { penName: string; avatarColorHex: string; avatarUrl?: string | null };
       likes: { userId: string }[] },
  meId: string | null
) {
  return {
    id: r.id,
    author: r.user.penName,
    avatarColorHex: r.user.avatarColorHex,
    avatarUrl: r.user.avatarUrl ?? null,
    bookID: r.bookId,
    text: r.text,
    date: r.createdAt,
    likeCount: r.likes.length,
    likedByMe: meId ? r.likes.some((l) => l.userId === meId) : false,
  };
}
