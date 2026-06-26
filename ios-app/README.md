# 续墨 / 书艺之阁 · iOS 原型（XuMo）

SwiftUI 原生小说阅读 / 发布 App 原型，核心卖点：**可对已发布的小说「改编 / 续写」（fork）**。
视觉按「品·书阁 / The Artful Shelf」UI Kit 1:1 重做（暖纸底 + 复古书籍色 + 衬线 + 植物线描背景）。

> 本地原型：数据来自内置 `seed.json`（现有 4 本书 101 章）+ 本机创建的改编/续写 + 演示数据，不联后端。

## 进入流程
启动闪屏（书艺之阁 logo + 植物背景 + 主推书，约 1.5 秒）→ 淡入主界面，默认停在「首页」。

## 底部 5 个 Tab
- **首页**：搜索栏 + 精选故事（FeaturedCard）+ 本周必读（横滑）+ 继续阅读（带进度）
- **书店**：精辑推荐 + 新书上架（横滑）+ 畅销榜单（序号+评分）
- **书架**：在读（进度）+ 我的创作（改编/续写）+ 收藏（网格）
- **社区**：热门话题（横幅）+ 书友俱乐部 + 最近活动（综合动态流，含真实改编/续写事件）
- **我的**：头像 + 统计块 + 我的书评 / 阅读历史 / 我的创作 / 设置

## 核心功能（fork）
任意书详情页点「改编/续写」→ 续写（末章后追加）或 改编（从某章另起支线）→ 生成新书，记录 `forkOf`/分叉树；书详情显示「改编自《X》」与「由此开出的支线」；社区动态流出现该事件；阅读器记录进度，回填首页/书架的「继续阅读/在读」。

## 设计系统（取自 UI Kit）
- 颜色：Cream `#F9F5F1` / Deep Blue `#1A2332` / Terracotta `#B17D6B` / Bronze Gold `#C7A17A` / Olive `#6E7042`
- 字体：衬线（书名/作者/标题）+ 系统无衬线（正文）
- 背景：作者提供的植物线描素材（`HomeBackground` ← IMG_9479）
- 真实封面：`cover-<id>`（法眼/前夫/回声/一面）

## 怎么运行（需 Mac + Xcode 16+）
1. 拷 `ios-app/` 到 Mac，双击 `XuMo.xcodeproj`（用了 Xcode 16 文件夹同步组）。
2. 选模拟器（iPhone 15）▶︎ 运行。
3. 打不开/旧版 Xcode：新建 iOS App(SwiftUI, 名 XuMo, iOS 17)，删模板文件，把 `XuMo/` 文件夹拖进去（Create groups），确认 `seed.json` 在 Copy Bundle Resources，运行。

## 代码结构
```
XuMo/
├─ XuMoApp.swift        # @main + 启动闪屏→5 tab 主界面 + bookDestination
├─ Theme.swift          # 配色/衬线/导航栏外观
├─ Components.swift     # SectionHeader/TagChip/RatingStars/ProgressRow/GridCover/FeaturedCard/CategoryBanner/SearchBar 等
├─ Models.swift         # Book / Chapter
├─ LibraryStore.swift   # 数据仓库：种子+fork+阅读进度，持久化；Color(hex:)
├─ MockData.swift       # 社区动态/俱乐部/榜单/评分/个人资料（演示）
├─ Views/
│  ├─ SplashView / HomeView / StoreView / ShelfView / CommunityView / ProfileView
│  ├─ BookDetailView / ReaderView / ForkComposerView / CoverView
└─ Assets.xcassets/     # HomeBackground + cover-fayan/qianfu/huisheng/yimian
```

## 下一步
验证「有没有人愿意 fork 别人的书」→ 接后端（账号/发布/分叉关系/跨设备）→ 授权署名链 → 发现与筛选 → 合规（AI 内容标识/审核）。
真实植物角饰/水彩、App 图标、浅色之外的主题可后补。
