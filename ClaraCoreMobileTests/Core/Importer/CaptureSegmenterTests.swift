import XCTest
@testable import ClaraCoreMobile

final class CaptureSegmenterTests: XCTestCase {
    func testSegmentsLargeCaptureWithOverlapAndHashes() {
        let capture = RawCapture(
            source: .file,
            rawContent: "abcdefghijkl",
            sourceApp: "Export",
            sourceThreadId: "thread-1"
        )
        let segmenter = FixedSizeCaptureSegmenter(maxCharacters: 5, overlapCharacters: 2)

        let segments = segmenter.segment(capture: capture, sessionId: "session-1")

        XCTAssertEqual(segments.map(\.content), ["abcde", "defgh", "ghijk", "jkl"])
        XCTAssertEqual(segments.map(\.characterRange), [0..<5, 3..<8, 6..<11, 9..<12])
        XCTAssertEqual(segments.first?.contentHash, RawCapture.hash("abcde"))
        XCTAssertEqual(segments.first?.sessionId, "session-1")
    }
}

