import Foundation

struct PreparedImportSession: Equatable {
    var session: ImportSession
    var segments: [CaptureSegment]
}

final class ImportSessionPreparer {
    private let inboxStore: InboxStore
    private let sessionStore: ImportSessionStore
    private let segmenter: CaptureSegmenting

    init(
        inboxStore: InboxStore,
        sessionStore: ImportSessionStore,
        segmenter: CaptureSegmenting
    ) {
        self.inboxStore = inboxStore
        self.sessionStore = sessionStore
        self.segmenter = segmenter
    }

    @discardableResult
    func prepare(item: InboxItem) throws -> PreparedImportSession {
        let capture = item.rawCapture()
        try capture.validateForImport()
        let session = try sessionStore.create(from: capture, title: title(for: item))
        let segments = segmenter.segment(capture: capture, sessionId: session.id)
        try sessionStore.addSegments(segments)
        try sessionStore.updateStatus(sessionId: session.id, status: .segmenting)
        return PreparedImportSession(session: session, segments: segments)
    }

    private func title(for item: InboxItem) -> String {
        if let title = item.metadata["title"], !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }

        if let sourceApp = item.sourceApp, let sourceThreadId = item.sourceThreadId {
            return "\(sourceApp) \(sourceThreadId)"
        }

        return item.rawContent
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "导入内容"
    }
}

extension InboxItem {
    func rawCapture() -> RawCapture {
        RawCapture(
            id: id,
            source: source,
            rawContent: rawContent,
            sourceApp: sourceApp,
            sourceThreadId: sourceThreadId,
            contextCardId: contextCardId,
            contentHash: contentHash,
            metadata: metadata,
            createdAt: createdAt
        )
    }
}
