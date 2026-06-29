import SwiftUI

/// 设置：账号 / 偏好 / 安全与合规 / 关于 / 登出。
struct SettingsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            Form {
                Section("账号") {
                    NavigationLink("编辑资料") { EditProfileView() }
                    LabeledContent("笔名", value: store.currentUser?.penName ?? "—")
                    LabeledContent("用户名", value: "@\(store.currentUser?.handle ?? "—")")
                }
                .listRowBackground(Theme.surface)

                Section("安全与合规") {
                    NavigationLink("举报与拉黑") { ModerationPlaceholder(title: "举报与拉黑",
                        body: "看到不当内容可在作品或用户页举报，我们会尽快处理；也可拉黑用户屏蔽其内容。\n（后端阶段接入真实举报/拉黑与人工审核队列）") }
                    NavigationLink("社区规范") { ModerationPlaceholder(title: "社区规范",
                        body: "1. 题材与尺度宽松，鼓励大胆创作；\n2. 严禁违法、仇恨、未成年相关内容；\n3. 改编他人作品需获授权；\n4. AI 创作请如实标注。") }
                    NavigationLink("隐私政策") { ModerationPlaceholder(title: "隐私政策", body: "（占位：上线前补充正式隐私政策与用户协议。）") }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button(role: .destructive) { store.logout() } label: {
                        Text("退出登录").frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Theme.surface)

                Section { Text("书艺之阁 · 本地原型 v0.2").font(.caption2).foregroundStyle(Theme.sub) }
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModerationPlaceholder: View {
    let title: String
    let body_: String
    init(title: String, body: String) { self.title = title; self.body_ = body }
    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.4)
            ScrollView {
                Text(body_).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85)).lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
