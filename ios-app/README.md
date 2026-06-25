# 续墨 · iOS 原型（XuMo）

一个 **SwiftUI 原生**的小说阅读 / 发布 App 原型，核心卖点是：**可以对已发布的小说「改编 / 续写」（fork）**。

> 「续墨」是工作名（续＝续写/分叉，墨＝写作），随时可改。
> 当前为**本地原型**：数据全部来自 App 内置的 `seed.json`（用现有 4 本书做种子）+ 你在本机创建的改编/续写。**不联后端**，主要用来验证核心假设：*读者真的会去 fork 别人的书吗*。

## 它现在能做什么

- **发现**：书架网格，浏览内置的 4 本书（《一面》《前夫他装作不爱我》《回声邮局》《法眼》）。
- **阅读**：按章翻页的阅读器，上一章 / 下一章。
- **改编 / 续写**（核心）：在任意一本书里点「改编 / 续写」——
  - *续写*：保留原书全部章节，在末尾接上你写的新章节；
  - *改编*：保留原书第 1…N 章，从某一章另起一条你自己的支线。
  - 平台**不提供 AI**：你用习惯的任何工具写好，粘进正文即可。
- **关系可见**：书详情页显示「改编自《X》」和「由此开出的支线（N）」，形成分叉树的雏形。
- **我的创作**：你创建的支线都在这里，本地持久化（存在 `Documents/userBooks.json`）。

## 怎么打开运行（需要 Mac + Xcode 16+）

> 这个仓库是在 Linux 环境里生成的，**没法在这里编译 iOS**。编译/运行/上架都要在 Mac 的 Xcode 里做。

1. 把 `ios-app/` 拷到 Mac 上。
2. 双击 `XuMo.xcodeproj` 用 Xcode 打开（工程用了 Xcode 16 的"文件夹同步组"，**需 Xcode 16 或更高**）。
3. 选个模拟器（如 iPhone 15），点 ▶︎ 运行。

### 如果工程打不开 / Xcode 版本较低（60 秒手动建项目）

工程文件是手写的，万一打不开，照这个做，等价且更稳：

1. Xcode → File → New → Project → **iOS App**；
   - Interface: **SwiftUI**，Language: **Swift**，名字填 **XuMo**；
   - 创建后，把 Xcode 自动生成的 `XuMoApp.swift` / `ContentView.swift` 删掉。
2. 把本目录下的 **`XuMo/` 整个文件夹**拖进 Xcode 项目（勾选 *Copy items if needed* + *Create groups*）。
   - 确认 `XuMo/Resources/seed.json` 出现在 **Target → Build Phases → Copy Bundle Resources** 里（没有就手动 +）。
3. Target → General → Minimum Deployments 设 **iOS 17.0**。
4. 运行。

## 代码结构

```
ios-app/
├─ XuMo.xcodeproj/         # 手写的 Xcode 工程（Xcode 16+）
└─ XuMo/
   ├─ XuMoApp.swift        # @main，TabView：发现 / 我的创作
   ├─ Models.swift         # Book / Chapter 数据模型
   ├─ LibraryStore.swift   # 数据仓库：加载种子+用户创作、创建 fork、持久化、颜色工具
   ├─ Views/
   │  ├─ CoverView.swift        # 用配色程序化生成封面（暂不用图片）
   │  ├─ LibraryView.swift      # 发现页书架 + 我的创作列表
   │  ├─ BookDetailView.swift   # 书详情：简介/标签/目录/改编入口/支线树
   │  ├─ ReaderView.swift       # 阅读器
   │  └─ ForkComposerView.swift # 改编/续写编辑器（核心）
   └─ Resources/
      └─ seed.json         # 内置种子数据（由仓库现有书籍导出）
```

## 下一步可做（按优先级）

1. **验证核心假设**：找几个真人用这个原型，看「改编/续写」到底有没有人用、用得爽不爽。这一步最重要，先别堆功能。
2. **接后端**：把 `LibraryStore` 的本地读写换成 API（账号、发布、分叉关系持久化、跨设备）。模型基本不用动。
3. **授权 / 署名链**：发布时让作者选许可（可否被改编 / 是否署名 / 是否分成）——这是整个平台的命门，建议在接后端时一起设计。
4. **发现与筛选**：榜单、口碑、人工策展，把好的支线浮上来（对抗 AI 烂稿洪水）。
5. **合规**：AI 生成内容标识 / 审核（中文区上线前必须处理）。

## 注意

- 种子数据里的几本书是本仓库的作品，仅用于原型演示。
- Bundle id 现为占位 `com.example.xumo`，上架前改成你自己的。
- 没放自定义 App 图标（用 Xcode 默认占位），不影响运行。
