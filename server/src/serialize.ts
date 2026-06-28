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
  chapters?: ChapterRow[];
};

export function serializeBook(b: BookRow) {
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
