import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";

export async function progressRoutes(app: FastifyInstance) {
  // GET /me/progress -> { bookId: chapterIndex }（对齐 iOS readingProgress[String:Int]）
  app.get(
    "/me/progress",
    { preHandler: [app.authenticate] },
    async (req) => {
      const rows = await prisma.readingProgress.findMany({
        where: { userId: req.userId! },
      });
      const out: Record<string, number> = {};
      for (const r of rows) out[r.bookId] = r.chapterIndex;
      return out;
    }
  );

  // PUT /me/progress  { bookId, chapterIndex } -> { ok: true }
  app.put(
    "/me/progress",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const b = (req.body ?? {}) as { bookId?: string; chapterIndex?: number };
      if (!b.bookId || typeof b.chapterIndex !== "number") {
        return reply.code(400).send({ error: "缺少 bookId / chapterIndex" });
      }
      await prisma.readingProgress.upsert({
        where: { userId_bookId: { userId: req.userId!, bookId: b.bookId } },
        create: { userId: req.userId!, bookId: b.bookId, chapterIndex: b.chapterIndex },
        update: { chapterIndex: b.chapterIndex },
      });
      return { ok: true };
    }
  );
}
