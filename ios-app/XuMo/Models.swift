import Foundation

// MARK: - 数据模型
// 本地原型阶段：所有数据来自 App 内置 seed.json + 用户在本机创建的"改编/续写"。
// 以后接后端时，把 LibraryStore 的加载/保存换成网络请求即可，模型基本不变。

struct Chapter: Codable, Identifiable, Hashable {
    var id: String { "\(index)-\(title)" }
    var index: Int
    var title: String
    var content: String
}

struct Book: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var author: String
    var blurb: String
    var tags: [String]
    var tagline: String
    var coverColors: [String]
    var coverAccent: String
    var status: String
    /// 若本书是对另一本书的改编/续写，这里是父书 id；原创为 nil。
    var forkOf: String?
    /// 改编时记录"从父书第几章分叉"（续写=接在末章之后）。原创/续写为 nil。
    var forkFromChapter: Int?
    /// 是否用户在本机创建（区分种子书与"我的创作"）。
    var isUserCreated: Bool = false
    var chapters: [Chapter]
    /// 服务器审核状态：approved / pending / rejected（缺省视为 approved）。
    var moderationStatus: String = "approved"
    /// 审核理由（仅作者本人可见，rejected 时有值）。
    var moderationReason: String = ""
    /// 是否当前用户拥有（服务器按 ownerId 判定，替代用笔名比对）。
    var isMine: Bool = false
    /// 服务器聚合的评分均值与人数。
    var ratingAvg: Double = 0
    var ratingCount: Int = 0
    /// 1..5 星各自人数（评分分布）。
    var ratingDist: [Int] = []

    enum CodingKeys: String, CodingKey {
        case id, title, author, blurb, tags, tagline
        case coverColors, coverAccent, status
        case forkOf, forkFromChapter, isUserCreated, chapters
        case moderationStatus, moderationReason, isMine
        case ratingAvg, ratingCount, ratingDist
    }
}

// 在 extension 里写自定义解码，既容错（seed.json 可缺字段），又保留默认的逐成员初始化器。
extension Book {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        author = (try? c.decode(String.self, forKey: .author)) ?? "佚名"
        blurb = (try? c.decode(String.self, forKey: .blurb)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        tagline = (try? c.decode(String.self, forKey: .tagline)) ?? ""
        coverColors = (try? c.decode([String].self, forKey: .coverColors)) ?? ["#0e0b0a", "#241a17", "#3a2a22"]
        coverAccent = (try? c.decode(String.self, forKey: .coverAccent)) ?? "#d9a441"
        status = (try? c.decode(String.self, forKey: .status)) ?? ""
        forkOf = try? c.decodeIfPresent(String.self, forKey: .forkOf)
        forkFromChapter = try? c.decodeIfPresent(Int.self, forKey: .forkFromChapter)
        isUserCreated = (try? c.decode(Bool.self, forKey: .isUserCreated)) ?? false
        chapters = (try? c.decode([Chapter].self, forKey: .chapters)) ?? []
        moderationStatus = (try? c.decode(String.self, forKey: .moderationStatus)) ?? "approved"
        moderationReason = (try? c.decode(String.self, forKey: .moderationReason)) ?? ""
        isMine = (try? c.decode(Bool.self, forKey: .isMine)) ?? false
        ratingAvg = (try? c.decode(Double.self, forKey: .ratingAvg)) ?? 0
        ratingCount = (try? c.decode(Int.self, forKey: .ratingCount)) ?? 0
        ratingDist = (try? c.decode([Int].self, forKey: .ratingDist)) ?? []
    }
}
