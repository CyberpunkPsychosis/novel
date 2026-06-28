import StoreKit

/// StoreKit 2 内购：加载墨滴商品、购买、校验交易，把已验证交易交给后端入账。
@MainActor
final class IAPStore: ObservableObject {
    /// 商品 id → 墨滴数（与 XuMo.storekit 及后端 PRODUCTS 一致）。
    static let creditsByProduct: [String: Int] = [
        "com.example.xumo.molzi.60": 60,
        "com.example.xumo.molzi.330": 330,
        "com.example.xumo.molzi.800": 800,
        "com.example.xumo.molzi.1600": 1600,
    ]

    @Published private(set) var products: [Product] = []
    @Published var busy = false

    static func credits(for id: String) -> Int { creditsByProduct[id] ?? 0 }

    func load() async {
        let ids = Array(Self.creditsByProduct.keys)
        let fetched = (try? await Product.products(for: ids)) ?? []
        products = fetched.sorted { $0.price < $1.price }
    }

    /// 购买并校验；成功后通过 grant 闭包让 LibraryStore 调后端入账，再 finish 交易。
    /// 返回入账的墨滴数（失败/取消返回 nil）。
    func purchase(_ product: Product, grant: (_ productId: String, _ transactionId: String) async -> Void) async -> Int? {
        busy = true
        defer { busy = false }
        do {
            let result = try await product.purchase()
            guard case .success(let verification) = result,
                  case .verified(let txn) = verification else { return nil }
            await grant(product.id, String(txn.id))
            await txn.finish()
            return Self.credits(for: product.id)
        } catch {
            return nil
        }
    }
}
