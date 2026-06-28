import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { relativeTime } from "../platform.js";

async function uid(req: any): Promise<string | null> {
  try { return ((await req.jwtVerify()) as { uid: string }).uid; } catch { return null; }
}

export async function socialRoutes(app: FastifyInstance) {
  // ===== 收藏 =====
  app.get("/me/favorites", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.favorite.findMany({ where: { userId: req.userId! } });
    return rows.map((r) => r.bookId);
  });

  // POST /books/:id/favorite -> { favorited }（切换）
  app.post<{ Params: { id: string } }>(
    "/books/:id/favorite", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      const existing = await prisma.favorite.findUnique({
        where: { userId_bookId: { userId: req.userId!, bookId: book.id } },
      });
      if (existing) {
        await prisma.favorite.delete({ where: { id: existing.id } });
        return { favorited: false };
      }
      await prisma.favorite.create({ data: { userId: req.userId!, bookId: book.id } });
      return { favorited: true };
    });

  // ===== 话题 =====
  // GET /topics -> [{id,title,author,avatarColorHex,replyCount,meta}]（按回帖热度+时间）
  app.get("/topics", async () => {
    const rows = await prisma.topic.findMany({
      include: { user: true, _count: { select: { replies: true } } },
      orderBy: { createdAt: "desc" },
    });
    return rows
      .map((t) => ({
        id: t.id, title: t.title, author: t.user.penName,
        avatarColorHex: t.user.avatarColorHex,
        replyCount: t._count.replies,
        meta: `${relativeTime(t.createdAt)} · ${t._count.replies} 回帖`,
      }))
      .sort((a, b) => b.replyCount - a.replyCount);
  });

  app.post("/topics", { preHandler: [app.authenticate] }, async (req, reply) => {
    const b = (req.body ?? {}) as { title?: string; body?: string };
    const title = (b.title ?? "").trim();
    if (!title) return reply.code(400).send({ error: "话题标题不能为空" });
    const t = await prisma.topic.create({
      data: { userId: req.userId!, title, body: (b.body ?? "").trim() },
      include: { user: true },
    });
    return { id: t.id, title: t.title, author: t.user.penName,
             avatarColorHex: t.user.avatarColorHex, replyCount: 0,
             meta: `刚刚 · 0 回帖` };
  });

  // GET /topics/:id -> { id,title,body,author,date, replies:[...] }
  app.get<{ Params: { id: string } }>("/topics/:id", async (req, reply) => {
    const t = await prisma.topic.findUnique({
      where: { id: req.params.id },
      include: { user: true, replies: { include: { user: true }, orderBy: { createdAt: "asc" } } },
    });
    if (!t) return reply.code(404).send({ error: "话题不存在" });
    return {
      id: t.id, title: t.title, body: t.body,
      author: t.user.penName, avatarColorHex: t.user.avatarColorHex, date: t.createdAt,
      replies: t.replies.map((r) => ({
        id: r.id, author: r.user.penName, avatarColorHex: r.user.avatarColorHex,
        text: r.text, date: r.createdAt,
      })),
    };
  });

  app.post<{ Params: { id: string } }>(
    "/topics/:id/replies", { preHandler: [app.authenticate] }, async (req, reply) => {
      const text = String((req.body as { text?: string })?.text ?? "").trim();
      if (!text) return reply.code(400).send({ error: "回复不能为空" });
      const topic = await prisma.topic.findUnique({ where: { id: req.params.id } });
      if (!topic) return reply.code(404).send({ error: "话题不存在" });
      const r = await prisma.topicReply.create({
        data: { topicId: topic.id, userId: req.userId!, text },
        include: { user: true },
      });
      return { id: r.id, author: r.user.penName, avatarColorHex: r.user.avatarColorHex,
               text: r.text, date: r.createdAt };
    });

  // ===== 俱乐部 =====
  // GET /clubs -> [{id,name,intro,memberCount,joinedByMe}]
  app.get("/clubs", async (req) => {
    const me = await uid(req);
    const rows = await prisma.club.findMany({
      include: { _count: { select: { members: true } },
                 members: me ? { where: { userId: me } } : false },
      orderBy: { createdAt: "asc" },
    });
    return rows.map((c) => ({
      id: c.id, name: c.name, intro: c.intro,
      memberCount: c._count.members,
      joinedByMe: me ? (c as any).members.length > 0 : false,
    }));
  });

  // POST /clubs/:id/join -> { joined, memberCount }（切换）
  app.post<{ Params: { id: string } }>(
    "/clubs/:id/join", { preHandler: [app.authenticate] }, async (req, reply) => {
      const club = await prisma.club.findUnique({ where: { id: req.params.id } });
      if (!club) return reply.code(404).send({ error: "俱乐部不存在" });
      const existing = await prisma.clubMember.findUnique({
        where: { userId_clubId: { userId: req.userId!, clubId: club.id } },
      });
      let joined: boolean;
      if (existing) { await prisma.clubMember.delete({ where: { id: existing.id } }); joined = false; }
      else { await prisma.clubMember.create({ data: { userId: req.userId!, clubId: club.id } }); joined = true; }
      const memberCount = await prisma.clubMember.count({ where: { clubId: club.id } });
      return { joined, memberCount };
    });
}
