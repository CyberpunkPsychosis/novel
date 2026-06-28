import SwiftUI

/// 改编申请收件箱：我作为作者收到的续写/改编申请，可同意/拒绝。
struct ForkRequestsInboxView: View {
    @EnvironmentObject var store: LibraryStore

    private var incoming: [ForkRequest] { store.incomingForkRequests }
    private var outgoing: [ForkRequest] {
        store.forkRequests.filter { $0.requester == store.currentUser?.penName && !incoming.contains($0) }
    }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.45)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(title: "收到的申请")
                    if incoming.isEmpty {
                        EmptyHint(text: "暂时没有人申请改编你的作品。\n发布作品、开放授权后，别人的申请会出现在这里。")
                    } else {
                        ForEach(incoming) { req in
                            IncomingRow(req: req,
                                        bookTitle: store.book(id: req.bookID)?.title ?? "",
                                        onApprove: { store.decide(req, approve: true) },
                                        onDeny: { store.decide(req, approve: false) })
                        }
                    }

                    SectionHeader(title: "我发出的申请")
                    if outgoing.isEmpty {
                        EmptyHint(text: "你还没向别人申请过改编/续写。")
                    } else {
                        ForEach(outgoing) { req in
                            OutgoingRow(req: req, bookTitle: store.book(id: req.bookID)?.title ?? "")
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("改编申请")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IncomingRow: View {
    let req: ForkRequest
    let bookTitle: String
    let onApprove: () -> Void
    let onDeny: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(Theme.terracotta).frame(width: 34, height: 34)
                    .overlay(Text(String(req.requester.prefix(1))).font(.caption).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(req.requester) 想\(req.mode)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("《\(bookTitle)》· 第 \(req.fromChapter) 章起").font(.caption2).foregroundStyle(Theme.sub)
                }
                Spacer()
            }
            if req.status == .pending {
                HStack(spacing: 10) {
                    Button(action: onApprove) {
                        Text("同意").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Theme.olive).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    Button(action: onDeny) {
                        Text("拒绝").font(.caption.weight(.bold)).foregroundStyle(Theme.terraDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Theme.terraDeep.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            } else {
                TagChip(text: req.status.label, color: req.status == .approved ? Theme.olive : Theme.terraDeep)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

private struct OutgoingRow: View {
    let req: ForkRequest
    let bookTitle: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(req.mode)《\(bookTitle)》").font(.subheadline).foregroundStyle(Theme.ink)
                Text("第 \(req.fromChapter) 章起").font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer()
            TagChip(text: req.status.label,
                    color: req.status == .approved ? Theme.olive : (req.status == .denied ? Theme.terraDeep : Theme.bronze))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(Theme.sub).lineSpacing(3)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
    }
}
