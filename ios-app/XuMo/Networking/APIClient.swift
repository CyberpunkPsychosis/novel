import Foundation

enum APIError: LocalizedError {
    case offline
    case unauthorized
    case badStatus(Int, String)
    case badURL
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline:            return "网络不可用，请检查连接"
        case .unauthorized:       return "登录已过期，请重新登录"
        case .badStatus(let c, _): return "请求失败（\(c)）"
        case .badURL:             return "服务器地址错误"
        case .decoding:           return "数据解析失败"
        }
    }
}

/// 极简 async 网络客户端：拼 baseURL、带 JWT、统一错误。
/// 返回类型由调用方泛型决定，复用系统 JSONDecoder（驼峰键与后端一致）。
struct APIClient {
    static let shared = APIClient()
    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // 后端 DateTime 序列化为 ISO8601（带毫秒），自定义策略兼容有/无小数秒。
        let withMs = ISO8601DateFormatter()
        withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let dt = withMs.date(from: s) ?? plain.date(from: s) { return dt }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath,
                                                    debugDescription: "无法解析日期: \(s)"))
        }
        return d
    }()

    func request<T: Decodable>(_ path: String,
                               method: String = "GET",
                               bodyData: Data? = nil,
                               auth: Bool = false) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let bodyData {
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let token = TokenStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.offline
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

// MARK: 接口出入参（与后端 JSON 对齐）
struct AuthResponse: Decodable { let token: String; let user: LocalUser }
struct OKResponse: Decodable { let ok: Bool }

struct ApplePayload: Encodable { let identityToken: String; let penName: String? }
struct DevLoginPayload: Encodable { let email: String; let penName: String? }
struct ProgressPayload: Encodable { let bookId: String; let chapterIndex: Int }

struct NewBookPayload: Encodable {
    let title: String
    let blurb: String
    let tags: [String]
    let tagline: String
    let coverColors: [String]
    let coverAccent: String
    let chapters: [Chapter]

    init(from b: Book) {
        title = b.title; blurb = b.blurb; tags = b.tags; tagline = b.tagline
        coverColors = b.coverColors; coverAccent = b.coverAccent; chapters = b.chapters
    }
}

// MARK: M2 fork 生态出入参
struct ForkCreatePayload: Encodable {
    let parentId: String
    let mode: String          // "continuation" / "adaptation"
    let fromChapter: Int
    let newChapterTitle: String
    let newContent: String
}
struct ForkRequestPayload: Encodable { let bookId: String; let fromChapter: Int; let mode: String }
struct DecidePayload: Encodable { let approve: Bool }
struct BuyPayload: Encodable { let amount: Int }

struct CreditsResponse: Decodable {
    let balance: Int
    let txns: [CreditTxn]
    let checkin: DailyCheckin
}
struct CheckinResponse: Decodable { let award: Int; let streak: Int }
struct BalanceResponse: Decodable { let balance: Int }
struct RatingResponse: Decodable { let ratingAvg: Double; let ratingCount: Int; let mine: Int }
