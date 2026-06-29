import Foundation

struct DigestCommitResult: Equatable {
    var memories: [Memory]
    var continuityLines: [ContinuityLine]

    var committedCount: Int {
        memories.count + continuityLines.count
    }
}

final class DigestCommitter {
    private let memoriaStore: MemoriaStore
    private let continuityStore: ContinuityStore

    init(memoriaStore: MemoriaStore, continuityStore: ContinuityStore) {
        self.memoriaStore = memoriaStore
        self.continuityStore = continuityStore
    }

    func commit(_ digest: DigestResult) throws -> DigestCommitResult {
        let lines = try digest.candidateSharedLineUpdates.map { update in
            try continuityStore.create(
                title: update.title,
                lastPosition: update.lastPosition,
                nextStep: update.nextStep
            )
        }
        let defaultLineId = lines.first?.id

        let memories = try digest.candidateMemories.map { candidate in
            try memoriaStore.store(
                content: candidate.content,
                tags: tags(for: candidate),
                isPrivate: false,
                sourceAgent: "mobile-reflection",
                lineId: defaultLineId
            )
        }

        return DigestCommitResult(memories: memories, continuityLines: lines)
    }

    private func tags(for candidate: CandidateMemory) -> [String] {
        var tags = candidate.tags
        tags.append("mobile")
        tags.append(candidate.kind.rawValue)
        return Array(Set(tags)).sorted()
    }
}
