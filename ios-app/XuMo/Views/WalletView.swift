import SwiftUI
import StoreKit

/// 墨滴钱包：余额 + 每日签到 + 流水 + Apple 内购买墨滴。
struct WalletView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showBuy = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.45)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 余额 + 签到
                    VStack(spacing: 14) {
                        Text("\(store.molDi)").font(Theme.serif(46, .bold)).foregroundStyle(Theme.ink)
                        Text("墨滴余额").font(.caption).foregroundStyle(Theme.sub)
                        HStack(spacing: 12) {
                            Button {
                                let got = store.doCheckin()
                                toast = got > 0 ? "签到成功 +\(got) 墨滴" : "今天已经签过了"
                            } label: {
                                Label(store.canCheckinToday ? "今日签到" : "已签到",
                                      systemImage: "drop.fill")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(store.canCheckinToday ? Theme.terraDeep : Theme.sub)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!store.canCheckinToday)

                            Button { showBuy = true } label: {
                                Label("买墨滴", systemImage: "cart")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(Theme.bronze).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        if store.checkin.streak > 0 {
                            Text("已连续签到 \(store.checkin.streak) 天").font(.caption2).foregroundStyle(Theme.olive)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))

                    SectionHeader(title: "墨滴明细")
                    if store.creditTxns.isEmpty {
                        Text("还没有流水。").font(.subheadline).foregroundStyle(Theme.sub)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.creditTxns.enumerated()), id: \.element.id) { i, t in
                                TxnRow(txn: t)
                                if i < store.creditTxns.count - 1 { Divider().background(Theme.line) }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    }
                }
                .padding(20)
            }
            if let toast { ToastView(text: toast).onAppear { dismissToast() } }
        }
        .navigationTitle("墨滴钱包")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBuy) { BuyMolDiSheet().environmentObject(store) }
    }

    private func dismissToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { toast = nil }
    }
}

private struct TxnRow: View {
    let txn: CreditTxn
    var body: some View {
        HStack {
            Image(systemName: txn.delta >= 0 ? "plus.circle" : "minus.circle")
                .foregroundStyle(txn.delta >= 0 ? Theme.olive : Theme.terraDeep)
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.reason.label).font(.subheadline).foregroundStyle(Theme.ink)
                if !txn.note.isEmpty { Text(txn.note).font(.caption2).foregroundStyle(Theme.sub) }
            }
            Spacer()
            Text(txn.delta >= 0 ? "+\(txn.delta)" : "\(txn.delta)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(txn.delta >= 0 ? Theme.olive : Theme.terraDeep)
        }
        .padding(.vertical, 11)
    }
}

/// 买墨滴：Apple 内购（StoreKit 2）。校验交易后由后端入账。
struct BuyMolDiSheet: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iap = IAPStore()
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("选择墨滴套餐").font(Theme.serif(18, .semibold)).foregroundStyle(Theme.ink).padding(.top, 8)

                        if iap.products.isEmpty {
                            ProgressView("加载商品…").padding(.top, 24)
                        } else {
                            ForEach(iap.products, id: \.id) { p in
                                Button { buy(p) } label: { packRow(p) }
                                    .buttonStyle(.plain)
                                    .disabled(iap.busy)
                            }
                        }

                        Text("通过 Apple 内购支付；交易由 Apple 校验后到账。")
                            .font(.caption2).foregroundStyle(Theme.sub)
                            .multilineTextAlignment(.center).padding(.top, 8)
                    }
                    .padding(20)
                }
                if iap.busy { ProgressView().scaleEffect(1.3).tint(Theme.terraDeep) }
                if let toast { ToastView(text: toast) }
            }
            .navigationTitle("买墨滴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .task { await iap.load() }
        }
    }

    @ViewBuilder private func packRow(_ p: Product) -> some View {
        HStack {
            Image(systemName: "drop.fill").foregroundStyle(Theme.terracotta)
            Text("\(IAPStore.credits(for: p.id)) 墨滴").font(.headline).foregroundStyle(Theme.ink)
            Spacer()
            Text(p.displayPrice).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(Theme.terraDeep).clipShape(Capsule())
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }

    private func buy(_ p: Product) {
        Task { @MainActor in
            let credited = await iap.purchase(p) { productId, txnId in
                await store.grantPurchase(productId: productId, transactionId: txnId)
            }
            if let credited, credited > 0 {
                toast = "充值成功 +\(credited) 墨滴"
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                dismiss()
            }
        }
    }
}

/// 轻量 toast
struct ToastView: View {
    let text: String
    var body: some View {
        VStack {
            Spacer()
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Theme.ink.opacity(0.9)).clipShape(Capsule())
                .padding(.bottom, 60)
        }
        .transition(.opacity)
    }
}
