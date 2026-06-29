import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { relativeTime } from "../platform.js";

async function uid(req: any): Promise<string | null> {
  try { return ((await req.jwtVerify()) as { uid: string }).uid; } catch { return null; }
}

type TopicRow = {
  id: string; title: string; createdAt: Date;
  user: { penName: string; avatarColorHex: string; avatarUrl?: string | null };
  _count: { replies: number };
};
function serializeTopicItem(t: TopicRow) {
  return {
    id: t.id, title: t.title,
    author: t.user.penName, avatarColorHex: t.user.avatarColorHex, avatarUrl: t.user.avatarUrl ?? null,
    replyCount: t._count.replies,
    meta: `${relativeTime(t.createdAt)} · ${t._count.replies} 回帖`,
  };
}

export async function socialRoutes(app: FastifyInstance) {
  // ===== 书架：想读 / 在读 / 读过 =====
  app.get("/me/shelf", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.favorite.findMany({ where: { userId: req.userId! } });
    const out: Record<string, string> = {};
    for (const r of rows) out[r.bookId] = r.status;
    return out;
  });

  // PUT /books/:id/shelf { status: want|reading|read } -> { status }
  app.put<{ Params: { id: string } }>(
    "/books/:id/shelf", { preHandler: [app.authenticate] }, async (req, reply) => {
      const status = String((req.body as { status?: string })?.status ?? "");
      if (!["want", "reading", "read"].includes(status)) {
        return reply.code(400).send({ error: "status 必须是 want/reading/read" });
      }
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      await prisma.favorite.upsert({
        where: { userId_bookId: { userId: req.userId!, bookId: book.id } },
        create: { userId: req.userId!, bookId: book.id, status },
        update: { status },
      });
      return { status };
    });

  // DELETE /books/:id/shelf -> { ok }（移出书架）
  app.delete<{ Params: { id: string } }>(
    "/books/:id/shelf", { preHandler: [app.authenticate] }, async (req) => {
      await prisma.favorite.deleteMany({ where: { userId: req.userId!, bookId: req.params.id } });
      return { ok: true };
    });

  // ===== 全站话题（clubId = null）=====
  app.get("/topics", async () => {
    const rows = await prisma.topic.findMany({
      where: { clubId: null },
      include: { user: true, _count: { select: { replies: true } } },
      orderBy: { createdAt: "desc" },
    });
    return rows.map(serializeTopicItem).sort((a, b) => b.replyCount - a.replyCount);
  });

  app.post("/topics", { preHandler: [app.authenticate] }, async (req, reply) => {
    const b = (req.body ?? {}) as { title?: string; body?: string };
    const title = (b.title ?? "").trim();
    if (!title) return reply.code(400).send({ error: "话题标题不能为空" });
    const t = await prisma.topic.create({
      data: { userId: req.userId!, title, body: (b.body ?? "").trim() },
      include: { user: true, _count: { select: { replies: true } } },
    });
    return serializeTopicItem(t);
  });

  // GET /topics/:id -> { id,title,body,author,avatarUrl,date, replies:[...] }
  app.get<{ Params: { id: string } }>("/topics/:id", async (req, reply) => {
    const t = await prisma.topic.findUnique({
      where: { id: req.params.id },
      include: { user: true, replies: { include: { user: true }, orderBy: { createdAt: "asc" } } },
    });
    if (!t) return reply.code(404).send({ error: "话题不存在" });
    return {
      id: t.id, title: t.title, body: t.body,
      author: t.user.penName, avatarColorHex: t.user.avatarColorHex, avatarUrl: t.user.avatarUrl ?? null,
      date: t.createdAt,
      replies: t.replies.map((r) => ({
        id: r.id, author: r.user.penName, avatarColorHex: r.user.avatarColorHex,
        avatarUrl: r.user.avatarUrl ?? null, text: r.text, date: r.createdAt,
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
               avatarUrl: r.user.avatarUrl ?? null, text: r.text, date: r.createdAt };
    });

  // ===== 俱乐部 =====
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

  // GET /clubs/:id -> 详情（信息 + 成员 + 我是否加入）
  app.get<{ Params: { id: string } }>("/clubs/:id", async (req, reply) => {
    const me = await uid(req);
    const c = await prisma.club.findUnique({
      where: { id: req.params.id },
      include: { members: { include: { user: true }, take: 30, orderBy: { createdAt: "asc" } } },
    });
    if (!c) return reply.code(404).send({ error: "俱乐部不存在" });
    return {
      id: c.id, name: c.name, intro: c.intro,
      memberCount: c.members.length,
      joinedByMe: me ? c.members.some((m) => m.userId === me) : false,
      members: c.members.map((m) => ({
        penName: m.user.penName, avatarColorHex: m.user.avatarColorHex, avatarUrl: m.user.avatarUrl ?? null,
      })),
    };
  });

  // GET /clubs/:id/topics -> 该俱乐部讨论列表
  app.get<{ Params: { id: string } }>("/clubs/:id/topics", async (req) => {
    const rows = await prisma.topic.findMany({
      where: { clubId: req.params.id },
      include: { user: true, _count: { select: { replies: true } } },
      orderBy: { createdAt: "desc" },
    });
    return rows.map(serializeTopicItem);
  });

  // POST /clubs/:id/topics { title, body? } -> 发讨论
  app.post<{ Params: { id: string } }>(
    "/clubs/:id/topics", { preHandler: [app.authenticate] }, async (req, reply) => {
      const b = (req.body ?? {}) as { title?: string; body?: string };
      const title = (b.title ?? "").trim();
      if (!title) return reply.code(400).send({ error: "标题不能为空" });
      const club = await prisma.club.findUnique({ where: { id: req.params.id } });
      if (!club) return reply.code(404).send({ error: "俱乐部不存在" });
      const t = await prisma.topic.create({
        data: { userId: req.userId!, title, body: (b.body ?? "").trim(), clubId: club.id },
        include: { user: true, _count: { select: { replies: true } } },
      });
      return serializeTopicItem(t);
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
