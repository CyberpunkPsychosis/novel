// DB 实体 → 与 iOS Swift Codable 对齐的 JSON。
// 关键：所有字段都显式给出（含 isUserCreated / forkOf / forkFromChapter），
// 不靠对端默认值，保证 Swift 解码稳。

type ChapterRow = { index: number; title: string; content: string };
type BookRow = {
  id: string;
  title: string;
  author: string;
  blurb: string;
  tags: string[];
  tagline: string;
  coverColors: string[];
  coverAccent: string;
  status: string;
  forkOf: string | null;
  forkFromChapter: number | null;
  isUserCreated: boolean;
  moderationStatus?: string;
  chapters?: ChapterRow[];
  ratings?: { value: number }[];
};

export function serializeBook(b: BookRow) {
  const ratings = b.ratings ?? [];
  const ratingCount = ratings.length;
  const ratingAvg = ratingCount
    ? ratings.reduce((s, r) => s + r.value, 0) / ratingCount
    : 0;
  return {
    id: b.id,
    title: b.title,
    author: b.author,
    blurb: b.blurb,
    tags: b.tags,
    tagline: b.tagline,
    coverColors: b.coverColors,
    coverAccent: b.coverAccent,
    status: b.status,
    forkOf: b.forkOf,
    forkFromChapter: b.forkFromChapter,
    isUserCreated: b.isUserCreated,
    moderationStatus: b.moderationStatus ?? "approved",
    ratingAvg: Math.round(ratingAvg * 10) / 10,
    ratingCount,
    chapters: (b.chapters ?? [])
      .slice()
      .sort((a, c) => a.index - c.index)
      .map((c) => ({ index: c.index, title: c.title, content: c.content })),
  };
}

type UserRow = {
  id: string;
  handle: string;
  penName: string;
  bio: string;
  avatarColorHex: string;
};

// 对齐 iOS LocalUser（id 用 handle 以外字段也行，这里直接用 handle 当展示 id）。
export function serializeUser(u: UserRow) {
  return {
    id: u.handle,
    handle: u.handle,
    penName: u.penName,
    bio: u.bio,
    avatarColorHex: u.avatarColorHex,
  };
}

// MARK: fork 生态实体 → iOS 类型（注意键名：date / bookID / requester=笔名）

export function serializeCreditTxn(t: {
  id: string; delta: number; reason: string; note: string; createdAt: Date;
}) {
  return { id: t.id, delta: t.delta, reason: t.reason, note: t.note, date: t.createdAt };
}

export function serializeNotification(n: {
  id: string; type: string; actor: string; text: string; read: boolean; createdAt: Date;
}) {
  return { id: n.id, type: n.type, actor: n.actor, text: n.text, read: n.read, date: n.createdAt };
}

// iOS ForkRequest.requester 是笔名字符串、bookID 大写。
export function serializeForkRequest(r: {
  id: string; bookId: string; fromChapter: number; mode: string; status: string; createdAt: Date;
  requester?: { penName: string } | null;
}) {
  return {
    id: r.id,
    requester: r.requester?.penName ?? "",
    bookID: r.bookId,
    fromChapter: r.fromChapter,
    mode: r.mode,
    status: r.status,
    date: r.createdAt,
  };
}

// iOS ForkPermission 是无 id 的 struct；缺省给开放默认。
export function serializePermission(p: {
  allowContinue: boolean; allowAdapt: boolean; requireApproval: boolean;
  allowDownload: boolean; priceMolDi: number;
} | null) {
  return {
    allowContinue: p?.allowContinue ?? true,
    allowAdapt: p?.allowAdapt ?? true,
    requireApproval: p?.requireApproval ?? true,
    allowDownload: p?.allowDownload ?? true,
    priceMolDi: p?.priceMolDi ?? 0,
  };
}

export function serializeCheckin(c: { lastDate: string; streak: number } | null) {
  return { lastDate: c?.lastDate ?? "", streak: c?.streak ?? 0 };
}
