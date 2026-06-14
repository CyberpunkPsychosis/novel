#!/usr/bin/env node
// 静态小说网站生成器（零依赖）。
// 读取 books/<书名>/ 下的 book.json 与 4-正文/*.md，生成 docs/ 静态站点。
// 用法：node tools/build-site.mjs

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BOOKS_DIR = path.join(ROOT, "books");
const OUT_DIR = path.join(ROOT, "docs");

// ---------- 工具 ----------

const escapeHtml = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const escapeAttr = (s) => escapeHtml(s).replace(/"/g, "&quot;");

// 极简 Markdown → HTML，只覆盖正文用到的语法：
// 一级标题、二级标题、分隔线、加粗、斜体、空行分段。
function inline(text) {
  let t = escapeHtml(text);
  t = t.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  t = t.replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, "<em>$1</em>");
  return t;
}

function chapterBodyToHtml(md) {
  const lines = md.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let para = [];
  let firstH1Skipped = false;

  const flush = () => {
    if (para.length) {
      out.push(`<p>${inline(para.join("")).trim()}</p>`);
      para = [];
    }
  };

  for (const raw of lines) {
    const line = raw.trimEnd();
    if (/^#\s+/.test(line)) {
      flush();
      if (!firstH1Skipped) {
        firstH1Skipped = true; // 章标题由阅读页另行渲染，正文里跳过
        continue;
      }
      out.push(`<h2>${inline(line.replace(/^#\s+/, ""))}</h2>`);
    } else if (/^##\s+/.test(line)) {
      flush();
      out.push(`<h3>${inline(line.replace(/^##\s+/, ""))}</h3>`);
    } else if (/^---+\s*$/.test(line)) {
      flush();
      out.push('<hr class="break" />');
    } else if (line.trim() === "") {
      flush();
    } else {
      if (para.length) para.push(" ");
      para.push(line.trim());
    }
  }
  flush();
  return out.join("\n");
}

// 从正文 md 里取章标题：优先第一行 "# xxx"，否则用文件名。
function extractTitle(md, fallback) {
  const m = md.match(/^#\s+(.+)$/m);
  return m ? m[1].trim() : fallback;
}

// 从文件名 "第001章-标题.md" 解析序号与名字。
function parseChapterFile(name) {
  const base = name.replace(/\.md$/i, "");
  const m = base.match(/第\s*(\d+)\s*章[\s\-—:：]*(.*)$/);
  if (m) return { num: parseInt(m[1], 10), name: m[2].trim() || base };
  return { num: null, name: base };
}

// 生成网文风格的 SVG 封面（无版权风险，可被 book.json 的 cover 覆盖）。
// 主视觉：一只发光的眼睛 + 横排大字标题 + 钩子文案，渲染出网文封面的张力。
function svgCover(book) {
  const [c1, c2, c3] = book.coverColors || ["#05060a", "#0f2027", "#1a3a2e"];
  const accent = book.coverAccent || "#e8c477";
  const title = escapeHtml(book.title);
  const author = escapeHtml(book.author || "");
  const tagline = escapeHtml(book.tagline || "");
  const topTag = escapeHtml((book.tags || []).slice(0, 3).join("　"));
  const n = [...book.title].length;
  const titleSize = n <= 2 ? 168 : n <= 4 ? 116 : n <= 6 ? 84 : 64;

  // 眼睛主视觉的放射光线
  const rays = Array.from({ length: 24 }, (_, i) => {
    const a = (i / 24) * Math.PI * 2;
    const r1 = 92, r2 = 92 + (i % 2 ? 26 : 46);
    const x1 = 300 + Math.cos(a) * r1, y1 = 300 + Math.sin(a) * r1;
    const x2 = 300 + Math.cos(a) * r2, y2 = 300 + Math.sin(a) * r2;
    return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${accent}" stroke-width="2" stroke-opacity="0.5"/>`;
  }).join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800" viewBox="0 0 600 800" role="img" aria-label="${escapeAttr(title)}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="38%" r="75%">
      <stop offset="0" stop-color="${c3}"/>
      <stop offset="0.5" stop-color="${c2}"/>
      <stop offset="1" stop-color="${c1}"/>
    </radialGradient>
    <radialGradient id="iris" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#fff7e0"/>
      <stop offset="0.35" stop-color="${accent}"/>
      <stop offset="1" stop-color="#7a4e16"/>
    </radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff3cf"/>
      <stop offset="0.5" stop-color="${accent}"/>
      <stop offset="1" stop-color="#b07d2c"/>
    </linearGradient>
    <filter id="glow" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="9" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <rect width="600" height="800" fill="url(#bg)"/>
  <rect x="22" y="22" width="556" height="756" fill="none" stroke="${accent}" stroke-opacity="0.45" stroke-width="1.5"/>

  ${topTag ? `<text x="300" y="92" class="tag">${topTag}</text>` : ""}

  <!-- 眼睛主视觉 -->
  <g filter="url(#glow)">
    ${rays}
    <path d="M170 300 Q300 196 430 300 Q300 404 170 300 Z" fill="none" stroke="${accent}" stroke-width="4"/>
    <circle cx="300" cy="300" r="60" fill="url(#iris)"/>
    <circle cx="300" cy="300" r="26" fill="#0a0a0a"/>
    <circle cx="283" cy="284" r="9" fill="#fff" opacity="0.9"/>
  </g>

  <!-- 标题 -->
  <text x="300" y="568" class="title" style="font-size:${titleSize}px">${title}</text>
  ${tagline ? `<text x="300" y="628" class="tagline">${tagline}</text>` : ""}

  <line x1="200" y1="690" x2="400" y2="690" stroke="${accent}" stroke-opacity="0.6" stroke-width="1.5"/>
  ${author ? `<text x="300" y="742" class="author">${author}</text>` : ""}

  <style>
    .title { fill: url(#gold); font-family: 'Noto Serif SC','Songti SC',serif; font-weight: 700; text-anchor: middle; letter-spacing: 6px; stroke: #2a1c06; stroke-width: 1px; paint-order: stroke; }
    .tagline { fill: #f3ead6; font-family: 'Noto Serif SC',serif; font-size: 30px; text-anchor: middle; letter-spacing: 4px; }
    .tag { fill: ${accent}; fill-opacity: 0.85; font-family: sans-serif; font-size: 22px; text-anchor: middle; letter-spacing: 4px; }
    .author { fill: #cdbfa6; font-family: 'Noto Serif SC',serif; font-size: 24px; text-anchor: middle; letter-spacing: 3px; }
  </style>
</svg>`;
}

// ---------- 页面模板 ----------

const CSS = `:root{--bg:#faf8f4;--fg:#26211c;--muted:#7d756b;--card:#fff;--line:#e8e1d6;--accent:#9a6a3a;--accent2:#c08a4a}
@media (prefers-color-scheme:dark){:root{--bg:#16130f;--fg:#e6ddd0;--muted:#9a9085;--card:#1f1b16;--line:#332c24;--accent:#d6a86a;--accent2:#e8c477}}
*{box-sizing:border-box}
html{font-size:18px}
body{margin:0;background:var(--bg);color:var(--fg);font-family:'Noto Serif SC',Georgia,'Songti SC',serif;line-height:1.85;-webkit-font-smoothing:antialiased}
a{color:var(--accent);text-decoration:none}
a:hover{color:var(--accent2)}
.wrap{max-width:760px;margin:0 auto;padding:0 20px}
header.site{text-align:center;padding:48px 20px 24px}
header.site h1{margin:0;font-size:2rem;letter-spacing:4px}
header.site p{margin:8px 0 0;color:var(--muted);letter-spacing:2px}
.shelf{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:28px;max-width:980px;margin:32px auto 64px;padding:0 20px}
.book{display:block;background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden;transition:transform .15s,box-shadow .15s}
.book:hover{transform:translateY(-4px);box-shadow:0 12px 28px rgba(0,0,0,.18)}
.book .cover{aspect-ratio:3/4;width:100%;object-fit:cover;display:block;background:#222}
.book .meta{padding:12px 14px 16px}
.book .meta .bt{font-size:1.1rem;font-weight:700;color:var(--fg);margin:0 0 4px}
.book .meta .bd{font-size:.82rem;color:var(--muted);line-height:1.5;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.badge{display:inline-block;font-size:.72rem;color:var(--accent);border:1px solid var(--line);border-radius:999px;padding:1px 9px;margin-top:8px}
.bookhead{display:flex;gap:24px;align-items:flex-start;padding:32px 0 8px;flex-wrap:wrap}
.bookhead img{width:170px;border-radius:10px;border:1px solid var(--line)}
.bookhead .info{flex:1;min-width:220px}
.bookhead h1{margin:.2em 0}
.bookhead .blurb{color:var(--fg);opacity:.9}
.tags span{display:inline-block;font-size:.78rem;color:var(--muted);border:1px solid var(--line);border-radius:999px;padding:2px 10px;margin:0 6px 6px 0}
.toc{list-style:none;padding:0;margin:24px 0 64px;border-top:1px solid var(--line)}
.toc li a{display:flex;justify-content:space-between;gap:12px;padding:14px 4px;border-bottom:1px solid var(--line);color:var(--fg)}
.toc li a:hover{color:var(--accent);background:rgba(154,106,58,.06)}
.toc .cn{color:var(--muted);font-size:.82rem;font-variant-numeric:tabular-nums}
article{padding:24px 0 40px}
article h1.title{font-size:1.6rem;text-align:center;margin:8px 0 4px;letter-spacing:2px}
article .sub{text-align:center;color:var(--muted);font-size:.85rem;margin-bottom:32px}
article p{margin:0 0 1.4em;text-indent:2em}
article h2{font-size:1.2rem;margin:2em 0 1em;text-align:center}
article h3{font-size:1.05rem;margin:1.6em 0 .8em}
hr.break{border:none;text-align:center;margin:2.2em 0}
hr.break::before{content:"❉";color:var(--accent);font-size:1.1rem;letter-spacing:6px}
.nav{display:flex;justify-content:space-between;gap:12px;margin:8px 0 56px}
.nav a,.nav span{flex:1;text-align:center;padding:12px;border:1px solid var(--line);border-radius:10px;background:var(--card)}
.nav span{color:var(--muted);opacity:.5}
.topbar{position:sticky;top:0;z-index:5;background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(8px);border-bottom:1px solid var(--line)}
.topbar .wrap{display:flex;align-items:center;justify-content:space-between;height:52px}
.topbar a{font-size:.9rem}
.tools button{font:inherit;font-size:.85rem;background:none;border:1px solid var(--line);color:var(--muted);border-radius:8px;padding:4px 10px;cursor:pointer;margin-left:6px}
.tools button:hover{color:var(--accent);border-color:var(--accent)}
footer.site{text-align:center;color:var(--muted);font-size:.8rem;padding:32px 20px 56px;letter-spacing:2px}
body.fs-l article{font-size:1.12rem}
body.fs-xl article{font-size:1.25rem}`;

const FONTS = `<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@400;700&display=swap" rel="stylesheet">`;

const READER_JS = `<script>
(function(){
  var b=document.body, k='reader-fs';
  var s=localStorage.getItem(k); if(s) b.classList.add(s);
  window.__fs=function(c){['fs-l','fs-xl'].forEach(function(x){b.classList.remove(x)});if(c)b.classList.add(c);localStorage.setItem(k,c||'');};
})();
</script>`;

function page({ title, body, depth, fonts = true }) {
  const base = "../".repeat(depth);
  return `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title>
${fonts ? FONTS : ""}
<link rel="stylesheet" href="${base}assets/style.css">
</head>
<body>
${body}
</body>
</html>`;
}

// ---------- 主流程 ----------

async function readJson(p, fallback = null) {
  try {
    return JSON.parse(await fs.readFile(p, "utf8"));
  } catch {
    return fallback;
  }
}

async function loadBooks() {
  let dirs = [];
  try {
    dirs = (await fs.readdir(BOOKS_DIR, { withFileTypes: true }))
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  } catch {
    return [];
  }
  const books = [];
  for (const dir of dirs) {
    const meta = await readJson(path.join(BOOKS_DIR, dir, "book.json"));
    if (!meta) continue;
    const textDir = path.join(BOOKS_DIR, dir, "4-正文");
    let files = [];
    try {
      files = (await fs.readdir(textDir)).filter((f) => /\.md$/i.test(f));
    } catch {}
    const chapters = [];
    for (const f of files) {
      const md = await fs.readFile(path.join(textDir, f), "utf8");
      const parsed = parseChapterFile(f);
      chapters.push({
        num: parsed.num,
        title: extractTitle(md, parsed.name),
        html: chapterBodyToHtml(md),
        words: md.replace(/\s/g, "").length,
      });
    }
    chapters.sort((a, b) => (a.num ?? 1e9) - (b.num ?? 1e9));
    books.push({ dir, meta, chapters });
  }
  // 章节多的书排前面
  books.sort((a, b) => b.chapters.length - a.chapters.length);
  return books;
}

const chapHref = (n) => `chapter-${String(n ?? 0).padStart(3, "0")}.html`;

async function build() {
  const site = (await readJson(path.join(ROOT, "site.json"))) || {
    title: "我的书架",
    subtitle: "",
    footer: "",
  };
  const books = await loadBooks();

  // 清理并重建 docs
  await fs.rm(OUT_DIR, { recursive: true, force: true });
  await fs.mkdir(path.join(OUT_DIR, "assets"), { recursive: true });
  await fs.writeFile(path.join(OUT_DIR, "assets", "style.css"), CSS);
  await fs.writeFile(path.join(OUT_DIR, ".nojekyll"), "");

  const footerHtml = site.footer
    ? `<footer class="site">${escapeHtml(site.footer)}</footer>`
    : "";

  // 首页书架
  const cards = books
    .map((b) => {
      const m = b.meta;
      const coverSrc = m.cover ? m.cover : `books/${m.slug}/cover.svg`;
      return `<a class="book" href="books/${m.slug}/index.html">
  <img class="cover" src="${escapeAttr(coverSrc)}" alt="${escapeAttr(m.title)} 封面">
  <div class="meta">
    <p class="bt">${escapeHtml(m.title)}</p>
    <p class="bd">${escapeHtml(m.blurb || "")}</p>
    <span class="badge">${escapeHtml(m.status || "")} · ${b.chapters.length} 章</span>
  </div>
</a>`;
    })
    .join("\n");

  const home = `<header class="site">
  <h1>${escapeHtml(site.title)}</h1>
  ${site.subtitle ? `<p>${escapeHtml(site.subtitle)}</p>` : ""}
</header>
<main class="shelf">
${cards || '<p style="grid-column:1/-1;text-align:center;color:var(--muted)">书架还空着，写几章就有了。</p>'}
</main>
${footerHtml}`;
  await fs.writeFile(
    path.join(OUT_DIR, "index.html"),
    page({ title: site.title, body: home, depth: 0 })
  );

  // 每本书
  for (const b of books) {
    const m = b.meta;
    const bookDir = path.join(OUT_DIR, "books", m.slug);
    await fs.mkdir(bookDir, { recursive: true });

    if (!m.cover) {
      await fs.writeFile(path.join(bookDir, "cover.svg"), svgCover(m));
    }

    const totalWords = b.chapters.reduce((s, c) => s + c.words, 0);
    const coverSrc = m.cover ? `../../${m.cover}` : "cover.svg";

    const tocItems = b.chapters
      .map((c) => {
        const label = c.num
          ? `第${String(c.num).padStart(3, "0")}章 ${c.title.replace(/^第\s*\d+\s*章[\s\-—:：]*/, "")}`
          : c.title;
        return `<li><a href="${chapHref(c.num)}"><span>${escapeHtml(label)}</span><span class="cn">${c.words} 字</span></a></li>`;
      })
      .join("\n");

    const bookBody = `<div class="topbar"><div class="wrap"><a href="../../index.html">← 书架</a><span class="cn" style="color:var(--muted);font-size:.85rem">${b.chapters.length} 章 · 约 ${totalWords} 字</span></div></div>
<main class="wrap">
  <div class="bookhead">
    <img src="${escapeAttr(coverSrc)}" alt="${escapeAttr(m.title)} 封面">
    <div class="info">
      <h1>${escapeHtml(m.title)}</h1>
      <p class="tags">${(m.tags || []).map((t) => `<span>${escapeHtml(t)}</span>`).join("")}</p>
      <p class="blurb">${escapeHtml(m.blurb || "")}</p>
      <p style="color:var(--muted);font-size:.85rem">作者：${escapeHtml(m.author || "佚名")} · ${escapeHtml(m.status || "")}</p>
    </div>
  </div>
  <ul class="toc">
${tocItems || '<li style="padding:16px;color:var(--muted)">还没有章节</li>'}
  </ul>
</main>
${footerHtml}`;
    await fs.writeFile(
      path.join(bookDir, "index.html"),
      page({ title: m.title, body: bookBody, depth: 2 })
    );

    // 每一章
    for (let i = 0; i < b.chapters.length; i++) {
      const c = b.chapters[i];
      const prev = b.chapters[i - 1];
      const next = b.chapters[i + 1];
      const titleLabel = c.num
        ? `第${String(c.num).padStart(3, "0")}章 ${c.title.replace(/^第\s*\d+\s*章[\s\-—:：]*/, "")}`
        : c.title;
      const nav = `<nav class="nav">
  ${prev ? `<a href="${chapHref(prev.num)}">← 上一章</a>` : `<span>← 上一章</span>`}
  <a href="index.html">目录</a>
  ${next ? `<a href="${chapHref(next.num)}">下一章 →</a>` : `<span>下一章 →</span>`}
</nav>`;
      const body = `<div class="topbar"><div class="wrap"><a href="index.html">${escapeHtml(m.title)} · 目录</a><span class="tools"><button onclick="__fs('')">小</button><button onclick="__fs('fs-l')">中</button><button onclick="__fs('fs-xl')">大</button></span></div></div>
<main class="wrap">
  <article>
    <h1 class="title">${escapeHtml(titleLabel)}</h1>
    <p class="sub">${escapeHtml(m.title)} · ${c.words} 字</p>
${c.html}
  </article>
  ${nav}
</main>
${footerHtml}
${READER_JS}`;
      await fs.writeFile(
        path.join(bookDir, chapHref(c.num)),
        page({ title: `${titleLabel} - ${m.title}`, body, depth: 2 })
      );
    }
  }

  const totalCh = books.reduce((s, b) => s + b.chapters.length, 0);
  console.log(`✓ 生成完成：${books.length} 本书，${totalCh} 章 → docs/`);
}

build().catch((e) => {
  console.error(e);
  process.exit(1);
});
