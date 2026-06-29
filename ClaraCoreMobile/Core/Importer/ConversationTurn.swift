import Foundation

struct ConversationTurn: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
        case system
        case unknown
    }

    var id: String
    var role: Role
    var content: String
    var insertedAt: Date?
}

struct ImportedConversation: Equatable {
    var title: String
    var sourceApp: String
    var sourceThreadId: String?
    var sourceURL: URL?
    var turns: [ConversationTurn]

    var transcriptMarkdown: String {
        var lines = ["# \(title)", "", "Source: \(sourceApp)"]
        if let sourceURL {
            lines.append("URL: \(sourceURL.absoluteString)")
        }

        for turn in turns {
            lines.append("")
            lines.append("## \(turn.role.rawValue.uppercased())")
            lines.append(turn.content)
        }

        return lines.joined(separator: "\n")
    }

    func rawCapture(source: RawCapture.Source = .url) -> RawCapture {
        RawCapture(
            source: source,
            rawContent: transcriptMarkdown,
            sourceApp: sourceApp,
            sourceThreadId: sourceThreadId,
            metadata: [
                "title": title,
                "url": sourceURL?.absoluteString ?? ""
            ].filter { !$0.value.isEmpty }
        )
    }
}

