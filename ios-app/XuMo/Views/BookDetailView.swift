import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    @State private var showFork = false
    @State private var showPermissions = false
    @State private var toast: String?

    private var parent: Book? { book.forkOf.flatMap { store.book(id: $0) } }
    private var children: [Book] { store.forks(of: book.id) }
    private var isOwner: Bool { store.isOwner(book) }
    private var perm: ForkPermission { store.permission(for: book.id) }
    private var moderation: ModerationStatus { store.moderationStatus(for: book.id) }
    private var shelf: String? { store.shelfStatus(book.id) }
    /// 这本书是否有可视化的分支（有真实 fork 子书才显示）。
    private var hasBranches: Bool { !children.isEmpty }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        CoverView(book: book).frame(width: 128)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title).font(Theme.serif(24, .bold)).foregroundStyle(Theme.ink)
                            Text(book.author).font(.subheadline).foregroundStyle(Theme.sub)
                            RatingStars(value: book.ratingAvg)
                            HStack(spacing: 6) {
                                if !book.status.isEmpty { TagChip(text: book.status, color: Theme.bronze) }
                                ModerationBadge(status: moderation)
                            }
                            if let parent {
                                NavigationLink(value: parent.id) {
                                    Label("改编自《\(parent.title)》", systemImage: "arrow.uturn.backward")
                                        .font(.caption).foregroundStyle(Theme.terraDeep)
                                }
                            }
                        }
                        Spacer()
                    }

                    if !book.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(book.tags, id: \.self) { TagChip(text: $0) } }
                        }
                    }

                    Text(book.blurb).font(.body).foregroundStyle(Theme.ink.opacity(0.85)).lineSpacing(4)

                    // 审核未通过：仅作者本人能看到理由
                    if book.isMine && moderation == .rejected && !book.moderationReason.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.terraDeep)
                            Text("未通过审核：\(book.moderationReason)")
                                .font(.caption).foregroundStyle(Theme.terraDeep)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.terraDeep.opacity(0.1)))
                    }

                    RatingRow(book: book)

                    HStack(spacing: 12) {
                        NavigationLink {
                            ReaderView(book: book, startIndex: store.lastReadIndex(book.id) ?? (book.chapters.first?.index ?? 1))
                        } label: {
                            Label("开始阅读", systemImage: "book")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.blue).controlSize(.large)

                        forkButton
                    }

                    if hasBranches {
                        NavigationLink { BranchTreeView(root: branchRoot) } label: {
                            HStack {
                                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                Text("查看分支图 · 选支线阅读").font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .foregroundStyle(Theme.terraDeep)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.terraDeep.opacity(0.10)))
                        }.buttonStyle(.plain)
                    }

                    if !children.isEmpty {
                        SectionHeader(title: "由此开出的支线（\(children.count)）")
                        ForEach(children) { c in
                            NavigationLink(value: c.id) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.terraDeep)
                                    VStack(alignment: .leading) {
                                        Text(c.title).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                                        Text(c.author).font(.caption2).foregroundStyle(Theme.sub)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.line)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                            }.buttonStyle(.plain)
                        }
                    }

                    ReviewsSection(book: book)

                    SectionHeader(title: "目录 · \(book.chapters.count) 章")
                    VStack(spacing: 0) {
                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { idx, ch in
                            NavigationLink {
                                ReaderView(book: book, startIndex: ch.index)
                            } label: {
                                HStack {
                                    Text(ch.title).font(.subheadline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.line)
                                }
                                .padding(.vertical, 12)
                            }
                            if idx < book.chapters.count - 1 { Divider().background(Theme.line) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                }
                .padding(20)
            }
        }
        .overlay { if let toast { ToastView(text: toast).onAppear { clearToast() } } }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { store.setShelf(book.id, status: "want"); toast = "已加入「想读」" } label: {
                        Label("想读", systemImage: shelf == "want" ? "checkmark" : "bookmark")
                    }
                    Button { store.setShelf(book.id, status: "reading"); toast = "已标为「在读」" } label: {
                        Label("在读", systemImage: shelf == "reading" ? "checkmark" : "book")
                    }
                    Button { store.setShelf(book.id, status: "read"); toast = "已标为「读过」" } label: {
                        Label("读过", systemImage: shelf == "read" ? "checkmark" : "checkmark.seal")
                    }
                    if shelf != nil {
                        Divider()
                        Button(role: .destructive) { store.setShelf(book.id, status: nil); toast = "已移出书架" } label: {
                            Label("移出书架", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: shelf == nil ? "bookmark" : "bookmark.fill")
                        .foregroundStyle(shelf == nil ? Theme.sub : Theme.terracotta)
                }
            }
        }
        .sheet(isPresented: $showFork) {
            ForkComposerView(parent: book).environmentObject(store)
        }
        .sheet(isPresented: $showPermissions) {
            PermissionEditor(book: book).environmentObject(store)
        }
        .bookDestination(store)
        .task { await store.loadPermission(book.id) }
    }

    private var branchRoot: Book { parent ?? book }

    /// fork 动作按钮——按所有权与授权状态变形。
    @ViewBuilder private var forkButton: some View {
        if isOwner {
            Button { showPermissions = true } label: {
                Label("授权设置", systemImage: "slider.horizontal.3")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Theme.olive).controlSize(.large)
        } else if store.hasForkAccess(book) {
            Button { showFork = true } label: {
                Label("改编/续写", systemImage: "arrow.triangle.branch")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Theme.terraDeep).controlSize(.large)
        } else if !perm.requireApproval {
            // 直接花墨滴解锁
            Button {
                if store.unlockFork(book) { toast = "解锁成功，可以开始改编了" }
                else { toast = "墨滴不足，先去签到/充值" }
            } label: {
                Label(perm.priceMolDi > 0 ? "\(perm.priceMolDi) 墨滴解锁" : "免费解锁改编", systemImage: "lock.open")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Theme.terraDeep).controlSize(.large)
        } else {
            // 需要作者审批
            Button {
                Task { @MainActor in
                    let ok = await store.requestFork(book: book, fromChapter: book.chapters.last?.index ?? 1, mode: "续写")
                    toast = ok ? "已发出申请，等作者同意" : "申请失败，请退出登录后重新登录再试"
                }
            } label: {
                Label("申请改编/续写", systemImage: "paperplane")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Theme.terraDeep).controlSize(.large)
        }
    }

    private func clearToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
    }
}

/// 评分行：显示均值/人数 + 我的可点评分（点星即上报服务器）。
struct RatingRow: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    private var mine: Int { store.myRating(for: book.id) }
    private var maxCount: Int { max(book.ratingDist.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.ratingCount > 0 ? String(format: "%.1f", book.ratingAvg) : "暂无评分")
                        .font(Theme.serif(18, .bold)).foregroundStyle(Theme.ink)
                    if book.ratingCount > 0 {
                        Text("\(book.ratingCount) 人评分").font(.caption2).foregroundStyle(Theme.sub)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mine > 0 ? "我的评分" : "点星评分").font(.caption2).foregroundStyle(Theme.sub)
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= mine ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundStyle(i <= mine ? Theme.bronze : Theme.line)
                                .onTapGesture { store.rate(book.id, value: i) }
                        }
                    }
                }
            }
            // 评分分布（5★→1★）
            if book.ratingCount > 0 && book.ratingDist.count == 5 {
                VStack(spacing: 3) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        let c = book.ratingDist[star - 1]
                        HStack(spacing: 6) {
                            Text("\(star)★").font(.caption2).foregroundStyle(Theme.sub).frame(width: 22, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.line.opacity(0.4))
                                    Capsule().fill(Theme.bronze)
                                        .frame(width: geo.size.width * CGFloat(c) / CGFloat(maxCount))
                                }
                            }.frame(height: 6)
                            Text("\(c)").font(.caption2).foregroundStyle(Theme.sub).frame(width: 22, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
    }
}

/// 书评区：列表 + 写书评 + 点赞。
struct ReviewsSection: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    @State private var reviews: [BookReview] = []
    @State private var composing = false
    @State private var draft = ""
    @State private var posting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "书评（\(reviews.count)）")
                Spacer()
                Button { composing = true } label: {
                    Label("写书评", systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.terraDeep)
                }
            }
            if reviews.isEmpty {
                Text("还没有书评，来写第一条。").font(.subheadline).foregroundStyle(Theme.sub)
            } else {
                ForEach(reviews) { r in ReviewRow(review: r) { await toggleLike(r) } }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $composing) {
            ReviewComposeSheet(draft: $draft, posting: $posting) { await submit() }
        }
    }

    private func reload() async { reviews = await store.reviews(of: book.id) }

    private func submit() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        posting = true
        let ok = await store.postReview(bookID: book.id, text: text)
        posting = false
        if ok { draft = ""; composing = false; await reload() }
    }

    private func toggleLike(_ r: BookReview) async {
        guard let res = await store.likeReview(r.id) else { return }
        if let i = reviews.firstIndex(where: { $0.id == r.id }) {
            reviews[i].likedByMe = res.liked
            reviews[i].likeCount = res.likeCount
        }
    }
}

struct ReviewRow: View {
    let review: BookReview
    let onLike: () async -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: review.avatarUrl, colorHex: review.avatarColorHex, name: review.author, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(review.author).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(review.text).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85)).lineSpacing(3)
            }
            Spacer(minLength: 6)
            Button { Task { await onLike() } } label: {
                HStack(spacing: 3) {
                    Image(systemName: review.likedByMe ? "heart.fill" : "heart")
                    Text("\(review.likeCount)").font(.caption2)
                }
                .foregroundStyle(review.likedByMe ? Theme.terracotta : Theme.sub)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
    }
}

struct ReviewComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: String
    @Binding var posting: Bool
    let onSubmit: () async -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("写书评").font(Theme.serif(18, .semibold)).foregroundStyle(Theme.ink)
                    TextField("说说你的感受…", text: $draft, axis: .vertical)
                        .lineLimit(4...10).padding(12)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("写书评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { Task { await onSubmit() } }
                        .disabled(posting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// 作者编辑授权：允许续写/改编/下载、是否需审批、定价墨滴。
struct PermissionEditor: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var perm = ForkPermission()
    @State private var price: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section {
                        Toggle("允许他人续写", isOn: $perm.allowContinue)
                        Toggle("允许他人改编", isOn: $perm.allowAdapt)
                        Toggle("允许下载", isOn: $perm.allowDownload)
                    } header: { Text("开放范围") }
                    .listRowBackground(Theme.surface)

                    Section {
                        Toggle("需要我逐个审批", isOn: $perm.requireApproval)
                        if !perm.requireApproval {
                            VStack(alignment: .leading) {
                                Text("解锁价格：\(Int(price)) 墨滴").font(.subheadline).foregroundStyle(Theme.ink)
                                Slider(value: $price, in: 0...200, step: 10)
                            }
                        }
                    } header: { Text("授权方式") }
                    footer: { Text(perm.requireApproval ? "他人申请后由你同意，才能改编。" : "他人花墨滴即可直接解锁，无需你逐个同意；价格归你（分成）。") }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("授权设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        perm.priceMolDi = Int(price)
                        store.setPermission(perm, for: book.id)
                        dismiss()
                    }
                }
            }
            .onAppear {
                perm = store.permission(for: book.id)
                price = Double(perm.priceMolDi)
            }
        }
    }
}
