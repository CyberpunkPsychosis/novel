import Foundation

// 本地原型用的演示数据。接后端后由 API 替换。

struct CommunityEvent: Identifiable {
    let id = UUID()
    let who: String
    let avatarColorHex: String
    let text: String
    let meta: String       // 时间 · 类型
}

struct BookClub: Identifiable {
    let id = UUID()
    let name: String
    let members: String
}

struct HotTopic: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let colorHex: String
}

enum MockData {
    // 评分与畅销榜已接服务器真数据（Book.ratingAvg / store.rankedBooks）。
    // 社区话题/俱乐部/动态流仍为演示数据，留待后续里程碑。

    static let hotTopics: [HotTopic] = [
        .init(title: "#《回声邮局》的结局，你怎么读", count: 312, colorHex: "#6E7042"),
        .init(title: "#如果让你改写女主结局", count: 187, colorHex: "#B17D6B"),
    ]

    static let clubs: [BookClub] = [
        .init(name: "言情研究所", members: "2.3k 成员"),
        .init(name: "科幻读书会", members: "1.1k 成员"),
    ]

    /// 静态动态流（fork 事件由 CommunityView 动态拼在前面）
    static let baseFeed: [CommunityEvent] = [
        .init(who: "阿澄", avatarColorHex: "#B17D6B", text: "读完了《法眼》并打了 ★★★★★", meta: "1 小时前 · 阅读"),
        .init(who: "叶知秋", avatarColorHex: "#7C4A38", text: "发表书评：「金缮这个意象用得真好，碎过的地方反而最亮。」", meta: "3 小时前 · 书评"),
        .init(who: "南风", avatarColorHex: "#6E7042", text: "在话题「如果让你改写女主结局」里发了言", meta: "昨天 · 讨论"),
        .init(who: "见月", avatarColorHex: "#1A2332", text: "把《一面》加进了收藏", meta: "昨天 · 收藏"),
    ]

    // 个人资料（演示）
    static let profileName = "墨白"
    static let profileBio = "慢慢长大的书架"
    static let profileStats: [(String, String)] = [
        ("153", "已读书籍"), ("4200", "阅读时长"), ("10.8k", "获赞")
    ]
    static let profileMenu = ["我的书评", "阅读历史", "我的创作", "设置"]
}
