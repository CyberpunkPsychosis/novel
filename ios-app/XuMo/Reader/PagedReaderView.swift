import SwiftUI
import UIKit

/// 单页视图控制器：满屏 UITextView 显示一页富文本。
final class PageVC: UIViewController {
    let pageIndex: Int
    private let page: ReaderPage
    private let bg: UIColor
    init(pageIndex: Int, page: ReaderPage, bg: UIColor) {
        self.pageIndex = pageIndex; self.page = page; self.bg = bg
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bg
        let tv = UITextView(frame: view.bounds)
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = Paginator.inset
        tv.textContainer.lineFragmentPadding = 0
        tv.attributedText = page.attr
        tv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tv)
    }
}

/// 仿真翻页阅读器（UIPageViewController + pageCurl）。
struct PagedReaderView: UIViewControllerRepresentable {
    let book: Book
    let fontSize: Double
    let lineSpacing: Double
    let theme: ReaderTheme
    let startChapter: Int
    let onChapter: (Int) -> Void          // 落到某页时回报章节（markRead）
    let onHUD: (String) -> Void           // 回报 HUD 文案

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .pageCurl,
                                      navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = theme.bg
        context.coordinator.repaginate(into: pvc, jumpToChapter: startChapter)
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        pvc.view.backgroundColor = theme.bg
        let size = pvc.view.bounds.size
        let sig = "\(fontSize)-\(lineSpacing)-\(theme.rawValue)"
        // 字号/主题变了，或真实页面尺寸首次/变化时 → 按真实尺寸重排，停在当前章。
        let sizeChanged = size != .zero && size != context.coordinator.lastSize
        if sig != context.coordinator.lastSignature || sizeChanged {
            let keepChapter = context.coordinator.currentChapter
            context.coordinator.repaginate(into: pvc, jumpToChapter: keepChapter)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: PagedReaderView
        var pages: [ReaderPage] = []
        var lastSignature = ""
        var lastSize: CGSize = .zero
        var currentChapter = 1
        private let settings = ReaderSettings()

        init(_ parent: PagedReaderView) { self.parent = parent }

        func repaginate(into pvc: UIPageViewController, jumpToChapter chapter: Int) {
            settings.fontSize = parent.fontSize
            settings.lineSpacing = parent.lineSpacing
            settings.theme = parent.theme
            lastSignature = "\(parent.fontSize)-\(parent.lineSpacing)-\(parent.theme.rawValue)"
            let screen = pvc.view.bounds.size == .zero ? UIScreen.main.bounds.size : pvc.view.bounds.size
            lastSize = screen
            pages = Paginator.paginate(book: parent.book, settings: settings, screen: screen)
            let start = pages.firstIndex { $0.chapterIndex == chapter } ?? 0
            if let vc = page(at: start) {
                pvc.setViewControllers([vc], direction: .forward, animated: false)
                report(start)
            }
        }

        private func page(at index: Int) -> PageVC? {
            guard index >= 0, index < pages.count else { return nil }
            return PageVC(pageIndex: index, page: pages[index], bg: parent.theme.bg)
        }

        private func report(_ index: Int) {
            guard index >= 0, index < pages.count else { return }
            let p = pages[index]
            currentChapter = p.chapterIndex
            parent.onChapter(p.chapterIndex)
            parent.onHUD("\(p.chapterTitle) · \(p.pageInChapter)/\(p.pagesInChapter)")
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            page(at: (vc as! PageVC).pageIndex - 1)
        }
        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            page(at: (vc as! PageVC).pageIndex + 1)
        }
        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let cur = pvc.viewControllers?.first as? PageVC else { return }
            report(cur.pageIndex)
        }
    }
}
