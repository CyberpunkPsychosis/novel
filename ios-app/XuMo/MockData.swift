import Foundation

// 仅剩活动流的离线兜底演示数据；其余（评分/榜单/话题/俱乐部/书评/统计）均已接服务器真数据。

struct CommunityEvent: Identifiable {
    let id = UUID()
    let who: String
    let avatarColorHex: String
    var avatarUrl: String? = nil
    let text: String
    let meta: String       // 时间 · 类型
}

enum MockData {
    /// 活动流离线兜底（store.feed 拉不到时才显示）
    static let baseFeed: [CommunityEvent] = [
        .init(who: "阿澄", avatarColorHex: "#B17D6B", text: "读完了《法眼》并打了 ★★★★★", meta: "1 小时前 · 阅读"),
        .init(who: "叶知秋", avatarColorHex: "#7C4A38", text: "发表书评：「金缮这个意象用得真好，碎过的地方反而最亮。」", meta: "3 小时前 · 书评"),
        .init(who: "南风", avatarColorHex: "#6E7042", text: "在话题「如果让你改写女主结局」里发了言", meta: "昨天 · 讨论"),
        .init(who: "见月", avatarColorHex: "#1A2332", text: "把《一面》加进了收藏", meta: "昨天 · 收藏"),
    ]
}
