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
    /// 这本书是否有可视化的分支（真实 fork 或 demo）。
    private var hasBranches: Bool { !children.isEmpty || book.id == "huisheng" }

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
                            RatingStars(value: MockData.rating(book.id))
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
        .sheet(isPresented: $showFork) {
            ForkComposerView(parent: book).environmentObject(store)
        }
        .sheet(isPresented: $showPermissions) {
            PermissionEditor(book: book).environmentObject(store)
        }
        .bookDestination(store)
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
                store.requestFork(book: book, fromChapter: book.chapters.last?.index ?? 1, mode: "续写")
                toast = "已发出申请，等作者同意"
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
