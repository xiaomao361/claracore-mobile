import Foundation

final class DeepSeekShareImporter {
    enum ImportError: LocalizedError, Equatable {
        case invalidURL
        case unsupportedURL
        case invalidResponse
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                "分享链接无效。请检查链接后重试。"
            case .unsupportedURL:
                "当前还不支持这个分享链接格式。"
            case .invalidResponse:
                "分享内容格式异常，暂时无法导入。"
            case let .unavailable(message):
                if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    "分享内容不可用，可能已失效或没有访问权限。"
                } else {
                    "分享内容不可用：\(message)"
                }
            }
        }
    }

    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func importConversation(from url: URL) async throws -> ImportedConversation {
        let shareId = try Self.shareId(from: url)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "chat.deepseek.com"
        components.path = "/api/v0/share/content"
        components.queryItems = [URLQueryItem(name: "share_id", value: shareId)]

        guard let requestURL = components.url else {
            throw ImportError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://chat.deepseek.com/share/\(shareId)", forHTTPHeaderField: "Referer")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ImportError.invalidResponse
        }

        return try decodeConversation(data: data, sourceURL: url, shareId: shareId)
    }

    func decodeConversation(data: Data, sourceURL: URL?, shareId: String) throws -> ImportedConversation {
        let envelope: DeepSeekShareEnvelope
        do {
            envelope = try decoder.decode(DeepSeekShareEnvelope.self, from: data)
        } catch {
            throw ImportError.invalidResponse
        }
        guard envelope.code == 0, envelope.data.bizCode == 0 else {
            throw ImportError.unavailable(envelope.data.bizMessage)
        }
        guard let payload = envelope.data.bizData else {
            throw ImportError.unavailable(envelope.data.bizMessage)
        }

        let turns = payload.messages.map { message in
            ConversationTurn(
                id: String(message.messageId),
                role: ConversationTurn.Role(deepSeekRole: message.role),
                content: message.content,
                insertedAt: message.insertedAt.map { Date(timeIntervalSince1970: $0) }
            )
        }

        return ImportedConversation(
            title: payload.title,
            sourceApp: "DeepSeek",
            sourceThreadId: shareId,
            sourceURL: sourceURL,
            turns: turns
        )
    }

    static func canImport(url: URL) -> Bool {
        (try? shareId(from: url)) != nil
    }

    static func shareId(from url: URL) throws -> String {
        guard let host = url.host?.lowercased(), host == "chat.deepseek.com" else {
            throw ImportError.unsupportedURL
        }

        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 2, parts[0] == "share", !parts[1].isEmpty else {
            throw ImportError.unsupportedURL
        }

        return parts[1]
    }

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}

private struct DeepSeekShareEnvelope: Decodable {
    var code: Int
    var data: DataNode

    struct DataNode: Decodable {
        var bizCode: Int
        var bizMessage: String
        var bizData: BizData?

        enum CodingKeys: String, CodingKey {
            case bizCode = "biz_code"
            case bizMessage = "biz_msg"
            case bizData = "biz_data"
        }
    }

    struct BizData: Decodable {
        var title: String
        var messages: [Message]
    }

    struct Message: Decodable {
        var messageId: Int
        var role: String
        var content: String
        var insertedAt: Double?

        enum CodingKeys: String, CodingKey {
            case messageId = "message_id"
            case role
            case content
            case insertedAt = "inserted_at"
        }
    }
}

private extension ConversationTurn.Role {
    init(deepSeekRole: String) {
        switch deepSeekRole.uppercased() {
        case "USER":
            self = .user
        case "ASSISTANT":
            self = .assistant
        case "SYSTEM":
            self = .system
        default:
            self = .unknown
        }
    }
}
