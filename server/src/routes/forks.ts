import type { FastifyInstance } from "fastify";
import { prisma } from "../db.js";
import { serializeBook, serializeForkRequest, serializePermission } from "../serialize.js";
import { addCredits, hasForkAccess, logActivity, notify, runModeration, spendCredits } from "../platform.js";

export async function forkRoutes(app: FastifyInstance) {
  // POST /forks  改编/续写真上云
  // { parentId, mode:"continuation"|"adaptation", fromChapter, newChapterTitle, newContent }
  app.post("/forks", { preHandler: [app.authenticate] }, async (req, reply) => {
    const me = await prisma.user.findUnique({ where: { id: req.userId! } });
    if (!me) return reply.code(401).send({ error: "未登录" });

    const b = (req.body ?? {}) as {
      parentId?: string; mode?: string; fromChapter?: number;
      newChapterTitle?: string; newContent?: string;
    };
    if (!b.parentId || (b.mode !== "continuation" && b.mode !== "adaptation")) {
      return reply.code(400).send({ error: "参数不全" });
    }

    const parent = await prisma.book.findUnique({
      where: { id: b.parentId }, include: { chapters: true },
    });
    if (!parent) return reply.code(404).send({ error: "原作不存在" });

    if (!(await hasForkAccess(me.id, parent.id))) {
      return reply.code(403).send({ error: "尚无改编权，请先申请或解锁" });
    }
    const perm = await prisma.forkPermission.findUnique({ where: { bookId: parent.id } });
    if (b.mode === "continuation" && perm && !perm.allowContinue) {
      return reply.code(403).send({ error: "原作者未开放续写" });
    }
    if (b.mode === "adaptation" && perm && !perm.allowAdapt) {
      return reply.code(403).send({ error: "原作者未开放改编" });
    }

    const sorted = parent.chapters.slice().sort((a, c) => a.index - c.index);
    const fromChapter = b.fromChapter ?? (sorted.at(-1)?.index ?? 0);
    const base =
      b.mode === "continuation" ? sorted : sorted.filter((c) => c.index <= fromChapter);
    const nextIndex = (base.at(-1)?.index ?? 0) + 1;
    const label = b.mode === "continuation" ? "续写" : "改编";
    const title = (b.newChapterTitle || "").trim() || `第${nextIndex}章`;

    const child = await prisma.book.create({
      data: {
        title: `${parent.title}·${label}`,
        author: me.penName,
        blurb: `${label}自《${parent.title}》。` + parent.blurb.slice(0, 40),
        tags: parent.tags,
        tagline: `${label}自《${parent.title}》`,
        coverColors: parent.coverColors,
        coverAccent: parent.coverAccent,
        status: "创作中",
        forkOf: parent.id,
        forkFromChapter: b.mode === "adaptation" ? fromChapter : null,
        isUserCreated: true,
        ownerId: me.id,
        moderationStatus: "pending",
        chapters: {
          create: [
            ...base.map((c) => ({ index: c.index, title: c.title, content: c.content })),
            { index: nextIndex, title, content: (b.newContent || "").trim() },
          ],
        },
      },
      include: { chapters: true, ratings: true },
    });

    // 通知原作者「有人开了支线」
    if (parent.ownerId && parent.ownerId !== me.id) {
      await notify(parent.ownerId, "newBranch",
        `${me.penName} 为《${parent.title}》开了新支线「${title}」`, me.penName);
    }
    await logActivity(me.id, "fork", `${label}了《${parent.title}》，开出新支线`, child.id);
    // 异步审核新支线
    runModeration(child.id).catch((e) => app.log.error(e));
    return serializeBook(child);
  });

  // GET /books/:id/permission  （公开：读者据此知道能否改编/价格）
  app.get<{ Params: { id: string } }>("/books/:id/permission", async (req) => {
    const perm = await prisma.forkPermission.findUnique({ where: { bookId: req.params.id } });
    return serializePermission(perm);
  });

  // PUT /books/:id/permission  （仅作者）
  app.put<{ Params: { id: string } }>(
    "/books/:id/permission", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      if (book.ownerId !== req.userId) return reply.code(403).send({ error: "只有作者能改授权" });

      const b = (req.body ?? {}) as Record<string, unknown>;
      const data = {
        allowContinue: Boolean(b.allowContinue ?? true),
        allowAdapt: Boolean(b.allowAdapt ?? true),
        requireApproval: Boolean(b.requireApproval ?? true),
        allowDownload: Boolean(b.allowDownload ?? true),
        priceMolDi: Number(b.priceMolDi ?? 0),
      };
      const perm = await prisma.forkPermission.upsert({
        where: { bookId: book.id },
        create: { bookId: book.id, ...data },
        update: data,
      });
      return serializePermission(perm);
    });

  // POST /fork-requests  发起改编/续写申请
  app.post("/fork-requests", { preHandler: [app.authenticate] }, async (req, reply) => {
    const me = await prisma.user.findUnique({ where: { id: req.userId! } });
    if (!me) return reply.code(401).send({ error: "未登录" });
    const b = (req.body ?? {}) as { bookId?: string; fromChapter?: number; mode?: string };
    if (!b.bookId || !b.mode) return reply.code(400).send({ error: "参数不全" });

    const book = await prisma.book.findUnique({ where: { id: b.bookId } });
    if (!book) return reply.code(404).send({ error: "书不存在" });

    const reqRow = await prisma.forkRequest.create({
      data: {
        requesterId: me.id, bookId: b.bookId,
        fromChapter: b.fromChapter ?? 1, mode: b.mode,
      },
      include: { requester: true },
    });
    if (book.ownerId && book.ownerId !== me.id) {
      await notify(book.ownerId, "forkRequest",
        `${me.penName} 想${b.mode}你的《${book.title}》，待你同意`, me.penName);
    }
    return serializeForkRequest(reqRow);
  });

  // GET /me/fork-requests/incoming  我收到的（针对我创作的书）
  app.get("/me/fork-requests/incoming", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.forkRequest.findMany({
      where: { book: { ownerId: req.userId! } },
      include: { requester: true },
      orderBy: { createdAt: "desc" },
    });
    return rows.map(serializeForkRequest);
  });

  // GET /me/fork-requests/outgoing  我发出的申请
  app.get("/me/fork-requests/outgoing", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.forkRequest.findMany({
      where: { requesterId: req.userId! },
      include: { requester: true },
      orderBy: { createdAt: "desc" },
    });
    return rows.map(serializeForkRequest);
  });

  // POST /fork-requests/:id/decide  作者同意/拒绝
  app.post<{ Params: { id: string } }>(
    "/fork-requests/:id/decide", { preHandler: [app.authenticate] }, async (req, reply) => {
      const approve = Boolean((req.body as { approve?: boolean })?.approve);
      const reqRow = await prisma.forkRequest.findUnique({
        where: { id: req.params.id }, include: { book: true, requester: true },
      });
      if (!reqRow) return reply.code(404).send({ error: "申请不存在" });
      if (reqRow.book.ownerId !== req.userId) {
        return reply.code(403).send({ error: "只有作者能审批" });
      }

      const updated = await prisma.forkRequest.update({
        where: { id: reqRow.id },
        data: { status: approve ? "approved" : "denied" },
        include: { requester: true },
      });

      if (approve) {
        // 同意即给申请人开改编权 + 作者得分成 + 双方通知
        await prisma.forkUnlock.upsert({
          where: { userId_bookId: { userId: reqRow.requesterId, bookId: reqRow.bookId } },
          create: { userId: reqRow.requesterId, bookId: reqRow.bookId },
          update: {},
        });
        await addCredits(req.userId!, 15, "royalty", `《${reqRow.book.title}》被${reqRow.mode}分成`);
        await notify(reqRow.requesterId, "forkApproved",
          `你对《${reqRow.book.title}》的${reqRow.mode}申请已通过`, reqRow.book.author);
      } else {
        await notify(reqRow.requesterId, "forkDenied",
          `你对《${reqRow.book.title}》的${reqRow.mode}申请被拒绝`, reqRow.book.author);
      }
      return serializeForkRequest(updated);
    });

  // POST /books/:id/unlock  花墨滴解锁改编/下载权
  app.post<{ Params: { id: string } }>(
    "/books/:id/unlock", { preHandler: [app.authenticate] }, async (req, reply) => {
      const book = await prisma.book.findUnique({ where: { id: req.params.id } });
      if (!book) return reply.code(404).send({ error: "书不存在" });
      const perm = await prisma.forkPermission.findUnique({ where: { bookId: book.id } });
      const price = perm?.priceMolDi ?? 0;

      if (price > 0) {
        const ok = await spendCredits(req.userId!, price, "fork", `解锁《${book.title}》改编权`);
        if (!ok) return reply.code(402).send({ error: "墨滴不足" });
        // 真实分成：价款进作者账户 + 通知作者。
        if (book.ownerId && book.ownerId !== req.userId) {
          await addCredits(book.ownerId, price, "royalty", `《${book.title}》被解锁分成`);
          await notify(book.ownerId, "system", `有人花 ${price} 墨滴解锁了《${book.title}》，已入账`);
        }
      }
      await prisma.forkUnlock.upsert({
        where: { userId_bookId: { userId: req.userId!, bookId: book.id } },
        create: { userId: req.userId!, bookId: book.id },
        update: {},
      });
      await notify(req.userId!, "system", `已解锁《${book.title}》的改编/下载权`);
      return { ok: true };
    });

  // GET /me/unlocks  我已解锁的书 id 列表
  app.get("/me/unlocks", { preHandler: [app.authenticate] }, async (req) => {
    const rows = await prisma.forkUnlock.findMany({ where: { userId: req.userId! } });
    return rows.map((r) => r.bookId);
  });
}
