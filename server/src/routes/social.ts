import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { notify, relativeTime } from "../platform.js";
import { serializeBook } from "../serialize.js";

async function uid(req: any): Promise<string | null> {
  try { return ((await req.jwtVerify()) as { uid: string }).uid; } catch { return null; }
}

type TopicRow = {
  id: string; title: string; createdAt: Date;
  user: { handle: string; penName: string; avatarColorHex: string; avatarUrl?: string | null };
  _count: { replies: number };
};
function serializeTopicItem(t: TopicRow) {
  return {
    id: t.id, title: t.title,
    author: t.user.penName, handle: t.user.handle,
    avatarColorHex: t.user.avatarColorHex, avatarUrl: t.user.avatarUrl ?? null,
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

  // ===== 他人主页 =====
  // GET /users/:handle -> { penName, bio, avatar..., books:[已过审创作], reviewCount }
  app.get<{ Params: { handle: string } }>("/users/:handle", async (req, reply) => {
    const u = await prisma.user.findUnique({ where: { handle: req.params.handle } });
    if (!u) return reply.code(404).send({ error: "用户不存在" });
    const books = await prisma.book.findMany({
      where: { ownerId: u.id, moderationStatus: "approved" },
      include: { chapters: true, ratings: true },
      orderBy: { createdAt: "desc" },
    });
    const reviewCount = await prisma.review.count({ where: { userId: u.id } });
    return {
      handle: u.handle, penName: u.penName, bio: u.bio,
      avatarColorHex: u.avatarColorHex, avatarUrl: u.avatarUrl ?? null,
      reviewCount,
      books: books.map((b) => serializeBook(b, null)),
    };
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
      author: t.user.penName, handle: t.user.handle,
      avatarColorHex: t.user.avatarColorHex, avatarUrl: t.user.avatarUrl ?? null,
      date: t.createdAt,
      replies: t.replies.map((r) => ({
        id: r.id, author: r.user.penName, handle: r.user.handle, avatarColorHex: r.user.avatarColorHex,
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
      // 通知楼主有人回帖
      if (topic.userId !== req.userId) {
        await notify(topic.userId, "system", `${r.user.penName} 回复了你的话题「${topic.title}」`,
          r.user.penName, { kind: "topic", id: topic.id });
      }
      return { id: r.id, author: r.user.penName, handle: r.user.handle, avatarColorHex: r.user.avatarColorHex,
               avatarUrl: r.user.avatarUrl ?? null, text: r.text, date: r.createdAt };
    });

  // DELETE /topics/:id （删自己的话题，级联回帖）
  app.delete<{ Params: { id: string } }>(
    "/topics/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const t = await prisma.topic.findUnique({ where: { id: req.params.id } });
      if (!t) return reply.code(404).send({ error: "话题不存在" });
      if (t.userId !== req.userId) return reply.code(403).send({ error: "只能删自己的话题" });
      await prisma.topic.delete({ where: { id: t.id } });
      return { ok: true };
    });

  // DELETE /topic-replies/:id （删自己的回帖）
  app.delete<{ Params: { id: string } }>(
    "/topic-replies/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const r = await prisma.topicReply.findUnique({ where: { id: req.params.id } });
      if (!r) return reply.code(404).send({ error: "回帖不存在" });
      if (r.userId !== req.userId) return reply.code(403).send({ error: "只能删自己的回帖" });
      await prisma.topicReply.delete({ where: { id: r.id } });
      return { ok: true };
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

  // POST /clubs { name, intro } -> 用户自建俱乐部（建者自动入会）
  app.post("/clubs", { preHandler: [app.authenticate] }, async (req, reply) => {
    const b = (req.body ?? {}) as { name?: string; intro?: string };
    const name = (b.name ?? "").trim();
    if (!name) return reply.code(400).send({ error: "俱乐部名不能为空" });
    const club = await prisma.club.create({
      data: { name, intro: (b.intro ?? "").trim(), ownerId: req.userId! },
    });
    await prisma.clubMember.create({ data: { userId: req.userId!, clubId: club.id } });
    return { id: club.id, name: club.name, intro: club.intro, memberCount: 1, joinedByMe: true };
  });

  // DELETE /clubs/:id -> 解散（仅建者）
  app.delete<{ Params: { id: string } }>(
    "/clubs/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const club = await prisma.club.findUnique({ where: { id: req.params.id } });
      if (!club) return reply.code(404).send({ error: "俱乐部不存在" });
      if (club.ownerId !== req.userId) return reply.code(403).send({ error: "只有建者能解散" });
      await prisma.club.delete({ where: { id: club.id } });
      return { ok: true };
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
      isOwner: !!me && c.ownerId === me,
      members: c.members.map((m) => ({
        handle: m.user.handle, penName: m.user.penName,
        avatarColorHex: m.user.avatarColorHex, avatarUrl: m.user.avatarUrl ?? null,
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
