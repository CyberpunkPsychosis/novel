import Foundation

// MARK: - 平台域模型（本地原型阶段）
// 这些类型支撑账号 / 墨滴 / 通知 / 授权 / 分支图，全部本地持久化。
// 接后端时，把 LibraryStore 的读写换成网络请求即可，类型基本不变。

// MARK: 账号
struct LocalUser: Codable, Identifiable, Hashable {
    var id: String                 // 用 handle 作为唯一 id
    var handle: String             // @handle
    var penName: String            // 笔名 / 显示名
    var bio: String = "慢慢长大的书架"
    var avatarColorHex: String = "#A65A3C"
    var avatarUrl: String? = nil

    /// 种子书的作者（非当前用户），用于区分"别人的书"。
    static let seedAuthorName = "观山海"
}

// MARK: 墨滴（积分）流水
enum CreditReason: String, Codable {
    case signup, checkin, buy, unlock, fork, royalty, refund
    var label: String {
        switch self {
        case .signup:  return "注册奖励"
        case .checkin: return "每日签到"
        case .buy:     return "购买墨滴"
        case .unlock:  return "解锁下载"
        case .fork:    return "解锁改编"
        case .royalty: return "作品分成"
        case .refund:  return "退还"
        }
    }
}

struct CreditTxn: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var delta: Int                 // +赚 / -花
    var reason: CreditReason
    var note: String = ""
    var date: Date
}

/// 每日签到状态：记录上次签到日与连续天数。
struct DailyCheckin: Codable, Hashable {
    var lastDate: String = ""      // yyyy-MM-dd
    var streak: Int = 0
}

// MARK: 通知
enum NotifType: String, Codable {
    case forkRequest, forkApproved, forkDenied, newBranch, checkin, system
    var icon: String {
        switch self {
        case .forkRequest:  return "arrow.triangle.branch"
        case .forkApproved: return "checkmark.seal"
        case .forkDenied:   return "xmark.seal"
        case .newBranch:    return "arrow.triangle.pull"
        case .checkin:      return "drop.fill"
        case .system:       return "bell"
        }
    }
}

struct AppNotification: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var type: NotifType
    var actor: String = ""
    var text: String
    var read: Bool = false
    var date: Date
}

// MARK: fork 授权 / 请求
struct ForkPermission: Codable, Hashable {
    var allowContinue: Bool = true     // 允许续写
    var allowAdapt: Bool = true        // 允许改编
    var requireApproval: Bool = true   // 是否需要作者审批（false=可直接解锁/创作）
    var allowDownload: Bool = true     // 允许下载
    var priceMolDi: Int = 0            // 解锁 fork / 下载的价格（墨滴）
}

enum ForkReqStatus: String, Codable {
    case pending, approved, denied
    var label: String {
        switch self {
        case .pending:  return "待审批"
        case .approved: return "已同意"
        case .denied:   return "已拒绝"
        }
    }
}

struct ForkRequest: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var requester: String          // 申请人笔名
    var bookID: String
    var fromChapter: Int
    var mode: String               // "续写" / "改编"
    var status: ForkReqStatus = .pending
    var date: Date
}

// MARK: 审核状态
enum ModerationStatus: String, Codable {
    case pending, approved, rejected
    var label: String {
        switch self {
        case .pending:  return "审核中"
        case .approved: return "已通过"
        case .rejected: return "未通过"
        }
    }
    var colorHex: String {
        switch self {
        case .pending:  return "#C7A17A"
        case .approved: return "#6E7042"
        case .rejected: return "#A65A3C"
        }
    }
}

// MARK: 分支图（段落 DAG）
struct BranchNode: Identifiable, Hashable {
    var id: String                 // 段落 id
    var bookID: String
    var chapterIndex: Int
    var title: String
    var authorName: String
    var isEnding: Bool = false
    var content: String? = nil     // 合成支线节点的正文（真实章节则留空，从书里取）
}

enum EdgeType: String { case linear, branch, merge }

struct BranchEdge: Identifiable, Hashable {
    var id: String { "\(from)->\(to)" }
    var from: String
    var to: String
    var type: EdgeType
    var label: String = ""         // 分叉点上展示给读者的选项文案
    var branchAuthor: String = ""  // 这条支线的作者
}

struct BranchGraph {
    var nodes: [BranchNode]
    var edges: [BranchEdge]
    func outgoing(_ nodeID: String) -> [BranchEdge] { edges.filter { $0.from == nodeID } }
    func incoming(_ nodeID: String) -> [BranchEdge] { edges.filter { $0.to == nodeID } }
    func node(_ id: String) -> BranchNode? { nodes.first { $0.id == id } }
    var startNodes: [BranchNode] { nodes.filter { n in !edges.contains { $0.to == n.id } } }
}

// MARK: 社区（里程碑4）
struct BookReview: Codable, Identifiable, Hashable {
    var id: String
    var author: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
    var bookID: String
    var text: String
    var date: Date
    var likeCount: Int
    var likedByMe: Bool
}

/// /feed 返回项（映射成 CommunityEvent 展示）。
struct FeedItem: Codable, Identifiable, Hashable {
    var id: String
    var who: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
    var text: String
    var meta: String
    var bookId: String?
}

struct CommunityStats: Codable, Hashable {
    var creations: Int = 0
    var reviews: Int = 0
    var likesReceived: Int = 0
}

struct LikeResult: Codable { var liked: Bool; var likeCount: Int }

// 话题
struct TopicItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var author: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
    var replyCount: Int
    var meta: String
}
struct TopicReplyItem: Codable, Identifiable, Hashable {
    var id: String
    var author: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
    var text: String
    var date: Date
}
struct TopicDetail: Codable, Hashable {
    var id: String
    var title: String
    var body: String
    var author: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
    var date: Date
    var replies: [TopicReplyItem]
}

// 俱乐部
struct ClubItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var intro: String
    var memberCount: Int
    var joinedByMe: Bool
}
struct ClubMemberItem: Codable, Hashable {
    var penName: String
    var avatarColorHex: String
    var avatarUrl: String? = nil
}
struct ClubDetail: Codable, Hashable {
    var id: String
    var name: String
    var intro: String
    var memberCount: Int
    var joinedByMe: Bool
    var members: [ClubMemberItem]
}
struct JoinResult: Codable { var joined: Bool; var memberCount: Int }

// MARK: 日期工具
enum DayKey {
    static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    static func key(_ d: Date) -> String { fmt.string(from: d) }
}
