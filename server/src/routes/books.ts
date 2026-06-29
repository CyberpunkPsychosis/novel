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
}
