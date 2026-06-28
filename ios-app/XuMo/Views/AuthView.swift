import SwiftUI
import AuthenticationServices

/// 登录页：Sign in with Apple（真账号）+ 开发期邮箱通道。
struct AuthView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var penName = ""
    @State private var showDev = true   // 测试期默认展开邮箱登录（Apple 登录需付费开发者账号）
    @State private var devEmail = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.55)
            ScrollView {
                VStack(spacing: 22) {
                    // 品牌
                    VStack(spacing: 10) {
                        Circle().fill(Theme.terracotta).frame(width: 76, height: 76)
                            .overlay(Text("墨").font(Theme.serif(34, .bold)).foregroundStyle(.white))
                        Text("书艺之阁").font(Theme.serif(26, .bold)).foregroundStyle(Theme.ink)
                        Text("AI 写就，众人续墨").font(.subheadline).foregroundStyle(Theme.sub)
                    }
                    .padding(.top, 56)

                    AuthField(icon: "pencil", placeholder: "笔名（首次登录用，可留空）", text: $penName)
                        .padding(.horizontal, 24)

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn,
                        onRequest: { $0.requestedScopes = [.fullName] },
                        onCompletion: handleApple)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                        .disabled(busy)
                        .opacity(busy ? 0.6 : 1)

                    Text("注册即送 100 墨滴 · 每日签到还能领")
                        .font(.caption).foregroundStyle(Theme.olive)

                    // 开发期邮箱通道（没有 Apple 开发者账号时用）
                    Button {
                        withAnimation { showDev.toggle() }
                    } label: {
                        Text(showDev ? "收起开发登录" : "开发登录（邮箱）")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    if showDev {
                        VStack(spacing: 12) {
                            AuthField(icon: "envelope", placeholder: "邮箱", text: $devEmail)
                            Button { devLogin() } label: {
                                Text("登录").font(.headline).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                                    .background(Theme.terraDeep)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(busy || devEmail.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    }

                    Text("平台不替你写作——你用任何 AI 或手写完成后上传；\n我们负责发布、改编授权与读者社区。")
                        .font(.caption2).foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .padding(.horizontal, 30).padding(.top, 6)
                }
                .padding(.bottom, 40)
            }
            if busy { ProgressView().scaleEffect(1.3).tint(Theme.terraDeep) }
        }
        .alert("登录失败", isPresented: Binding(get: { errorText != nil },
                                            set: { if !$0 { errorText = nil } })) {
            Button("好") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: 动作
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                errorText = "未取得 Apple 凭证"; return
            }
            let name = [cred.fullName?.familyName, cred.fullName?.givenName]
                .compactMap { $0 }.joined()
            let pen = name.isEmpty ? trimmedPen : name
            run { try await store.signInWithApple(identityToken: token, penName: pen) }
        case .failure(let e):
            // 用户取消不算错误
            if (e as? ASAuthorizationError)?.code == .canceled { return }
            errorText = e.localizedDescription
        }
    }

    private func devLogin() {
        run { try await store.devLogin(email: devEmail.trimmingCharacters(in: .whitespaces),
                                       penName: trimmedPen) }
    }

    private var trimmedPen: String? {
        let p = penName.trimmingCharacters(in: .whitespaces)
        return p.isEmpty ? nil : p
    }

    private func run(_ op: @escaping () async throws -> Void) {
        busy = true
        Task { @MainActor in
            do { try await op() }
            catch { errorText = (error as? LocalizedError)?.errorDescription ?? "请稍后重试" }
            busy = false
        }
    }
}

private struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.sub).frame(width: 20)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
