import Foundation

struct ReflectionRunResult: Identifiable, Equatable {
    var session: ImportSession
    var drafts: [SegmentReflectionDraft]
    var digest: DigestResult

    var id: String {
        session.id
    }
}

enum ReflectionProgress: Equatable {
    case preparing
    case segmenting(total: Int)
    case reflectingSegment(current: Int, total: Int)
    case reconciling(total: Int)
    case ready
}

final class ReflectionRunner {
    enum RunnerError: LocalizedError, Equatable {
        case noSegments

        var errorDescription: String? {
            switch self {
            case .noSegments:
                "没有可整理的内容片段。请重新导入包含文字的对话、公开分享链接或 .txt 文件。"
            }
        }
    }

    private let sessionStore: ImportSessionStore
    private let reflectionService: ReflectionService

    init(
        sessionStore: ImportSessionStore,
        reflectionService: ReflectionService
    ) {
        self.sessionStore = sessionStore
        self.reflectionService = reflectionService
    }

    func run(
        prepared: PreparedImportSession,
        onProgress: ((ReflectionProgress) -> Void)? = nil
    ) async throws -> ReflectionRunResult {
        guard !prepared.segments.isEmpty else {
            throw RunnerError.noSegments
        }

        try sessionStore.updateStatus(sessionId: prepared.session.id, status: .reflecting)

        var drafts: [SegmentReflectionDraft] = []
        for (index, segment) in prepared.segments.enumerated() {
            onProgress?(.reflectingSegment(current: index + 1, total: prepared.segments.count))
            let draft = try await reflectionService.reflect(segment: segment)
            drafts.append(draft)
        }

        onProgress?(.reconciling(total: drafts.count))
        let digest = try await reflectionService.reconcile(session: prepared.session, drafts: drafts)
        try sessionStore.updateStatus(sessionId: prepared.session.id, status: .digested)

        return ReflectionRunResult(
            session: prepared.session,
            drafts: drafts,
            digest: digest
        )
    }
}
