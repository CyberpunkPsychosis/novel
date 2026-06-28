import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeBook } from "../serialize.js";
import { logActivity, runModeration } from "../platform.js";

export async function bookRoutes(app: FastifyInstance) {
  // GET /books -> [Book]（含 chapters + 评分聚合；本期 4 本全量返回，分页后期再说）
  app.get("/books", async () => {
    const books = await prisma.book.findMany({
      include: { chapters: true, ratings: true },
      orderBy: { createdAt: "asc" },
    });
    return books.map(serializeBook);
  });

  // GET /books/:id -> Book
  app.get<{ Params: { id: string } }>("/books/:id", async (req, reply) => {
    const book = await prisma.book.findUnique({
      where: { id: req.params.id },
      include: { chapters: true, ratings: true },
    });
    if (!book) return reply.code(404).send({ error: "书不存在" });
    return serializeBook(book);
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
      return serializeBook(book);
    }
  );
}
