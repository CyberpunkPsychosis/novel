import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import fastifyJwt from "@fastify/jwt";

// JWT 插件：签发自家 token + 提供 authenticate 守卫。
// token payload 只放 { uid }，校验后挂到 request.userId。
declare module "fastify" {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
    signToken: (uid: string) => string;
  }
  interface FastifyRequest {
    userId?: string;
  }
}

export async function registerAuth(app: FastifyInstance) {
  const secret = process.env.JWT_SECRET || "dev-only-change-me-please";
  await app.register(fastifyJwt, { secret });

  app.decorate("signToken", (uid: string) =>
    app.jwt.sign({ uid }, { expiresIn: "180d" })
  );

  app.decorate(
    "authenticate",
    async (req: FastifyRequest, reply: FastifyReply) => {
      try {
        const decoded = await req.jwtVerify<{ uid: string }>();
        req.userId = decoded.uid;
      } catch {
        reply.code(401).send({ error: "未登录或登录已过期" });
      }
    }
  );
}
