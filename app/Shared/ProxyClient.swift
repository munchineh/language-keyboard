import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The `profile` object in proxy requests (snake_case to match the Worker).
struct ProxyProfile: Codable, Equatable {
    var relationship: String?
    var speech_level: String?
    var listener_age: String?
    var listener_gender: String?
    var speaker_gender: String?
    var tone: String?
    var region: String?
    var script: String?
}

struct CheckRequest: Codable, Equatable {
    var lang: String
    var text: String
    var context: String?
    var profile: ProxyProfile
    var note: String?
    var model: String?
    /// Language for "tip" and "note" (en, ko, zh-Hans, zh-Hant).
    var explain: String?
}

/// `/check` response: `{"status":"ok","stiff":bool}` or
/// `{"status":"fix","stiff":bool,"corrected":"...","tip":"..."}`.
struct CheckResponse: Codable, Equatable {
    var status: String
    var stiff: Bool?
    var corrected: String?
    var tip: String?

    var isFix: Bool { status == "fix" && corrected != nil }
}

struct RephraseOption: Codable, Equatable, Identifiable {
    var label: String
    var text: String
    var note: String?
    var id: String { label + text }
}

struct RephraseResponse: Codable, Equatable {
    var options: [RephraseOption]
}

enum ProxyError: LocalizedError, Equatable {
    case missingToken
    case badURL
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Add the proxy token in the Language Keyboard app"
        case .badURL: return "Proxy URL is not valid"
        case .http(let code, let message): return "Proxy error \(code)\(message.isEmpty ? "" : ": \(message)")"
        case .decoding: return "Unexpected reply from the proxy"
        }
    }
}

/// Talks to the Cloudflare Worker `keyboard-proxy`. One shared session so the
/// TLS connection is reused between checks (saves ~300ms per check).
final class ProxyClient {
    static let shared = ProxyClient()

    private let session: URLSession
    var store: SettingsStore

    init(store: SettingsStore = .shared) {
        self.store = store
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: config)
    }

    func check(_ body: CheckRequest) async throws -> (CheckResponse, latencyMs: Int?) {
        let (data, response) = try await post("check", body: body)
        guard let decoded = try? JSONDecoder().decode(CheckResponse.self, from: data) else { throw ProxyError.decoding }
        let latency = (response.value(forHTTPHeaderField: "x-latency-ms")).flatMap { Int($0) }
        return (decoded, latency)
    }

    func rephrase(_ body: CheckRequest) async throws -> RephraseResponse {
        let (data, _) = try await post("rephrase", body: body)
        guard let decoded = try? JSONDecoder().decode(RephraseResponse.self, from: data) else { throw ProxyError.decoding }
        return decoded
    }

    /// `GET /`: version and model list. Used by the companion app's connection test.
    func status() async throws -> String {
        let request = try makeRequest(path: "", method: "GET", body: nil)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Private

    private func post<T: Encodable>(_ path: String, body: T) async throws -> (Data, HTTPURLResponse) {
        let request = try makeRequest(path: path, method: "POST", body: try JSONEncoder().encode(body))
        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)
        guard let http = response as? HTTPURLResponse else { throw ProxyError.decoding }
        return (data, http)
    }

    private func makeRequest(path: String, method: String, body: Data?) throws -> URLRequest {
        let token = store.proxyToken
        if method == "POST" && token.isEmpty { throw ProxyError.missingToken }
        let base = store.proxyURL.hasSuffix("/") ? String(store.proxyURL.dropLast()) : store.proxyURL
        guard let url = URL(string: path.isEmpty ? base + "/" : base + "/" + path) else { throw ProxyError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ProxyError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            // The Worker returns {"error": "..."}; never includes the user's text.
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? ""
            throw ProxyError.http(http.statusCode, message)
        }
    }
}
