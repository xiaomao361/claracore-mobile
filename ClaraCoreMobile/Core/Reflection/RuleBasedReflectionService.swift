import Foundation

struct RuleBasedReflectionService: ReflectionService {
    func reflect(segment: CaptureSegment) async throws -> SegmentReflectionDraft {
        let summary = segment.content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""

        return SegmentReflectionDraft(
            segmentId: segment.id,
            summary: summary,
            candidateMemories: [],
            candidateSharedLineUpdates: [],
            uncertainItems: summary.isEmpty ? ["empty_segment"] : []
        )
    }

    func reconcile(session: ImportSession, drafts: [SegmentReflectionDraft]) async throws -> DigestResult {
        DraftDigestReconciler(summaryLimit: 5).digest(session: session, drafts: drafts)
    }
}
