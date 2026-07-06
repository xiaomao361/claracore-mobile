import Foundation
import CryptoKit

struct RawCapture: Identifiable, Equatable {
    static let maxImportCharacters = 240_000

    enum ValidationError: LocalizedError, Equatable {
        case emptyImport
        case oversizedImport(currentCharacters: Int, maxCharacters: Int)

        var errorDescription: String? {
            switch self {
            case .emptyImport:
                "导入内容为空。请粘贴一段对话文本、公开分享链接，或选择包含文字的 .txt 文件。"
            case let .oversizedImport(currentCharacters, maxCharacters):
                "这次导入约 \(currentCharacters.formatted()) 字，超过当前上限 \(maxCharacters.formatted()) 字。请把原文拆成几次导入，或只粘贴最需要整理的部分。"
            }
        }
    }

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
    var contextCardId: String?
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
        contextCardId: String? = nil,
        contentHash: String? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.sourceApp = sourceApp
        self.sourceThreadId = sourceThreadId
        self.contextCardId = contextCardId
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

    func validateForImport(maxCharacters: Int = Self.maxImportCharacters) throws {
        guard !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyImport
        }
        guard rawContent.count <= maxCharacters else {
            throw ValidationError.oversizedImport(
                currentCharacters: rawContent.count,
                maxCharacters: maxCharacters
            )
        }
    }
}
