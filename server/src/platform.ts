import { prisma } from "./db.js";

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

// yyyy-MM-dd（UTC，避免时区漂移；签到颗粒度按天足够）。
export function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
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
