import SwiftUI

/// 交互式分支阅读：沿分支图前进，遇分叉点让读者选支线（标明作者），可回退。
struct BranchReaderView: View {
    @EnvironmentObject var store: LibraryStore
    let root: Book
    @State private var path: [String]          // 走过的节点 id 栈

    init(root: Book, startNodeID: String) {
        self.root = root
        _path = State(initialValue: [startNodeID])
    }

    private var graph: BranchGraph { store.branchGraph(for: root) }
    private var currentID: String { path.last ?? "" }
    private var current: BranchNode? { graph.node(currentID) }
    private var choices: [BranchEdge] { graph.outgoing(currentID) }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.35)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 1).id("top")
                        if let node = current {
                            let text = store.nodeText(node)
                            HStack(spacing: 6) {
                                Circle().fill(Theme.terraDeep).frame(width: 7, height: 7)
                                Text("本段作者 · \(node.authorName)").font(.caption).foregroundStyle(Theme.sub)
                            }
                            Text(text.title).font(Theme.serif(22, .bold)).foregroundStyle(Theme.ink)
                            ForEach(Array(paragraphs(text.body).enumerated()), id: \.offset) { _, para in
                                if para == "---" {
                                    HStack { Spacer(); Image(systemName: "leaf").font(.caption).foregroundStyle(Theme.olive.opacity(0.6)); Spacer() }.padding(.vertical, 6)
                                } else {
                                    Text(para).font(Theme.serif(18)).foregroundStyle(Theme.ink.opacity(0.9)).lineSpacing(9)
                                }
                            }

                            choicesView(proxy)
                        } else {
                            Text("段落缺失").foregroundStyle(Theme.sub)
                        }
                    }
                    .padding(22)
                }
            }
        }
        .navigationTitle(root.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if path.count > 1 {
                    Button { withAnimation { _ = path.popLast() } } label: { Label("回退", systemImage: "arrow.uturn.backward") }
                }
            }
        }
    }

    @ViewBuilder
    private func choicesView(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if choices.isEmpty {
                HStack { Spacer()
                    Label("这条线到这里就是结局了", systemImage: "flag.checkered")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                    Spacer() }
                .padding(.top, 18)
            } else if choices.count == 1 {
                Button { advance(choices[0].to, proxy) } label: {
                    Label("继续", systemImage: "arrow.right")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.blue).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("故事在这里分叉，你想往哪走？").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                ForEach(choices) { c in
                    Button { advance(c.to, proxy) } label: { ChoiceButton(edge: c, target: graph.node(c.to)) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 24)
    }

    private func advance(_ to: String, _ proxy: ScrollViewProxy) {
        withAnimation { path.append(to) }
        proxy.scrollTo("top", anchor: .top)
    }

    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

/// 分叉点的一个选项：选项文案 + 支线作者。
struct ChoiceButton: View {
    let edge: BranchEdge
    let target: BranchNode?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.terraDeep)
            VStack(alignment: .leading, spacing: 3) {
                Text(edge.label.isEmpty ? (target?.title ?? "继续") : edge.label)
                    .font(Theme.serif(16, .semibold)).foregroundStyle(Theme.ink)
                if !edge.branchAuthor.isEmpty {
                    Text("支线作者 · \(edge.branchAuthor)").font(.caption2).foregroundStyle(Theme.sub)
                }
            }
            Spacer()
            if edge.type == .merge { TagChip(text: "合流", color: Theme.olive) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.line)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.terraDeep.opacity(0.35), lineWidth: 1))
    }
}
