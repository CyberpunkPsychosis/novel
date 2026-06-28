import SwiftUI

/// 通知中心：fork 申请 / 被通过 / 新支线 / 签到 / 系统。进入即标记已读。
struct NotificationsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.45)
            ScrollView {
                VStack(spacing: 10) {
                    if store.notifications.isEmpty {
                        Text("还没有通知。").font(.subheadline).foregroundStyle(Theme.sub).padding(.top, 48)
                    } else {
                        ForEach(store.notifications) { n in NotificationRow(n: n) }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markAllNotificationsRead() }
    }
}

private struct NotificationRow: View {
    let n: AppNotification
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: n.type.icon).font(.subheadline).foregroundStyle(Theme.terraDeep)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.terraDeep.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(n.text).font(.subheadline).foregroundStyle(Theme.ink)
                Text(relative(n.date)).font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
            if !n.read { Circle().fill(Theme.terraDeep).frame(width: 7, height: 7).padding(.top, 4) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(n.read ? Theme.surface : Theme.bronze.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: d, relativeTo: Date())
    }
}
