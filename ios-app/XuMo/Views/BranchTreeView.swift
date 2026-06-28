import SwiftUI

/// 分支流程图：把一本书的分叉 DAG 按层级画出来，节点按作者着色，
/// 标出分叉点 / 合流 / 结局；点节点进入交互式分支阅读。
struct BranchTreeView: View {
    @EnvironmentObject var store: LibraryStore
    let root: Book

    private var graph: BranchGraph { store.branchGraph(for: root) }
    private var layers: [[BranchNode]] { layout(graph) }
    private var authorColors: [String: Color] { colorMap(graph) }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.4)
            ScrollView([.vertical, .horizontal]) {
                ZStack(alignment: .topLeading) {
                    // 连线
                    GraphEdges(graph: graph, positions: positions)
                        .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    // 分叉/合流的强调线
                    GraphEdges(graph: graph, positions: positions, only: [.branch, .merge])
                        .stroke(Theme.terraDeep.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    // 节点
                    ForEach(graph.nodes) { node in
                        NavigationLink {
                            BranchReaderView(root: root, startNodeID: node.id)
                        } label: {
                            NodeChip(node: node, color: authorColors[node.authorName] ?? Theme.bronze,
                                     incoming: graph.incoming(node.id), outgoing: graph.outgoing(node.id))
                        }
                        .buttonStyle(.plain)
                        .position(positions[node.id] ?? .zero)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .padding(24)
            }

            VStack { Spacer(); LegendBar(authorColors: authorColors) }
        }
        .navigationTitle("分支图 · \(root.title)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 布局
    private let nodeW: CGFloat = 150
    private let colGap: CGFloat = 64
    private let rowGap: CGFloat = 96

    private var positions: [String: CGPoint] {
        var p: [String: CGPoint] = [:]
        for (depth, layer) in layers.enumerated() {
            for (i, node) in layer.enumerated() {
                let x = CGFloat(i) * (nodeW + colGap) + nodeW / 2
                let y = CGFloat(depth) * rowGap + 34
                p[node.id] = CGPoint(x: x, y: y)
            }
        }
        return p
    }
    private var canvasSize: CGSize {
        let maxCols = layers.map { $0.count }.max() ?? 1
        let w = CGFloat(maxCols) * (nodeW + colGap) + nodeW
        let h = CGFloat(layers.count) * rowGap + 80
        return CGSize(width: max(w, 320), height: max(h, 240))
    }

    /// 按到起点的最长路径分层（DAG 层级布局）。
    private func layout(_ g: BranchGraph) -> [[BranchNode]] {
        var depth: [String: Int] = [:]
        func d(_ id: String, _ seen: Set<String> = []) -> Int {
            if let v = depth[id] { return v }
            guard !seen.contains(id) else { return 0 }
            let ins = g.incoming(id)
            let v = ins.isEmpty ? 0 : (ins.map { d($0.from, seen.union([id])) }.max()! + 1)
            depth[id] = v; return v
        }
        for n in g.nodes { _ = d(n.id) }
        let maxD = depth.values.max() ?? 0
        return (0...maxD).map { lvl in g.nodes.filter { depth[$0.id] == lvl } }
    }

    private func colorMap(_ g: BranchGraph) -> [String: Color] {
        let palette = [Theme.blue, Theme.terraDeep, Theme.olive, Theme.bronze, Theme.terracotta]
        var map: [String: Color] = [:]
        for (i, name) in Array(Set(g.nodes.map { $0.authorName })).sorted().enumerated() {
            map[name] = palette[i % palette.count]
        }
        return map
    }
}

private struct NodeChip: View {
    let node: BranchNode
    let color: Color
    let incoming: [BranchEdge]
    let outgoing: [BranchEdge]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(node.authorName).font(.caption2.weight(.semibold)).foregroundStyle(color)
                Spacer()
                if outgoing.count > 1 { Image(systemName: "arrow.triangle.branch").font(.caption2).foregroundStyle(Theme.terraDeep) }
                if incoming.count > 1 { Image(systemName: "arrow.triangle.merge").font(.caption2).foregroundStyle(Theme.olive) }
                if node.isEnding { Image(systemName: "flag.checkered").font(.caption2).foregroundStyle(Theme.sub) }
            }
            Text(node.title).font(Theme.serif(13, .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
        }
        .padding(10)
        .frame(width: 150, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.5), lineWidth: 1.5))
    }
}

/// 画所有边（贝塞尔竖向连接）
private struct GraphEdges: Shape {
    let graph: BranchGraph
    let positions: [String: CGPoint]
    var only: Set<EdgeType>? = nil
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for e in graph.edges {
            if let only, !only.contains(e.type) { continue }
            guard let a = positions[e.from], let b = positions[e.to] else { continue }
            let start = CGPoint(x: a.x, y: a.y + 34)
            let end = CGPoint(x: b.x, y: b.y - 34)
            let midY = (start.y + end.y) / 2
            path.move(to: start)
            path.addCurve(to: end,
                          control1: CGPoint(x: start.x, y: midY),
                          control2: CGPoint(x: end.x, y: midY))
        }
        return path
    }
}

private struct LegendBar: View {
    let authorColors: [String: Color]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(authorColors.sorted(by: { $0.key < $1.key }), id: \.key) { name, color in
                    HStack(spacing: 5) {
                        Circle().fill(color).frame(width: 9, height: 9)
                        Text(name).font(.caption2).foregroundStyle(Theme.ink)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}
