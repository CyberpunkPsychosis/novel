import { prisma } from "./db.js";
import { moderate } from "./moderation.js";

// 墨滴余额 = 该用户所有流水 delta 之和。
export async function balanceOf(userId: string): Promise<number> {
  const agg = await prisma.creditTxn.aggregate({
    where: { userId },
    _sum: { delta: true },
  });
  return agg._sum.delta ?? 0;
}

export async function addCredits(userId: string, delta: number, reason: string, note = "") {
  await prisma.creditTxn.create({ data: { userId, delta, reason, note } });
}

// 校验余额后扣费；不足返回 false 不扣。
export async function spendCredits(
  userId: string, amount: number, reason: string, note = ""
): Promise<boolean> {
  if (amount <= 0) return true;
  if ((await balanceOf(userId)) < amount) return false;
  await addCredits(userId, -amount, reason, note);
  return true;
}

export async function notify(
  userId: string, type: string, text: string, actor = ""
) {
  await prisma.notification.create({ data: { userId, type, actor, text } });
}

// 记一条活动流事件（发布/改编/评分/书评）。
export async function logActivity(
  userId: string, type: string, text: string, bookId: string | null = null
) {
  await prisma.activity.create({ data: { userId, type, text, bookId } });
}

// 相对时间文案。
export function relativeTime(d: Date): string {
  const sec = Math.max(0, (Date.now() - d.getTime()) / 1000);
  if (sec < 60) return "刚刚";
  if (sec < 3600) return `${Math.floor(sec / 60)} 分钟前`;
  if (sec < 86400) return `${Math.floor(sec / 3600)} 小时前`;
  return `${Math.floor(sec / 86400)} 天前`;
}

// yyyy-MM-dd（UTC，避免时区漂移；签到颗粒度按天足够）。
export function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

// 异步审核一本书：跑 DeepSeek/兜底 → 写回状态 → 通知作者。
export async function runModeration(bookId: string) {
  const book = await prisma.book.findUnique({
    where: { id: bookId }, include: { chapters: true },
  });
  if (!book) return;
  const body = book.chapters
    .map((c) => `${c.title}\n${c.content}`).join("\n").slice(0, 6000);
  const res = await moderate(`${book.title} ${book.blurb}`, body);
  await prisma.book.update({
    where: { id: bookId },
    data: {
      moderationStatus: res.approved ? "approved" : "rejected",
      moderationReason: res.reason,
    },
  });
  if (book.ownerId) {
    await notify(book.ownerId, "system",
      res.approved
        ? `《${book.title}》已通过审核，现已发布`
        : `《${book.title}》未通过审核：${res.reason}`);
  }
}

// 是否有改编权：作者本人 / 已解锁 / 该书授权为「免审批」。
export async function hasForkAccess(userId: string, bookId: string): Promise<boolean> {
  const book = await prisma.book.findUnique({ where: { id: bookId } });
  if (!book) return false;
  if (book.ownerId === userId) return true;
  const unlocked = await prisma.forkUnlock.findUnique({
    where: { userId_bookId: { userId, bookId } },
  });
  if (unlocked) return true;
  const perm = await prisma.forkPermission.findUnique({ where: { bookId } });
  if (perm && !perm.requireApproval) return true;
  // 需审批：看是否有已通过的申请
  const approved = await prisma.forkRequest.findFirst({
    where: { requesterId: userId, bookId, status: "approved" },
  });
  return !!approved;
}
