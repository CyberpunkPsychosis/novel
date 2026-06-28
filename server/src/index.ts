import Fastify from "fastify";
import cors from "@fastify/cors";
import { registerAuth } from "./plugins/auth.js";
import { authRoutes } from "./routes/auth.js";
import { bookRoutes } from "./routes/books.js";
import { progressRoutes } from "./routes/progress.js";

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

const port = Number(process.env.PORT || 3000);
app
  .listen({ port, host: "0.0.0.0" })
  .then(() => app.log.info(`XuMo API on :${port}`))
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });
