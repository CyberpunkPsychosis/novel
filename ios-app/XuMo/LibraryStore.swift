import Foundation
import SwiftUI

/// 数据仓库：内置种子书 + 用户改编/续写 + 阅读进度，本地持久化。
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    /// bookID -> 最近读到的章节 index
    @Published private(set) var readingProgress: [String: Int] = [:]

    // MARK: 平台状态（账号 / 墨滴 / 通知 / 授权 / 审核）
    @Published var currentUser: LocalUser?
    @Published private(set) var creditTxns: [CreditTxn] = []
    @Published private(set) var checkin = DailyCheckin()
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var permissions: [String: ForkPermission] = [:]
    @Published private(set) var forkRequests: [ForkRequest] = []
    /// 当前用户已解锁 fork/下载权的书 id
    @Published private(set) var unlockedBooks: Set<String> = []
    /// bookID -> 审核状态（已废弃：审核状态随 Book.moderationStatus 下发，保留以免影响旧引用）
    @Published private(set) var moderation: [String: ModerationStatus] = [:]
    /// 我对各书的评分（bookID -> 1...5）
    @Published private(set) var myRatings: [String: Int] = [:]
    /// 综合热度榜（GET /rankings）
    @Published private(set) var rankedBooks: [Book] = []
    /// 全站活动流（GET /feed）
    @Published private(set) var feed: [CommunityEvent] = []
    /// 我的社区统计（GET /me/stats）
    @Published private(set) var myStats = CommunityStats()
    /// 书架：bookID -> 状态(want/reading/read)
    @Published private(set) var shelf: [String: String] = [:]
    /// 社区话题
    @Published private(set) var topics: [TopicItem] = []
    /// 书友俱乐部
    @Published private(set) var clubs: [ClubItem] = []
    /// 我发出的改编/续写申请
    @Published private(set) var outgoingRequests: [ForkRequest] = []

    /// 服务器下发的书（含种子+他人已发布+我已同步的）；离线时来自缓存，再退到 bundle seed。
    private var serverBooks: [Book] = []

    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var userBooksURL: URL { docs.appendingPathComponent("userBooks.json") }
    private var remoteCacheURL: URL { docs.appendingPathComponent("remoteBooks.json") }
    private var progressURL: URL { docs.appendingPathComponent("progress.json") }
    private var userURL: URL { docs.appendingPathComponent("user.json") }
    private var creditsURL: URL { docs.appendingPathComponent("credits.json") }
    private var checkinURL: URL { docs.appendingPathComponent("checkin.json") }
    private var notifURL: URL { docs.appendingPathComponent("notifications.json") }
    private var permURL: URL { docs.appendingPathComponent("permissions.json") }
    private var forkReqURL: URL { docs.appendingPathComponent("forkRequests.json") }
    private var unlocksURL: URL { docs.appendingPathComponent("unlocks.json") }

    init() {
        reload()
        loadProgress()
        if readingProgress.isEmpty { seedDemoProgress() }
        loadPlatform()
    }

    func reload() {
        // 服务器书：优先本地缓存，离线/首启回退到 bundle 内 seed.json。
        serverBooks = loadRemoteCache() ?? Self.loadSeed()
        rebuild()
    }

    /// 合并「服务器书 + 仅本地的书（未上云的草稿/本地 fork）」，服务器优先、按 id 去重。
    private func rebuild() {
        let serverIDs = Set(serverBooks.map { $0.id })
        var out = serverBooks
        out.append(contentsOf: loadUserBooks().filter { !serverIDs.contains($0.id) })
        books = out
    }

    private func loadRemoteCache() -> [Book]? {
        guard let data = try? Data(contentsOf: remoteCacheURL) else { return nil }
        return try? JSONDecoder().decode([Book].self, from: data)
    }
    private func saveRemoteCache(_ b: [Book]) {
        if let data = try? JSONEncoder().encode(b) { try? data.write(to: remoteCacheURL, options: .atomic) }
    }

    // MARK: 查询
    func book(id: String) -> Book? { books.first { $0.id == id } }
    var seedAndPublished: [Book] { books }
    var myCreations: [Book] { books.filter { $0.isUserCreated } }
    func forks(of bookID: String) -> [Book] { books.filter { $0.forkOf == bookID } }
    func forkCount(of bookID: String) -> Int { forks(of: bookID).count }

    // MARK: 阅读进度
    func markRead(bookID: String, chapterIndex: Int) {
        readingProgress[bookID] = chapterIndex
        saveProgress()
        // 异步上报进度（失败不阻塞阅读，下次登录/翻页再同步）。
        guard isLoggedIn else { return }
        // 开始阅读自动置「在读」（已读过则不动）。
        if shelf[bookID] == nil || shelf[bookID] == "want" { setShelf(bookID, status: "reading") }
        Task {
            let body = try? JSONEncoder().encode(ProgressPayload(bookId: bookID, chapterIndex: chapterIndex))
            _ = try? await APIClient.shared.request("/me/progress", method: "PUT",
                                                    bodyData: body, auth: true) as OKResponse
        }
    }
    func lastReadIndex(_ bookID: String) -> Int? { readingProgress[bookID] }

    /// 已读进度 0...1
    func fraction(for book: Book) -> Double {
        guard let last = readingProgress[book.id], !book.chapters.isEmpty else { return 0 }
        let idxs = book.chapters.map { $0.index }.sorted()
        let pos = idxs.firstIndex(of: last) ?? 0
        return Double(pos + 1) / Double(idxs.count)
    }
    func caption(for book: Book) -> String {
        guard let last = readingProgress[book.id] else { return book.author }
        let idxs = book.chapters.map { $0.index }.sorted()
        let pos = (idxs.firstIndex(of: last) ?? 0) + 1
        return "\(book.author) · \(pos) / \(idxs.count) 章"
    }
    /// 在读书目（有进度的种子书，按最近读优先粗排）
    var inProgressBooks: [Book] {
        books.filter { readingProgress[$0.id] != nil && !$0.isUserCreated }
    }

    // MARK: 改编 / 续写
    enum ForkMode { case continuation, adaptation }

    @discardableResult
    func createFork(from parent: Book, mode: ForkMode, fromChapter: Int,
                    newChapterTitle: String, newContent: String, myPenName: String) -> Book {
        var base: [Chapter]
        switch mode {
        case .continuation: base = parent.chapters
        case .adaptation:   base = parent.chapters.filter { $0.index <= fromChapter }
        }
        let nextIndex = (base.map { $0.index }.max() ?? 0) + 1
        let t = newChapterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        base.append(Chapter(index: nextIndex,
                            title: t.isEmpty ? "第\(nextIndex)章" : t,
                            content: newContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        let label = (mode == .continuation) ? "续写" : "改编"
        let author = !myPenName.isEmpty ? myPenName : (currentUser?.penName ?? "我")
        let new = Book(
            id: "user-\(UUID().uuidString.prefix(8))",
            title: "\(parent.title)·\(label)",
            author: author,
            blurb: "\(label)自《\(parent.title)》。" + String(parent.blurb.prefix(40)),
            tags: parent.tags, tagline: "\(label)自《\(parent.title)》",
            coverColors: parent.coverColors, coverAccent: parent.coverAccent,
            status: "创作中", forkOf: parent.id,
            forkFromChapter: (mode == .adaptation) ? fromChapter : nil,
            isUserCreated: true, chapters: base)
        var mine = loadUserBooks(); mine.append(new); saveUserBooks(mine); reload()
        submitForReview(new.id)                  // 本地"审核中→通过"过场
        // 上云：服务器按原参数重建 fork、记录分叉关系并通知原作者；成功后替换本地副本。
        Task {
            await uploadFork(localID: new.id, parentId: parent.id, mode: mode,
                             fromChapter: fromChapter, title: newChapterTitle, content: newContent)
        }
        return new
    }

    func deleteUserBook(id: String) {
        var mine = loadUserBooks(); mine.removeAll { $0.id == id }; saveUserBooks(mine); reload()
    }

    /// 上传一部原创新作（非 fork）。作者用外部 AI/手写完成后粘进来。
    @discardableResult
    func createOriginal(title: String, blurb: String, tags: [String],
                        firstChapterTitle: String, content: String) -> Book {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = Book(
            id: "user-\(UUID().uuidString.prefix(8))",
            title: t.isEmpty ? "未命名新作" : t,
            author: currentUser?.penName ?? "我",
            blurb: blurb.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags, tagline: "原创",
            coverColors: ["#1A2332", "#3a2a22", "#6E7042"], coverAccent: "#C7A17A",
            status: "创作中", forkOf: nil, forkFromChapter: nil, isUserCreated: true,
            chapters: [Chapter(index: 1,
                               title: firstChapterTitle.isEmpty ? "第1章" : firstChapterTitle,
                               content: content.trimmingCharacters(in: .whitespacesAndNewlines))])
        var mine = loadUserBooks(); mine.append(new); saveUserBooks(mine); reload()
        submitForReview(new.id)
        // 立即落本地草稿（离线可用），同时尝试上云；成功后服务器版替换本地草稿。
        Task { await uploadBook(new) }
        return new
    }

    /// 把本地新作上传到服务器；成功则删本地草稿并刷新（避免重复显示）。
    private func uploadBook(_ local: Book) async {
        guard isLoggedIn else { return }
        do {
            let body = try JSONEncoder().encode(NewBookPayload(from: local))
            let _: Book = try await APIClient.shared.request("/books", method: "POST",
                                                             bodyData: body, auth: true)
            await MainActor.run {
                var mine = loadUserBooks(); mine.removeAll { $0.id == local.id }; saveUserBooks(mine)
            }
            await refreshBooks()
        } catch {
            // 上云失败：保留本地草稿，下次可重试。
        }
    }

    /// 把本地 fork 上传到服务器（服务器据原参数重建并校验改编权）；成功删本地副本并刷新。
    private func uploadFork(localID: String, parentId: String, mode: ForkMode,
                            fromChapter: Int, title: String, content: String) async {
        guard isLoggedIn else { return }
        let modeStr = mode == .continuation ? "continuation" : "adaptation"
        do {
            let body = try JSONEncoder().encode(ForkCreatePayload(
                parentId: parentId, mode: modeStr, fromChapter: fromChapter,
                newChapterTitle: title, newContent: content))
            let _: Book = try await APIClient.shared.request("/forks", method: "POST",
                                                             bodyData: body, auth: true)
            await MainActor.run {
                var mine = loadUserBooks(); mine.removeAll { $0.id == localID }; saveUserBooks(mine)
            }
            await refreshBooks()
        } catch {
            // 上云失败：保留本地副本。
        }
    }

    // MARK: 持久化
    private static func loadSeed() -> [Book] {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Book].self, from: data)) ?? []
    }
    private func loadUserBooks() -> [Book] {
        guard let data = try? Data(contentsOf: userBooksURL) else { return [] }
        return (try? JSONDecoder().decode([Book].self, from: data)) ?? []
    }
    private func saveUserBooks(_ b: [Book]) {
        if let data = try? JSONEncoder().encode(b) { try? data.write(to: userBooksURL, options: .atomic) }
    }
    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressURL) else { return }
        readingProgress = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(readingProgress) { try? data.write(to: progressURL, options: .atomic) }
    }
    /// 首次启动给几本书预置进度，让"继续阅读/在读"不空。
    private func seedDemoProgress() {
        let demo = ["huisheng": 6, "fayan": 28, "yimian": 4]
        for (id, idx) in demo where book(id: id) != nil { readingProgress[id] = idx }
        saveProgress()
    }
}

// MARK: - 平台功能（账号 / 墨滴 / 通知 / 授权 / 审核 / 分支图）
extension LibraryStore {

    // MARK: 加载 / 持久化助手
    func loadPlatform() {
        currentUser   = decode(userURL, LocalUser.self)
        creditTxns    = decode(creditsURL, [CreditTxn].self) ?? []
        checkin       = decode(checkinURL, DailyCheckin.self) ?? DailyCheckin()
        notifications = decode(notifURL, [AppNotification].self) ?? []
        permissions   = decode(permURL, [String: ForkPermission].self) ?? [:]
        forkRequests  = decode(forkReqURL, [ForkRequest].self) ?? []
        unlockedBooks = Set(decode(unlocksURL, [String].self) ?? [])
        // 平台数据以服务器为准；这里加载的本地缓存仅作离线兜底。
    }

    private func decode<T: Decodable>(_ url: URL, _ type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func save<T: Encodable>(_ value: T, to url: URL) {
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: 账号
    var isLoggedIn: Bool { currentUser != nil }

    func logout() {
        currentUser = nil
        TokenStore.clear()
        try? FileManager.default.removeItem(at: userURL)
    }

    /// 启动时校验登录态：token 失效（如账号已删/过期）就自动登出，避免卡在死账号。
    @MainActor
    func verifySession() async {
        guard isLoggedIn else { return }
        do {
            let me: LocalUser = try await APIClient.shared.request("/me", auth: true)
            currentUser = me
            save(currentUser, to: userURL)
        } catch APIError.unauthorized {
            logout()
        } catch {
            // 离线等其它错误：保留本地会话。
        }
    }

    // MARK: 真实登录（接后端 · 里程碑1）
    @MainActor
    func signInWithApple(identityToken: String, penName: String?) async throws {
        let body = try JSONEncoder().encode(ApplePayload(identityToken: identityToken, penName: penName))
        let res: AuthResponse = try await APIClient.shared.request("/auth/apple", method: "POST", bodyData: body)
        await applyLogin(res)
    }

    /// 开发期邮箱通道（没有 Apple 开发者账号时用；后端 DEV_EMAIL_LOGIN=true 才开）。
    @MainActor
    func devLogin(email: String, penName: String?) async throws {
        let body = try JSONEncoder().encode(DevLoginPayload(email: email, penName: penName))
        let res: AuthResponse = try await APIClient.shared.request("/auth/dev", method: "POST", bodyData: body)
        await applyLogin(res)
    }

    @MainActor
    private func applyLogin(_ res: AuthResponse) async {
        TokenStore.token = res.token
        currentUser = res.user
        save(currentUser, to: userURL)
        await refreshBooks()
        await loadRemoteProgress()
        await syncPlatform()
    }

    // MARK: 云端书库 / 进度同步
    @MainActor
    func refreshBooks() async {
        do {
            let remote: [Book] = try await APIClient.shared.request("/books")
            serverBooks = remote
            saveRemoteCache(remote)
            // 已同步到服务器的本地草稿就地删除，避免重复。
            let ids = Set(remote.map { $0.id })
            var mine = loadUserBooks()
            let before = mine.count
            mine.removeAll { ids.contains($0.id) }
            if mine.count != before { saveUserBooks(mine) }
            rebuild()
        } catch {
            // 离线/失败：保留当前 serverBooks（缓存或 seed），不清空。
        }
    }

    @MainActor
    func loadRemoteProgress() async {
        do {
            let p: [String: Int] = try await APIClient.shared.request("/me/progress", auth: true)
            readingProgress = p
            saveProgress()
        } catch {
            // 离线：保留本地进度。
        }
    }

    // MARK: 墨滴（服务器记账；本地为乐观缓存，sync 回拉对账）
    var molDi: Int { creditTxns.reduce(0) { $0 + $1.delta } }

    func addCredits(_ amount: Int, reason: CreditReason, note: String = "") {
        creditTxns.insert(CreditTxn(delta: amount, reason: reason, note: note, date: Date()), at: 0)
        save(creditTxns, to: creditsURL)
    }
    @discardableResult
    func spendCredits(_ amount: Int, reason: CreditReason, note: String = "") -> Bool {
        guard molDi >= amount else { return false }
        addCredits(-amount, reason: reason, note: note)
        return true
    }
    /// 买墨滴（里程碑3 换 StoreKit）：乐观加 + 上云 + 回拉对账。
    func buyMolDi(_ amount: Int) {
        addCredits(amount, reason: .buy, note: "购买 \(amount) 墨滴")
        Task {
            let body = try? JSONEncoder().encode(BuyPayload(amount: amount))
            _ = try? await APIClient.shared.request("/me/credits/buy", method: "POST", bodyData: body, auth: true) as BalanceResponse
            await loadCredits()
        }
    }

    // MARK: 每日签到
    var canCheckinToday: Bool { checkin.lastDate != DayKey.key(Date()) }

    @discardableResult
    func doCheckin() -> Int {
        let today = DayKey.key(Date())
        guard checkin.lastDate != today else { return 0 }
        let yesterday = DayKey.key(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        checkin.streak = (checkin.lastDate == yesterday) ? checkin.streak + 1 : 1
        checkin.lastDate = today
        save(checkin, to: checkinURL)
        let award = 10 + min(checkin.streak, 7) * 2
        addCredits(award, reason: .checkin, note: "连续签到 \(checkin.streak) 天")   // 乐观
        Task {
            // 把客户端本地日期发给服务器，按用户的"今天"记，避免 UTC 错位。
            let body = try? JSONEncoder().encode(["day": today])
            _ = try? await APIClient.shared.request("/me/checkin", method: "POST", bodyData: body, auth: true) as CheckinResponse
            await loadCredits()
            await loadNotifications()
        }
        return award
    }

    // MARK: 通知
    var unreadCount: Int { notifications.filter { !$0.read }.count }

    /// 本地乐观插一条（服务器真通知会在下次 sync 覆盖）。
    func pushNotification(_ type: NotifType, actor: String = "", text: String) {
        notifications.insert(AppNotification(type: type, actor: actor, text: text, date: Date()), at: 0)
        save(notifications, to: notifURL)
    }
    func markAllNotificationsRead() {
        notifications = notifications.map { var n = $0; n.read = true; return n }
        save(notifications, to: notifURL)
        Task { _ = try? await APIClient.shared.request("/me/notifications/read-all", method: "POST", auth: true) as OKResponse }
    }

    // MARK: 授权 / 所有权
    func isOwner(_ book: Book) -> Bool {
        book.isUserCreated && book.author == currentUser?.penName
    }
    func permission(for bookID: String) -> ForkPermission { permissions[bookID] ?? ForkPermission() }

    /// 拉某本书的授权进缓存（BookDetailView 出现时调用）。
    @MainActor
    func loadPermission(_ bookID: String) async {
        if let p: ForkPermission = try? await APIClient.shared.request("/books/\(bookID)/permission") {
            permissions[bookID] = p
            save(permissions, to: permURL)
        }
    }

    func setPermission(_ p: ForkPermission, for bookID: String) {
        permissions[bookID] = p; save(permissions, to: permURL)   // 乐观
        Task {
            let body = try? JSONEncoder().encode(p)
            _ = try? await APIClient.shared.request("/books/\(bookID)/permission", method: "PUT", bodyData: body, auth: true) as ForkPermission
        }
    }

    // MARK: fork 解锁 / 申请
    func hasForkAccess(_ book: Book) -> Bool { isOwner(book) || unlockedBooks.contains(book.id) }

    @discardableResult
    func unlockFork(_ book: Book) -> Bool {
        let price = permission(for: book.id).priceMolDi
        if price > 0 {
            guard spendCredits(price, reason: .fork, note: "解锁《\(book.title)》改编权") else { return false }
        }
        unlockedBooks.insert(book.id); save(Array(unlockedBooks), to: unlocksURL)   // 乐观
        Task {
            let ok = (try? await APIClient.shared.request("/books/\(book.id)/unlock", method: "POST", auth: true) as OKResponse) != nil
            await loadCredits()
            if !ok { await loadUnlocks() }   // 服务器拒绝（余额不足等）→ 回滚为真状态
        }
        return true
    }

    @discardableResult
    func requestFork(book: Book, fromChapter: Int, mode: String) async -> Bool {
        let body = try? JSONEncoder().encode(ForkRequestPayload(bookId: book.id, fromChapter: fromChapter, mode: mode))
        return (try? await APIClient.shared.request("/fork-requests", method: "POST",
                                                    bodyData: body, auth: true) as ForkRequest) != nil
    }

    /// 我作为作者收到的改编/续写申请（已由服务器筛为「针对我创作的书」）。
    var incomingForkRequests: [ForkRequest] {
        forkRequests.filter { req in book(id: req.bookID).map { isOwner($0) } ?? false }
    }

    func decide(_ req: ForkRequest, approve: Bool) {
        if let i = forkRequests.firstIndex(where: { $0.id == req.id }) {
            forkRequests[i].status = approve ? .approved : .denied   // 乐观
            save(forkRequests, to: forkReqURL)
        }
        Task {
            let body = try? JSONEncoder().encode(DecidePayload(approve: approve))
            _ = try? await APIClient.shared.request("/fork-requests/\(req.id)/decide", method: "POST", bodyData: body, auth: true) as ForkRequest
            await loadIncomingRequests()
            await loadCredits()
            await loadNotifications()
        }
    }

    // MARK: 审核（服务器 DeepSeek 真审核；状态随 Book 下发）
    func moderationStatus(for bookID: String) -> ModerationStatus {
        guard let raw = book(id: bookID)?.moderationStatus else { return .approved }
        return ModerationStatus(rawValue: raw) ?? .approved
    }

    /// 上传后服务器异步审核；这里只在几秒后再刷一次书库，把"审核中→通过/驳回"拉回来。
    func submitForReview(_ bookID: String) {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await refreshBooks()
        }
    }

    // MARK: 评分
    /// 我对各书的评分缓存（bookID -> 1...5）。
    @MainActor
    func loadMyRatings() async {
        if let r: [String: Int] = try? await APIClient.shared.request("/me/ratings", auth: true) {
            myRatings = r
        }
    }
    func myRating(for bookID: String) -> Int { myRatings[bookID] ?? 0 }

    func rate(_ bookID: String, value: Int) {
        myRatings[bookID] = value   // 乐观
        Task {
            let body = try? JSONEncoder().encode(["value": value])
            // 不再整库刷新（重且抖动）：用返回的均值/分布就地更新该书。
            if let r = try? await APIClient.shared.request("/books/\(bookID)/rating", method: "POST", bodyData: body, auth: true) as RatingResponse {
                await MainActor.run { applyRating(bookID, avg: r.ratingAvg, count: r.ratingCount) }
            }
        }
    }

    /// 就地更新某书的评分均值/人数（避免整库 refresh）。
    @MainActor
    private func applyRating(_ bookID: String, avg: Double, count: Int) {
        if let i = serverBooks.firstIndex(where: { $0.id == bookID }) {
            serverBooks[i].ratingAvg = avg; serverBooks[i].ratingCount = count
        }
        if let i = books.firstIndex(where: { $0.id == bookID }) {
            books[i].ratingAvg = avg; books[i].ratingCount = count
        }
    }

    // MARK: 榜单
    @MainActor
    func loadRankings() async {
        if let r: [Book] = try? await APIClient.shared.request("/rankings") {
            rankedBooks = r
        }
    }

    // MARK: 充值入账（StoreKit 校验后调用）
    @MainActor
    func grantPurchase(productId: String, transactionId: String) async {
        let body = try? JSONEncoder().encode(["productId": productId, "transactionId": transactionId])
        _ = try? await APIClient.shared.request("/me/credits/purchase", method: "POST", bodyData: body, auth: true) as BalanceResponse
        await loadCredits()
    }

    // MARK: 社区（活动流 / 书评 / 统计）
    @MainActor
    func loadFeed() async {
        guard let items: [FeedItem] = try? await APIClient.shared.request("/feed") else { return }
        feed = items.map { CommunityEvent(who: $0.who, avatarColorHex: $0.avatarColorHex,
                                          avatarUrl: $0.avatarUrl, text: $0.text, meta: $0.meta) }
    }

    @MainActor
    func loadMyStats() async {
        if let s: CommunityStats = try? await APIClient.shared.request("/me/stats", auth: true) {
            myStats = s
        }
    }

    /// 拉某本书的书评（登录则带 token 以得到 likedByMe）。
    func reviews(of bookID: String) async -> [BookReview] {
        (try? await APIClient.shared.request("/books/\(bookID)/reviews", auth: isLoggedIn)) ?? []
    }

    @discardableResult
    func postReview(bookID: String, text: String) async -> Bool {
        let body = try? JSONEncoder().encode(["text": text])
        let ok = (try? await APIClient.shared.request("/books/\(bookID)/reviews", method: "POST",
                                                      bodyData: body, auth: true) as BookReview) != nil
        if ok { await loadFeed(); await loadMyStats() }
        return ok
    }

    func likeReview(_ reviewID: String) async -> LikeResult? {
        try? await APIClient.shared.request("/reviews/\(reviewID)/like", method: "POST", auth: true)
    }

    func myReviews() async -> [BookReview] {
        (try? await APIClient.shared.request("/me/reviews", auth: true)) ?? []
    }

    // MARK: 书架（想读/在读/读过）
    func shelfStatus(_ bookID: String) -> String? { shelf[bookID] }
    func booksOnShelf(_ status: String) -> [Book] { books.filter { shelf[$0.id] == status } }

    @MainActor
    func loadShelf() async {
        if let s: [String: String] = try? await APIClient.shared.request("/me/shelf", auth: true) {
            shelf = s
        }
    }

    /// 设书架状态；status 传 nil 表示移出书架。
    func setShelf(_ bookID: String, status: String?) {
        if let status { shelf[bookID] = status } else { shelf[bookID] = nil }   // 乐观
        Task {
            if let status {
                let body = try? JSONEncoder().encode(["status": status])
                _ = try? await APIClient.shared.request("/books/\(bookID)/shelf", method: "PUT", bodyData: body, auth: true) as [String: String]
            } else {
                _ = try? await APIClient.shared.request("/books/\(bookID)/shelf", method: "DELETE", auth: true) as OKResponse
            }
        }
    }

    // MARK: 个人资料
    @MainActor
    func updateProfile(penName: String, bio: String, avatarColorHex: String) async {
        let body = try? JSONEncoder().encode(["penName": penName, "bio": bio, "avatarColorHex": avatarColorHex])
        if let u: LocalUser = try? await APIClient.shared.request("/me", method: "PUT", bodyData: body, auth: true) {
            currentUser = u
            save(currentUser, to: userURL)
        }
    }

    @MainActor
    func uploadAvatar(_ data: Data) async {
        if let r: AvatarResponse = try? await APIClient.shared.upload("/me/avatar", fileData: data,
                                                                      filename: "avatar.jpg", mime: "image/jpeg") {
            currentUser = r.user
            save(currentUser, to: userURL)
        }
    }

    // MARK: 我发出的申请
    @MainActor
    func loadOutgoingRequests() async {
        if let r: [ForkRequest] = try? await APIClient.shared.request("/me/fork-requests/outgoing", auth: true) {
            outgoingRequests = r
        }
    }

    // MARK: 俱乐部详情 / 讨论
    func clubDetail(_ id: String) async -> ClubDetail? {
        try? await APIClient.shared.request("/clubs/\(id)", auth: isLoggedIn)
    }
    func clubTopics(_ id: String) async -> [TopicItem] {
        (try? await APIClient.shared.request("/clubs/\(id)/topics")) ?? []
    }
    @discardableResult
    func postClubTopic(_ clubID: String, title: String, body: String) async -> Bool {
        let payload = try? JSONEncoder().encode(["title": title, "body": body])
        return (try? await APIClient.shared.request("/clubs/\(clubID)/topics", method: "POST", bodyData: payload, auth: true) as TopicItem) != nil
    }

    // MARK: 话题
    @MainActor
    func loadTopics() async {
        if let t: [TopicItem] = try? await APIClient.shared.request("/topics") { topics = t }
    }

    @discardableResult
    func postTopic(title: String, body: String) async -> Bool {
        let payload = try? JSONEncoder().encode(["title": title, "body": body])
        let ok = (try? await APIClient.shared.request("/topics", method: "POST", bodyData: payload, auth: true) as TopicItem) != nil
        if ok { await loadTopics() }
        return ok
    }

    func topicDetail(_ id: String) async -> TopicDetail? {
        try? await APIClient.shared.request("/topics/\(id)")
    }

    func postReply(topicID: String, text: String) async -> TopicReplyItem? {
        let payload = try? JSONEncoder().encode(["text": text])
        let r: TopicReplyItem? = try? await APIClient.shared.request("/topics/\(topicID)/replies", method: "POST", bodyData: payload, auth: true)
        if r != nil { await loadTopics() }   // 回帖数变了，刷新列表
        return r
    }

    // MARK: 俱乐部
    @MainActor
    func loadClubs() async {
        if let c: [ClubItem] = try? await APIClient.shared.request("/clubs", auth: isLoggedIn) { clubs = c }
    }

    func toggleClub(_ clubID: String) {
        // 乐观切换
        if let i = clubs.firstIndex(where: { $0.id == clubID }) {
            clubs[i].joinedByMe.toggle()
            clubs[i].memberCount += clubs[i].joinedByMe ? 1 : -1
        }
        Task {
            if let r = try? await APIClient.shared.request("/clubs/\(clubID)/join", method: "POST", auth: true) as JoinResult {
                await MainActor.run {
                    if let i = clubs.firstIndex(where: { $0.id == clubID }) {
                        clubs[i].joinedByMe = r.joined; clubs[i].memberCount = r.memberCount
                    }
                }
            } else { await loadClubs() }
        }
    }

    // MARK: 平台数据同步（登录/启动把服务器真数据拉进 @Published 缓存）
    @MainActor
    func syncPlatform() async {
        guard isLoggedIn else { return }
        await loadCredits()
        await loadNotifications()
        await loadIncomingRequests()
        await loadUnlocks()
        await loadMyRatings()
        await loadRankings()
        await loadFeed()
        await loadMyStats()
        await loadShelf()
        await loadTopics()
        await loadClubs()
        await loadOutgoingRequests()
    }

    @MainActor
    func loadCredits() async {
        guard let res: CreditsResponse = try? await APIClient.shared.request("/me/credits", auth: true) else { return }
        creditTxns = res.txns
        checkin = res.checkin
        save(creditTxns, to: creditsURL); save(checkin, to: checkinURL)
    }
    @MainActor
    func loadNotifications() async {
        guard let n: [AppNotification] = try? await APIClient.shared.request("/me/notifications", auth: true) else { return }
        notifications = n
        save(notifications, to: notifURL)
    }
    @MainActor
    func loadIncomingRequests() async {
        guard let r: [ForkRequest] = try? await APIClient.shared.request("/me/fork-requests/incoming", auth: true) else { return }
        forkRequests = r
        save(forkRequests, to: forkReqURL)
    }
    @MainActor
    func loadUnlocks() async {
        guard let ids: [String] = try? await APIClient.shared.request("/me/unlocks", auth: true) else { return }
        unlockedBooks = Set(ids)
        save(Array(unlockedBooks), to: unlocksURL)
    }

    // MARK: 分支图（完全由真实 fork 关系生成）
    func branchGraph(for root: Book) -> BranchGraph {
        spineWithChildren(root)
    }

    private func nodeID(_ bookID: String, _ idx: Int) -> String { "\(bookID)#\(idx)" }

    /// 节点 → 实际正文（真实章节取书里的；合成支线取 node.content）。
    func nodeText(_ node: BranchNode) -> (title: String, body: String) {
        if let b = book(id: node.bookID), let ch = b.chapters.first(where: { $0.index == node.chapterIndex }) {
            return (ch.title, ch.content)
        }
        return (node.title, node.content ?? "（\(node.authorName) 续写的支线）")
    }

    /// 通用：主书线性脊柱 + 真实 fork 子书作为支线。
    private func spineWithChildren(_ root: Book) -> BranchGraph {
        var nodes: [BranchNode] = []; var edges: [BranchEdge] = []
        let spine = root.chapters.sorted { $0.index < $1.index }
        let hasForks = !forks(of: root.id).isEmpty
        for (i, ch) in spine.enumerated() {
            nodes.append(BranchNode(id: nodeID(root.id, ch.index), bookID: root.id,
                                    chapterIndex: ch.index, title: ch.title, authorName: root.author,
                                    isEnding: i == spine.count - 1 && !hasForks))
            if i > 0 {
                edges.append(BranchEdge(from: nodeID(root.id, spine[i-1].index),
                                        to: nodeID(root.id, ch.index), type: .linear))
            }
        }
        for child in forks(of: root.id) {
            let forkPoint = child.forkFromChapter ?? (root.chapters.map { $0.index }.max() ?? 0)
            let newCh = child.chapters.filter { $0.index > forkPoint }.sorted { $0.index < $1.index }
            guard let first = newCh.first else { continue }
            edges.append(BranchEdge(from: nodeID(root.id, forkPoint), to: nodeID(child.id, first.index),
                                    type: .branch, label: child.tagline, branchAuthor: child.author))
            for (j, ch) in newCh.enumerated() {
                nodes.append(BranchNode(id: nodeID(child.id, ch.index), bookID: child.id,
                                        chapterIndex: ch.index, title: ch.title, authorName: child.author,
                                        isEnding: j == newCh.count - 1))
                if j > 0 {
                    edges.append(BranchEdge(from: nodeID(child.id, newCh[j-1].index),
                                            to: nodeID(child.id, ch.index), type: .linear))
                }
            }
        }
        return BranchGraph(nodes: nodes, edges: edges)
    }
}

// MARK: 颜色工具
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            self = Color(red: Double((v & 0xFF0000) >> 16)/255,
                         green: Double((v & 0x00FF00) >> 8)/255,
                         blue: Double(v & 0x0000FF)/255)
        } else { self = Color(red: 0.1, green: 0.1, blue: 0.12) }
    }
}
