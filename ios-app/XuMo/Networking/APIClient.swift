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
    private let decoder = JSONDecoder()

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
