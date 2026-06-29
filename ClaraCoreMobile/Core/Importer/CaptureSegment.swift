import Foundation

struct CaptureSegment: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case pending
        case reflecting
        case reflected
        case failed
    }

    var id: String
    var sessionId: String
    var sequence: Int
    var content: String
    var contentHash: String
    var characterRange: Range<Int>
    var tokenEstimate: Int
    var status: Status
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        sequence: Int,
        content: String,
        characterRange: Range<Int>,
        status: Status = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sequence = sequence
        self.content = content
        self.contentHash = RawCapture.hash(content)
        self.characterRange = characterRange
        self.tokenEstimate = TokenEstimator.estimate(content)
        self.status = status
        self.createdAt = createdAt
    }
}

