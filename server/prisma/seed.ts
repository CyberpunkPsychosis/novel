// 把现有 ios-app/XuMo/Resources/seed.json 灌进数据库。
// 建系统账号「观山海」持有 4 本种子书（isUserCreated=false），即 iOS 里「别人的书」。
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const __dirname = dirname(fileURLToPath(import.meta.url));

// 允许用 SEED_FILE 覆盖路径（容器里跑时用）。
const seedPath =
  process.env.SEED_FILE ||
  resolve(__dirname, "../../ios-app/XuMo/Resources/seed.json");

const SEED_AUTHOR = "观山海"; // = iOS LocalUser.seedAuthorName

type SeedChapter = { index: number; title: string; content: string };
type SeedBook = {
  id: string;
  title: string;
  author: string;
  blurb: string;
  tags: string[];
  tagline: string;
  coverColors: string[];
  coverAccent: string;
  status: string;
  forkOf?: string | null;
  forkFromChapter?: number | null;
  chapters: SeedChapter[];
};

async function main() {
  const raw = readFileSync(seedPath, "utf-8");
  const books = JSON.parse(raw) as SeedBook[];
  console.log(`读到 ${books.length} 本书，来自 ${seedPath}`);

  // 系统作者账号
  const author = await prisma.user.upsert({
    where: { handle: "guanshanhai" },
    update: {},
    create: {
      handle: "guanshanhai",
      penName: SEED_AUTHOR,
      bio: "观山海 · 平台原作",
      avatarColorHex: "#1A2332",
    },
  });

  for (const b of books) {
    // 用 seed.json 里的固定 id（yimian/fayan/...），保证 iOS 端进度键稳定。
    await prisma.book.upsert({
      where: { id: b.id },
      update: {
        title: b.title,
        author: b.author,
        blurb: b.blurb,
        tags: b.tags,
        tagline: b.tagline,
        coverColors: b.coverColors,
        coverAccent: b.coverAccent,
        status: b.status,
        forkOf: b.forkOf ?? null,
        forkFromChapter: b.forkFromChapter ?? null,
        isUserCreated: false,
        ownerId: author.id,
      },
      create: {
        id: b.id,
        title: b.title,
        author: b.author,
        blurb: b.blurb,
        tags: b.tags,
        tagline: b.tagline,
        coverColors: b.coverColors,
        coverAccent: b.coverAccent,
        status: b.status,
        forkOf: b.forkOf ?? null,
        forkFromChapter: b.forkFromChapter ?? null,
        isUserCreated: false,
        ownerId: author.id,
      },
    });

    // 章节：先清后插，保证可重复运行。
    await prisma.chapter.deleteMany({ where: { bookId: b.id } });
    await prisma.chapter.createMany({
      data: b.chapters.map((c) => ({
        bookId: b.id,
        index: c.index,
        title: c.title,
        content: c.content,
      })),
    });
    console.log(`  ✓ 《${b.title}》${b.chapters.length} 章`);
  }

  // 演示：给《法眼》设「花 30 墨滴免审批直接解锁改编」的授权，跑通付费 fork 路径。
  if (books.some((b) => b.id === "fayan")) {
    await prisma.forkPermission.upsert({
      where: { bookId: "fayan" },
      update: { allowContinue: true, allowAdapt: true, requireApproval: false, allowDownload: true, priceMolDi: 30 },
      create: { bookId: "fayan", allowContinue: true, allowAdapt: true, requireApproval: false, allowDownload: true, priceMolDi: 30 },
    });
    console.log("  ✓ 《法眼》授权：30 墨滴免审批解锁");
  }

  // 演示：两个书友俱乐部（成员数由真实加入产生）
  for (const c of [
    { name: "言情研究所", intro: "专攻都市/古言/虐恋的同好" },
    { name: "悬疑推理社", intro: "一起拆解伏笔与反转" },
  ]) {
    const exists = await prisma.club.findFirst({ where: { name: c.name } });
    if (!exists) await prisma.club.create({ data: c });
  }
  console.log("  ✓ 俱乐部：言情研究所 / 悬疑推理社");

  const total = await prisma.chapter.count();
  console.log(`完成：${books.length} 本书，共 ${total} 章。`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
