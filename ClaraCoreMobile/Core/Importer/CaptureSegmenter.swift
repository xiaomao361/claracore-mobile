import Foundation

protocol CaptureSegmenting {
    func segment(capture: RawCapture, sessionId: String) -> [CaptureSegment]
}

struct FixedSizeCaptureSegmenter: CaptureSegmenting {
    let maxCharacters: Int
    let overlapCharacters: Int

    init(maxCharacters: Int = 12_000, overlapCharacters: Int = 800) {
        precondition(maxCharacters > 0)
        precondition(overlapCharacters >= 0 && overlapCharacters < maxCharacters)
        self.maxCharacters = maxCharacters
        self.overlapCharacters = overlapCharacters
    }

    func segment(capture: RawCapture, sessionId: String) -> [CaptureSegment] {
        let content = capture.rawContent
        guard !content.isEmpty else {
            return []
        }

        var segments: [CaptureSegment] = []
        var startOffset = 0
        var sequence = 0

        while startOffset < content.count {
            let endOffset = min(startOffset + maxCharacters, content.count)
            let startIndex = content.index(content.startIndex, offsetBy: startOffset)
            let endIndex = content.index(content.startIndex, offsetBy: endOffset)
            let segmentContent = String(content[startIndex..<endIndex])

            segments.append(
                CaptureSegment(
                    sessionId: sessionId,
                    sequence: sequence,
                    content: segmentContent,
                    characterRange: startOffset..<endOffset
                )
            )

            guard endOffset < content.count else {
                break
            }

            startOffset = max(endOffset - overlapCharacters, startOffset + 1)
            sequence += 1
        }

        return segments
    }
}

