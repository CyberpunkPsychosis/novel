import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeNotification } from "../serialize.js";

export async function notificationRoutes(app: FastifyInstance) {
  // GET /me/notifications -> [Notification]
  app.get("/me/notifications", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.notification.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: "desc" },
    });
    return rows.map(serializeNotification);
  });

  // POST /me/notifications/read-all -> { ok }
  app.post("/me/notifications/read-all", { preHandler: [app.authenticate] }, async (req) => {
    await prisma.notification.updateMany({
      where: { userId: req.userId!, read: false },
      data: { read: true },
    });
    return { ok: true };
  });
}
