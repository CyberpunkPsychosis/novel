import SwiftUI

/// 编辑作品元信息（作者）：标题 / 简介 / 标签。
struct EditBookView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var title = ""
    @State private var blurb = ""
    @State private var tagsText = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section("标题") { TextField("标题", text: $title) }.listRowBackground(Theme.surface)
                    Section("简介") {
                        TextField("简介", text: $blurb, axis: .vertical).lineLimit(3...8)
                    }.listRowBackground(Theme.surface)
                    Section("标签（逗号分隔）") { TextField("如：言情, 悬疑", text: $tagsText) }
                        .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("编辑作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        busy = true
                        let tags = tagsText.split(whereSeparator: { $0 == "," || $0 == "，" })
                            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        Task { @MainActor in
                            await store.updateBook(book.id, title: title, blurb: blurb, tags: tags,
                                                   coverColors: book.coverColors, coverAccent: book.coverAccent)
                            dismiss()
                        }
                    }.disabled(busy)
                }
            }
            .onAppear {
                title = book.title; blurb = book.blurb; tagsText = book.tags.joined(separator: ", ")
            }
        }
    }
}

/// 追加章节（作者）。上传后重新审核。
struct AppendChapterView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var title = ""
    @State private var content = ""
    @State private var busy = false

    private var nextIndex: Int { (book.chapters.map { $0.index }.max() ?? 0) + 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section("第 \(nextIndex) 章 标题") { TextField("例：第\(nextIndex)章 · 标题", text: $title) }
                        .listRowBackground(Theme.surface)
                    Section {
                        TextEditor(text: $content).frame(minHeight: 240).font(Theme.serif(16))
                            .scrollContentBackground(.hidden)
                    } header: { Text("正文") } footer: { Text("用任何 AI 或手写完成后粘进来；追加后会重新过一遍审核。") }
                        .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("追加章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        busy = true
                        Task { @MainActor in
                            await store.appendChapter(book.id, title: title, content: content)
                            dismiss()
                        }
                    }.disabled(busy || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// 创建俱乐部
struct CreateClubView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var intro = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section("俱乐部名") { TextField("如：悬疑推理社", text: $name) }.listRowBackground(Theme.surface)
                    Section("简介") {
                        TextField("一句话介绍", text: $intro, axis: .vertical).lineLimit(2...5)
                    }.listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("创建俱乐部")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        busy = true
                        Task { @MainActor in
                            await store.createClub(name: name, intro: intro)
                            dismiss()
                        }
                    }.disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
