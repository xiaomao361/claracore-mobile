import Foundation

struct ReflectionProvenance: Codable, Equatable {
    var sessionId: String
    var segmentId: String
    var characterRange: Range<Int>
}

struct CandidateMemory: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case fact
        case preference
        case decision
        case task
    }

    var id: String
    var kind: Kind
    var content: String
    var confidence: Double
    var tags: [String]
    var provenance: ReflectionProvenance

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        content: String,
        confidence: Double,
        tags: [String],
        provenance: ReflectionProvenance
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.confidence = confidence
        self.tags = tags
        self.provenance = provenance
    }
}

struct CandidateSharedLineUpdate: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var lastPosition: String
    var nextStep: String?
    var confidence: Double
    var provenance: ReflectionProvenance

    init(
        id: String = UUID().uuidString,
        title: String,
        lastPosition: String,
        nextStep: String?,
        confidence: Double,
        provenance: ReflectionProvenance
    ) {
        self.id = id
        self.title = title
        self.lastPosition = lastPosition
        self.nextStep = nextStep
        self.confidence = confidence
        self.provenance = provenance
    }
}

struct SegmentReflectionDraft: Codable, Equatable {
    var segmentId: String
    var summary: String
    var candidateMemories: [CandidateMemory]
    var candidateSharedLineUpdates: [CandidateSharedLineUpdate]
    var uncertainItems: [String]
}

struct DigestResult: Codable, Equatable {
    var sessionId: String
    var summary: String
    var candidateMemories: [CandidateMemory]
    var candidateSharedLineUpdates: [CandidateSharedLineUpdate]
    var conflicts: [String]
}

