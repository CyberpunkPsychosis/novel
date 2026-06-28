import Fastify from "fastify";
import cors from "@fastify/cors";
import { registerAuth } from "./plugins/auth.js";
import { authRoutes } from "./routes/auth.js";
import { bookRoutes } from "./routes/books.js";
import { progressRoutes } from "./routes/progress.js";
import { forkRoutes } from "./routes/forks.js";
import { creditRoutes } from "./routes/credits.js";
import { notificationRoutes } from "./routes/notifications.js";
import { discoverRoutes } from "./routes/discover.js";
import { communityRoutes } from "./routes/community.js";
import { socialRoutes } from "./routes/social.js";

const app = Fastify({
  logger: true,
  bodyLimit: 5 * 1024 * 1024, // 上传整本书可能较大
});

await app.register(cors, { origin: true });
await registerAuth(app);

app.get("/health", async () => ({ ok: true }));

await app.register(authRoutes);
await app.register(bookRoutes);
await app.register(progressRoutes);
await app.register(forkRoutes);
await app.register(creditRoutes);
await app.register(notificationRoutes);
await app.register(discoverRoutes);
await app.register(communityRoutes);
await app.register(socialRoutes);

const port = Number(process.env.PORT || 3000);
app
  .listen({ port, host: "0.0.0.0" })
  .then(() => app.log.info(`XuMo API on :${port}`))
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });
