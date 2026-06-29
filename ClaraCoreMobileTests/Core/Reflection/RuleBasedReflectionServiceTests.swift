import XCTest
@testable import ClaraCoreMobile

final class RuleBasedReflectionServiceTests: XCTestCase {
    func testReflectReturnsSegmentSummaryWithoutCommittingCandidates() async throws {
        let service = RuleBasedReflectionService()
        let segment = CaptureSegment(
            sessionId: "session-1",
            sequence: 0,
            content: "\nImportant first line.\nMore content.",
            characterRange: 0..<37
        )

        let draft = try await service.reflect(segment: segment)

        XCTAssertEqual(draft.segmentId, segment.id)
        XCTAssertEqual(draft.summary, "Important first line.")
        XCTAssertTrue(draft.candidateMemories.isEmpty)
        XCTAssertTrue(draft.candidateSharedLineUpdates.isEmpty)
    }
}

