import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeBook } from "../serialize.js";
import { logActivity, runModeration } from "../platform.js";

// 可选取登录用户 id（公开接口也想知道"是不是我"）。
async function optUid(req: any): Promise<string | null> {
  try { return ((await req.jwtVerify()) as { uid: string }).uid; } catch { return null; }
}

export async function bookRoutes(app: FastifyInstance) {
  // GET /books -> [Book]（只返回已过审的；外加我自己未过审的）
  app.get("/books", async (req) => {
    const me = await optUid(req);
    const books = await prisma.book.findMany({
      where: me
        ? { OR: [{ moderationStatus: "approved" }, { ownerId: me }] }
        : { moderationStatus: "approved" },
      include: { chapters: true, ratings: true },
      orderBy: { createdAt: "asc" },
    });
    return books.map((b) => serializeBook(b, me));
  });

  // GET /books/:id -> Book（未过审的仅作者可见）
  app.get<{ Params: { id: string } }>("/books/:id", async (req, reply) => {
    const me = await optUid(req);
    const book = await prisma.book.findUnique({
      where: { id: req.params.id },
      include: { chapters: true, ratings: true },
    });
    if (!book) return reply.code(404).send({ error: "书不存在" });
    if (book.moderationStatus !== "approved" && book.ownerId !== me) {
      return reply.code(404).send({ error: "书不存在" });
    }
    return serializeBook(book, me);
  });

  // POST /books （上传原创新作）-> Book
  app.post(
    "/books",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const me = await prisma.user.findUnique({ where: { id: req.userId! } });
      if (!me) return reply.code(401).send({ error: "未登录" });

      const b = (req.body ?? {}) as {
        title?: string;
        blurb?: string;
        tags?: string[];
        tagline?: string;
        coverColors?: string[];
        coverAccent?: string;
        chapters?: { index: number; title: string; content: string }[];
      };

      const chapters = (b.chapters ?? []).filter((c) => c && typeof c.index === "number");
      if (chapters.length === 0) {
        return reply.code(400).send({ error: "至少要有一章正文" });
      }

      const book = await prisma.book.create({
        data: {
          title: (b.title || "").trim() || "未命名新作",
          author: me.penName,
          blurb: (b.blurb || "").trim(),
          tags: b.tags ?? [],
          tagline: (b.tagline || "原创").trim(),
          coverColors: b.coverColors ?? ["#1A2332", "#3a2a22", "#6E7042"],
          coverAccent: (b.coverAccent || "#C7A17A").trim(),
          status: "创作中",
          isUserCreated: true,
          ownerId: me.id,
          moderationStatus: "pending",
          chapters: {
            create: chapters.map((c) => ({
              index: c.index,
              title: (c.title || "").trim() || `第${c.index}章`,
              content: (c.content || "").trim(),
            })),
          },
        },
        include: { chapters: true, ratings: true },
      });
      await logActivity(me.id, "publish", `发布了新作《${book.title}》`, book.id);
      // 异步审核（不阻塞返回）：完成后写回状态并通知作者。
      runModeration(book.id).catch((e) => app.log.error(e));
      return serializeBook(book, me.id);
    }
  );

  // PUT /books/:id  （作者改标题/简介/标签/封面）-> Book
  app.put<{ Params: { id: string } }>(
    "/books/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      if (book.ownerId !== req.userId) return reply.code(403).send({ error: "只有作者能编辑" });
      const b = (req.body ?? {}) as {
        title?: string; blurb?: string; tags?: string[]; coverColors?: string[]; coverAccent?: string;
      };
      const data: Record<string, unknown> = {};
      if (typeof b.title === "string" && b.title.trim()) data.title = b.title.trim();
      if (typeof b.blurb === "string") data.blurb = b.blurb.trim();
      if (Array.isArray(b.tags)) data.tags = b.tags;
      if (Array.isArray(b.coverColors)) data.coverColors = b.coverColors;
      if (typeof b.coverAccent === "string" && b.coverAccent.trim()) data.coverAccent = b.coverAccent.trim();
      const updated = await prisma.book.update({
        where: { id: book.id }, data, include: { chapters: true, ratings: true },
      });
      return serializeBook(updated, req.userId);
    }
  );

  // DELETE /books/:id  （作者删除自己的作品，级联章节/评分/书评/收藏/申请/解锁）
  app.delete<{ Params: { id: string } }>(
    "/books/:id", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      if (book.ownerId !== req.userId) return reply.code(403).send({ error: "只有作者能删除" });
      await prisma.book.delete({ where: { id: book.id } });
      return { ok: true };
    }
  );

  // POST /books/:id/chapters { title, content }  （作者追加章节，重新审核）-> Book
  app.post<{ Params: { id: string } }>(
    "/books/:id/chapters", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id }, include: { chapters: true } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      if (book.ownerId !== req.userId) return reply.code(403).send({ error: "只有作者能加章" });
      const b = (req.body ?? {}) as { title?: string; content?: string };
      const content = (b.content || "").trim();
      if (!content) return reply.code(400).send({ error: "正文不能为空" });
      const nextIndex = (book.chapters.map((c) => c.index).reduce((a, c) => Math.max(a, c), 0)) + 1;
      await prisma.chapter.create({
        data: { bookId: book.id, index: nextIndex,
                title: (b.title || "").trim() || `第${nextIndex}章`, content },
      });
      await prisma.book.update({ where: { id: book.id }, data: { moderationStatus: "pending" } });
      runModeration(book.id).catch((e) => app.log.error(e));
      const updated = await prisma.book.findUnique({
        where: { id: book.id }, include: { chapters: true, ratings: true },
      });
      return serializeBook(updated!, req.userId);
    }
  );
}
