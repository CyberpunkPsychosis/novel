import SwiftUI

/// 上传原创新作：作者在外部用任意 AI 或手写完成后，把成品粘进来发布。
/// 平台不提供写作 AI，只负责发布、授权与读者社区；上传后自动审核。
struct NewWorkComposerView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var blurb = ""
    @State private var tagsText = ""
    @State private var chapterTitle = ""
    @State private var content = ""
    @State private var done = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section("作品名") {
                        TextField("给你的新作起个名字", text: $title)
                    }.listRowBackground(Theme.surface)

                    Section("简介") {
                        TextField("一句话简介", text: $blurb, axis: .vertical).lineLimit(2...4)
                    }.listRowBackground(Theme.surface)

                    Section("标签（逗号分隔）") {
                        TextField("例：言情, 治愈, 现代", text: $tagsText)
                    }.listRowBackground(Theme.surface)

                    Section("第一章标题") {
                        TextField("例：第1章 · 开始", text: $chapterTitle)
                    }.listRowBackground(Theme.surface)

                    Section {
                        TextEditor(text: $content)
                            .frame(minHeight: 220).font(Theme.serif(16)).scrollContentBackground(.hidden)
                    } header: { Text("正文") }
                    footer: { Text("用你习惯的任何 AI 或纯手写都行，写好粘进来。上传后会自动过一遍审核（违法及未成年相关内容会被拦下），通过即发布。") }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("上传新作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("上传") { publish() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("已提交", isPresented: $done) {
                Button("好") { dismiss() }
            } message: {
                Text("作品正在自动审核，通过后即在你的「我的创作」中发布。")
            }
        }
    }

    private func publish() {
        let tags = tagsText.split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        store.createOriginal(title: title, blurb: blurb, tags: tags,
                             firstChapterTitle: chapterTitle, content: content)
        done = true
    }
}
