import SwiftUI

/// 改编 / 续写编辑器——平台核心动作。平台不提供 AI，作者自带工具写好粘进来。
struct ForkComposerView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let parent: Book

    @State private var mode: LibraryStore.ForkMode = .continuation
    @State private var fromChapter: Int = 1
    @State private var penName: String = ""
    @State private var chapterTitle: String = ""
    @State private var content: String = ""
    @State private var createdID: String?

    private var chapterIndices: [Int] { parent.chapters.map { $0.index }.sorted() }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    Section {
                        Picker("方式", selection: $mode) {
                            Text("续写").tag(LibraryStore.ForkMode.continuation)
                            Text("改编").tag(LibraryStore.ForkMode.adaptation)
                        }
                        .pickerStyle(.segmented)

                        if mode == .adaptation {
                            Picker("从第几章分叉", selection: $fromChapter) {
                                ForEach(chapterIndices, id: \.self) { i in
                                    Text(chapterTitleFor(i)).tag(i)
                                }
                            }
                        }
                    } header: {
                        Text("基于《\(parent.title)》")
                    } footer: {
                        Text(mode == .continuation
                             ? "保留原书全部 \(parent.chapters.count) 章，在后面新增你写的章节。"
                             : "保留原书第 1…\(fromChapter) 章，从这里另开一条你自己的线。")
                    }
                    .listRowBackground(Theme.surface)

                    Section("笔名") {
                        TextField("不填默认显示「我」", text: $penName)
                    }
                    .listRowBackground(Theme.surface)

                    Section("新章节标题") {
                        TextField("例：第N章 · 标题", text: $chapterTitle)
                    }
                    .listRowBackground(Theme.surface)

                    Section {
                        TextEditor(text: $content)
                            .frame(minHeight: 220)
                            .font(Theme.serif(16))
                            .scrollContentBackground(.hidden)
                    } header: {
                        Text("正文")
                    } footer: {
                        Text("用你习惯的任何 AI 或纯手写都行，写好粘进来。平台只负责发布与改编关系，不限制你怎么创作。")
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("改编 / 续写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { publish() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("已发布", isPresented: Binding(
                get: { createdID != nil }, set: { if !$0 { createdID = nil } })) {
                Button("好") { dismiss() }
            } message: {
                Text("你的支线已生成，可在「我的创作」里看到。")
            }
        }
    }

    private func chapterTitleFor(_ i: Int) -> String {
        parent.chapters.first { $0.index == i }?.title ?? "第\(i)章"
    }

    private func publish() {
        let new = store.createFork(
            from: parent, mode: mode, fromChapter: fromChapter,
            newChapterTitle: chapterTitle, newContent: content, myPenName: penName)
        createdID = new.id
    }
}
