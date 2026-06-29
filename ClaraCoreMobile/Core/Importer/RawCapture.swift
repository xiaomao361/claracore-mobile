import Foundation
import CryptoKit

struct RawCapture: Identifiable, Equatable {
    enum Source: String, CaseIterable {
        case manual
        case clipboard
        case share
        case file
        case url
    }

    var id: String
    var source: Source
    var sourceApp: String?
    var sourceThreadId: String?
    var contentHash: String
    var rawContent: String
    var metadata: [String: String]
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        source: Source,
        rawContent: String,
        sourceApp: String? = nil,
        sourceThreadId: String? = nil,
        contentHash: String? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.sourceApp = sourceApp
        self.sourceThreadId = sourceThreadId
        self.contentHash = contentHash ?? Self.hash(rawContent)
        self.rawContent = rawContent
        self.metadata = metadata
        self.createdAt = createdAt
    }

    static func hash(_ content: String) -> String {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
