import Foundation

protocol ReflectionService {
    func reflect(segment: CaptureSegment) async throws -> SegmentReflectionDraft
    func reconcile(session: ImportSession, drafts: [SegmentReflectionDraft]) async throws -> DigestResult
}

