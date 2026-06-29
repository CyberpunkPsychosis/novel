import type { FastifyInstance } from "fastify";
import { createWriteStream } from "node:fs";
import { resolve, extname } from "node:path";
import { pipeline } from "node:stream/promises";
import { prisma } from "../db.js";
import { serializeUser } from "../serialize.js";

const uploadsDir = resolve(process.cwd(), "uploads");

export async function mediaRoutes(app: FastifyInstance) {
  // POST /me/avatar (multipart: file) -> { avatarUrl, user }
  app.post("/me/avatar", { preHandler: [app.authenticate] }, async (req, reply) => {
    const data = await req.file();
    if (!data) return reply.code(400).send({ error: "没有收到图片" });

    const ext = (extname(data.filename || "") || ".jpg").toLowerCase();
    const safeExt = [".jpg", ".jpeg", ".png", ".heic", ".webp"].includes(ext) ? ext : ".jpg";
    const name = `${req.userId}-${Date.now()}${safeExt}`;
    await pipeline(data.file, createWriteStream(resolve(uploadsDir, name)));

    const avatarUrl = `/uploads/${name}`;
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { avatarUrl },
    });
    return { avatarUrl, user: serializeUser(user) };
  });
}
