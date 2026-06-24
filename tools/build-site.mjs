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

// 「青简 · 墨白」移动端阅读设计系统（依据作者设计稿落地）。
const CSS = `:root,:root[data-theme=paper]{--bg:#F4EFE4;--fg:#211C17;--muted:#8A8175;--card:#FBF8F1;--line:rgba(33,28,23,.10);--accent:#B0392B;--soft:rgba(176,57,43,.10)}
:root[data-theme=eye]{--bg:#DEE7D4;--fg:#22302A;--muted:#6E7A6B;--card:#E7EEDF;--line:rgba(34,48,42,.12);--accent:#4F7A52;--soft:rgba(79,122,82,.14)}
:root[data-theme=yellow]{--bg:#F2E4C9;--fg:#3A2F1E;--muted:#8A7A5E;--card:#F8EED9;--line:rgba(58,47,30,.12);--accent:#B0392B;--soft:rgba(176,57,43,.10)}
:root[data-theme=night]{--bg:#16191B;--fg:#C7C0B3;--muted:#6B6359;--card:#1E2225;--line:rgba(255,255,255,.08);--accent:#C97A5A;--soft:rgba(201,122,90,.16)}
*{box-sizing:border-box}
html{font-size:17px;-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--fg);font-family:'Noto Sans SC',-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.7;-webkit-font-smoothing:antialiased;transition:background .25s,color .25s}
a{color:inherit;text-decoration:none}

/* 顶部品牌 */
.brand{text-align:center;padding:40px 20px 14px}
.brand .logo{font-family:'Noto Serif SC',serif;font-size:1.75rem;letter-spacing:8px;color:var(--fg)}
.brand .logo b{color:var(--accent);font-weight:700}
.brand .sub{margin-top:9px;font-size:.76rem;letter-spacing:4px;color:var(--muted)}
.brand .rule{width:38px;height:2px;background:var(--accent);opacity:.7;margin:14px auto 0;border-radius:2px}

/* 书架 */
.shelf{display:grid;grid-template-columns:repeat(auto-fill,minmax(146px,1fr));gap:24px 18px;max-width:880px;margin:22px auto 80px;padding:0 18px}
.book{display:block}
.book .cover{aspect-ratio:3/4;width:100%;object-fit:cover;display:block;border-radius:6px;background:#2a2620;box-shadow:0 6px 16px rgba(33,28,23,.20)}
.book .bt{font-family:'Noto Serif SC',serif;font-size:1.02rem;font-weight:700;margin:10px 2px 2px;color:var(--fg)}
.book .bd{font-size:.76rem;color:var(--muted);line-height:1.5;margin:0 2px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.book .badge{display:inline-block;font-size:.68rem;color:var(--accent);margin:6px 2px 0;letter-spacing:1px}

/* 通用顶栏 */
.appbar{position:sticky;top:0;z-index:20;display:flex;align-items:center;gap:10px;height:50px;padding:0 12px;background:color-mix(in srgb,var(--bg) 86%,transparent);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);border-bottom:1px solid var(--line)}
.appbar .ic{font-size:1.5rem;line-height:1;color:var(--fg);width:30px;text-align:center}
.appbar .t{flex:1;font-size:.95rem;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.appbar .r{font-size:.74rem;color:var(--muted)}

/* 书页详情 + 目录 */
.wrap{max-width:720px;margin:0 auto;padding:0 20px}
.bookhead{display:flex;gap:18px;align-items:flex-start;padding:24px 0 6px}
.bookhead img{width:122px;border-radius:6px;box-shadow:0 6px 18px rgba(33,28,23,.24)}
.bookhead .info{flex:1;min-width:0}
.bookhead h1{font-family:'Noto Serif SC',serif;margin:2px 0 6px;font-size:1.4rem;letter-spacing:1px}
.bookhead .by{font-size:.8rem;color:var(--muted)}
.tags{margin:10px 0 0}
.tags span{display:inline-block;font-size:.72rem;color:var(--accent);background:var(--soft);border-radius:2px;padding:2px 8px;margin:0 6px 6px 0}
.blurb{color:var(--fg);opacity:.88;font-size:.92rem;line-height:1.85;margin:16px 0 4px}
.toc-h{display:flex;align-items:center;gap:12px;margin:24px 0 2px;color:var(--muted);font-size:.78rem;letter-spacing:3px}
.toc-h::before,.toc-h::after{content:"";flex:1;height:1px;background:var(--line)}
.toc{list-style:none;padding:0;margin:6px 0 80px}
.toc li a{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:15px 4px;border-bottom:1px solid var(--line)}
.toc li a .nm{font-size:.95rem;color:var(--fg)}
.toc li a .cn{color:var(--muted);font-size:.72rem;font-variant-numeric:tabular-nums;flex:none}
.toc li a:active{background:var(--soft)}

/* 阅读页 */
.reader{min-height:100vh}
.r-appbar{position:fixed;top:0;left:0;right:0;z-index:30;display:flex;align-items:center;gap:10px;height:50px;padding:0 12px;background:color-mix(in srgb,var(--bg) 90%,transparent);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);border-bottom:1px solid var(--line);transition:transform .25s}
.r-appbar .ic{font-size:1.5rem;line-height:1;width:28px;text-align:center}
.r-appbar .t{flex:1;font-size:.88rem;color:var(--fg);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.page{max-width:680px;margin:0 auto;padding:72px 22px 96px}
article{font-family:'Noto Serif SC',serif}
article h1.title{font-family:'Noto Serif SC',serif;font-size:1.4rem;text-align:center;margin:6px 0 6px;letter-spacing:1px;line-height:1.5}
article .sub{text-align:center;color:var(--muted);font-size:.74rem;letter-spacing:1px}
article .sub::after{content:"";display:block;width:28px;height:2px;background:var(--accent);opacity:.55;margin:14px auto 30px;border-radius:2px}
article p{margin:0 0 1.1em;text-indent:2em}
article h2{font-family:'Noto Serif SC',serif;font-size:1.12rem;margin:1.9em 0 1em;text-align:center}
article h3{font-size:1.02rem;margin:1.5em 0 .7em}
hr.break{border:none;text-align:center;margin:2em 0}
hr.break::before{content:"❖";color:var(--accent);opacity:.5;font-size:.9rem;letter-spacing:6px}
.chap-end{text-align:center;color:var(--muted);font-size:.76rem;margin:38px 0 0;letter-spacing:3px}
:root[data-font=song] article{font-family:'Noto Serif SC','Songti SC',serif}
:root[data-font=hei] article{font-family:'Noto Sans SC',sans-serif}
:root[data-font=kai] article{font-family:'Kaiti SC','STKaiti','KaiTi','Noto Serif SC',serif}
:root[data-lh=tight] article p{line-height:1.65}
:root[data-lh=normal] article p{line-height:1.95}
:root[data-lh=loose] article p{line-height:2.3}
:root[data-fs=s] article{font-size:.95rem}
:root[data-fs=m] article{font-size:1.08rem}
:root[data-fs=l] article{font-size:1.22rem}
:root[data-fs=xl] article{font-size:1.36rem}

/* 底部工具条 */
.r-botbar{position:fixed;left:0;right:0;bottom:0;z-index:30;display:flex;height:calc(56px + env(safe-area-inset-bottom));padding-bottom:env(safe-area-inset-bottom);background:color-mix(in srgb,var(--bg) 92%,transparent);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);border-top:1px solid var(--line);transition:transform .25s}
.r-botbar a,.r-botbar button{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;background:none;border:0;color:var(--fg);font-family:inherit;font-size:.68rem;cursor:pointer}
.r-botbar .ic{font-size:1.15rem;line-height:1}
.r-botbar .dim{color:var(--muted);opacity:.4}
.reader.bars-off .r-appbar{transform:translateY(-100%)}
.reader.bars-off .r-botbar{transform:translateY(100%)}

/* 设置面板 */
.mask{position:fixed;inset:0;z-index:40;background:rgba(0,0,0,.32);opacity:0;visibility:hidden;transition:opacity .25s}
.mask.on{opacity:1;visibility:visible}
.sheet{position:fixed;left:0;right:0;bottom:0;z-index:50;background:var(--card);border-top:1px solid var(--line);border-radius:16px 16px 0 0;padding:16px 18px calc(18px + env(safe-area-inset-bottom));transform:translateY(115%);transition:transform .3s cubic-bezier(.4,0,.2,1);box-shadow:0 -8px 30px rgba(0,0,0,.20)}
.sheet.on{transform:translateY(0)}
.sheet h4{margin:2px 0 16px;font-size:.86rem;color:var(--fg);text-align:center;letter-spacing:3px;font-weight:500}
.row{display:flex;align-items:center;margin:0 0 15px;gap:10px}
.row .lab{width:34px;flex:none;font-size:.78rem;color:var(--muted)}
.seg{flex:1;display:flex;gap:8px}
.seg button{flex:1;padding:9px 4px;border:1px solid var(--line);background:transparent;color:var(--fg);border-radius:8px;font-family:inherit;font-size:.82rem;cursor:pointer;transition:.15s}
.seg button.on{background:var(--accent);color:#fff;border-color:var(--accent)}
.sw{flex:1;display:flex;gap:10px}
.sw button{flex:1;height:40px;border-radius:8px;border:2px solid var(--line);cursor:pointer;font-family:inherit;font-size:.72rem;color:#211C17}
.sw button.on{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent) inset}
.sw .b-paper{background:#F4EFE4}.sw .b-eye{background:#DEE7D4}.sw .b-yellow{background:#F2E4C9}.sw .b-night{background:#16191B;color:#C7C0B3}

footer.site{text-align:center;color:var(--muted);font-size:.72rem;padding:8px 20px 30px;letter-spacing:2px}`;

const FONTS = `<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@400;700&family=Noto+Sans+SC:wght@400;500;700&display=swap" rel="stylesheet">`;

// 在 <head> 早执行：读取本地存储的阅读偏好，防止首屏闪烁。
const BOOT = `<script>(function(){var d=document.documentElement,g=function(k,v){try{return localStorage.getItem(k)||v}catch(e){return v}};d.dataset.theme=g('qj-theme','paper');d.dataset.font=g('qj-font','song');d.dataset.lh=g('qj-lh','normal');d.dataset.fs=g('qj-fs','m');})();</script>`;

// 阅读页底部「阅读设置」面板。
const SETTINGS_SHEET = `<div class="mask" id="mask"></div>
<section class="sheet" id="sheet">
  <h4>阅读设置</h4>
  <div class="row"><span class="lab">字号</span><div class="seg">
    <button data-opt="fs" data-val="s" onclick="__qj.fs('s')">小</button>
    <button data-opt="fs" data-val="m" onclick="__qj.fs('m')">标准</button>
    <button data-opt="fs" data-val="l" onclick="__qj.fs('l')">大</button>
    <button data-opt="fs" data-val="xl" onclick="__qj.fs('xl')">特大</button>
  </div></div>
  <div class="row"><span class="lab">背景</span><div class="sw">
    <button class="b-paper" data-opt="theme" data-val="paper" onclick="__qj.theme('paper')">米白</button>
    <button class="b-eye" data-opt="theme" data-val="eye" onclick="__qj.theme('eye')">护眼</button>
    <button class="b-yellow" data-opt="theme" data-val="yellow" onclick="__qj.theme('yellow')">纸黄</button>
    <button class="b-night" data-opt="theme" data-val="night" onclick="__qj.theme('night')">夜间</button>
  </div></div>
  <div class="row"><span class="lab">字体</span><div class="seg">
    <button data-opt="font" data-val="song" onclick="__qj.font('song')">宋体</button>
    <button data-opt="font" data-val="hei" onclick="__qj.font('hei')">黑体</button>
    <button data-opt="font" data-val="kai" onclick="__qj.font('kai')">楷体</button>
  </div></div>
  <div class="row"><span class="lab">行距</span><div class="seg">
    <button data-opt="lh" data-val="tight" onclick="__qj.lh('tight')">紧凑</button>
    <button data-opt="lh" data-val="normal" onclick="__qj.lh('normal')">适中</button>
    <button data-opt="lh" data-val="loose" onclick="__qj.lh('loose')">宽松</button>
  </div></div>
</section>`;

const READER_JS = `<script>
(function(){
  var d=document.documentElement, reader=document.getElementById('reader');
  function sync(){
    document.querySelectorAll('[data-opt]').forEach(function(el){
      el.classList.toggle('on', d.dataset[el.getAttribute('data-opt')]===el.getAttribute('data-val'));
    });
  }
  function set(k,a,v){d.dataset[a]=v;try{localStorage.setItem(k,v)}catch(e){}sync();}
  window.__qj={theme:function(v){set('qj-theme','theme',v)},font:function(v){set('qj-font','font',v)},lh:function(v){set('qj-lh','lh',v)},fs:function(v){set('qj-fs','fs',v)}};
  var mask=document.getElementById('mask'),sheet=document.getElementById('sheet');
  window.__openSet=function(){mask.classList.add('on');sheet.classList.add('on')};
  window.__closeSet=function(){mask.classList.remove('on');sheet.classList.remove('on')};
  mask&&mask.addEventListener('click',window.__closeSet);
  var page=document.getElementById('page');
  page&&page.addEventListener('click',function(e){
    if(e.target.closest('a,button')) return;
    if(window.getSelection&&String(window.getSelection()).length) return;
    reader.classList.toggle('bars-off');
  });
  sync();
})();
</script>`;

function page({ title, body, depth, fonts = true }) {
  const base = "../".repeat(depth);
  return `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${escapeHtml(title)}</title>
${BOOT}
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
    if (meta.hidden) continue; // 在 book.json 里设 "hidden": true 可把该书从网站下架（稿件保留）
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
    const coverFile = meta.cover ? path.basename(meta.cover) : "cover.svg";
    books.push({ dir, meta, chapters, coverFile });
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
      const coverSrc = `books/${m.slug}/${b.coverFile}`;
      return `<a class="book" href="books/${m.slug}/index.html">
  <img class="cover" src="${escapeAttr(coverSrc)}" alt="${escapeAttr(m.title)} 封面">
  <p class="bt">${escapeHtml(m.title)}</p>
  <p class="bd">${escapeHtml(m.blurb || "")}</p>
  <span class="badge">${escapeHtml(m.status || "")} · ${b.chapters.length} 章</span>
</a>`;
    })
    .join("\n");

  const home = `<header class="brand">
  <div class="logo"><b>青</b>简 阅读</div>
  ${site.subtitle ? `<div class="sub">${escapeHtml(site.subtitle)}</div>` : ""}
  <div class="rule"></div>
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

    if (m.cover) {
      await fs.copyFile(
        path.join(BOOKS_DIR, b.dir, m.cover),
        path.join(bookDir, b.coverFile)
      );
    } else {
      await fs.writeFile(path.join(bookDir, "cover.svg"), svgCover(m));
    }

    const totalWords = b.chapters.reduce((s, c) => s + c.words, 0);
    const coverSrc = b.coverFile;

    const tocItems = b.chapters
      .map((c) => {
        const label = c.num
          ? `第${String(c.num).padStart(3, "0")}章 ${c.title.replace(/^第\s*\d+\s*章[\s\-—:：]*/, "")}`
          : c.title;
        return `<li><a href="${chapHref(c.num)}"><span class="nm">${escapeHtml(label)}</span><span class="cn">${c.words} 字</span></a></li>`;
      })
      .join("\n");

    const bookBody = `<header class="appbar"><a class="ic" href="../../index.html" aria-label="返回书架">‹</a><span class="t">${escapeHtml(m.title)}</span><span class="r">${b.chapters.length} 章 · 约 ${Math.round(totalWords / 1000)} 千字</span></header>
<main class="wrap">
  <div class="bookhead">
    <img src="${escapeAttr(coverSrc)}" alt="${escapeAttr(m.title)} 封面">
    <div class="info">
      <h1>${escapeHtml(m.title)}</h1>
      <div class="by">${escapeHtml(m.author || "佚名")} 著 · ${escapeHtml(m.status || "")}</div>
      <div class="tags">${(m.tags || []).map((t) => `<span>${escapeHtml(t)}</span>`).join("")}</div>
    </div>
  </div>
  <p class="blurb">${escapeHtml(m.blurb || "")}</p>
  <div class="toc-h">目录</div>
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
      const prevBtn = prev
        ? `<a href="${chapHref(prev.num)}"><span class="ic">‹</span><span>上一章</span></a>`
        : `<button class="dim"><span class="ic">‹</span><span>上一章</span></button>`;
      const nextBtn = next
        ? `<a href="${chapHref(next.num)}"><span class="ic">›</span><span>下一章</span></a>`
        : `<button class="dim"><span class="ic">›</span><span>下一章</span></button>`;
      const body = `<div class="reader" id="reader">
  <header class="r-appbar">
    <a class="ic" href="index.html" aria-label="返回目录">‹</a>
    <span class="t">${escapeHtml(m.title)}</span>
  </header>
  <main class="page" id="page">
    <article>
      <h1 class="title">${escapeHtml(titleLabel)}</h1>
      <p class="sub">${escapeHtml(m.title)} · ${c.words}字</p>
${c.html}
      <p class="chap-end">— 本章完 —</p>
    </article>
  </main>
  <nav class="r-botbar">
    ${prevBtn}
    <a href="index.html"><span class="ic">☰</span><span>目录</span></a>
    <button onclick="__openSet()"><span class="ic">Aa</span><span>设置</span></button>
    ${nextBtn}
  </nav>
  ${SETTINGS_SHEET}
</div>
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
