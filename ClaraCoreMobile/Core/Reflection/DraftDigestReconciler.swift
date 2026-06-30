import Foundation

struct DraftDigestReconciler {
    var summaryLimit = 12
    var memoryLimit = 6
    var sharedLineLimit = 12
    var minimumMemoryConfidence = 0.82
    var minimumSharedLineConfidence = 0.72

    func digest(
        session: ImportSession,
        drafts: [SegmentReflectionDraft],
        summaryOverride: String? = nil,
        conflicts: [String] = []
    ) -> DigestResult {
        DigestResult(
            sessionId: session.id,
            summary: normalizedSummary(from: drafts, override: summaryOverride),
            candidateMemories: dedupeMemories(drafts.flatMap(\.candidateMemories)),
            candidateSharedLineUpdates: dedupeSharedLines(drafts.flatMap(\.candidateSharedLineUpdates)),
            conflicts: Array(Set(conflicts + drafts.flatMap(\.uncertainItems))).sorted()
        )
    }

    private func normalizedSummary(from drafts: [SegmentReflectionDraft], override: String?) -> String {
        if let override = override?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            return override
        }

        return drafts
            .map(\.summary)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(summaryLimit)
            .joined(separator: "\n")
    }

    private func dedupeMemories(_ memories: [CandidateMemory]) -> [CandidateMemory] {
        var byKey: [String: CandidateMemory] = [:]
        for memory in memories where shouldKeep(memory) {
            let key = normalizedKey(memory.content)
            guard !key.isEmpty else { continue }

            if let existing = byKey[key] {
                byKey[key] = stronger(existing, memory)
            } else {
                byKey[key] = memory
            }
        }

        return byKey.values
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.content < rhs.content
                }
                return lhs.confidence > rhs.confidence
            }
            .prefix(memoryLimit)
            .map { $0 }
    }

    private func dedupeSharedLines(_ updates: [CandidateSharedLineUpdate]) -> [CandidateSharedLineUpdate] {
        var byKey: [String: CandidateSharedLineUpdate] = [:]
        for update in updates where shouldKeep(update) {
            let key = normalizedKey("\(update.title) \(update.lastPosition)")
            guard !key.isEmpty else { continue }

            if let existing = byKey[key] {
                byKey[key] = stronger(existing, normalized(update))
            } else {
                byKey[key] = normalized(update)
            }
        }

        return byKey.values
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.title < rhs.title
                }
                return lhs.confidence > rhs.confidence
            }
            .prefix(sharedLineLimit)
            .map { $0 }
    }

    private func stronger(_ lhs: CandidateMemory, _ rhs: CandidateMemory) -> CandidateMemory {
        if lhs.confidence == rhs.confidence {
            return lhs.content.count >= rhs.content.count ? lhs : rhs
        }
        return lhs.confidence > rhs.confidence ? lhs : rhs
    }

    private func stronger(_ lhs: CandidateSharedLineUpdate, _ rhs: CandidateSharedLineUpdate) -> CandidateSharedLineUpdate {
        if lhs.confidence == rhs.confidence {
            return lhs.lastPosition.count >= rhs.lastPosition.count ? lhs : rhs
        }
        return lhs.confidence > rhs.confidence ? lhs : rhs
    }

    private func shouldKeep(_ memory: CandidateMemory) -> Bool {
        guard memory.confidence >= minimumMemoryConfidence else { return false }
        guard memory.kind == .fact || memory.kind == .preference || memory.kind == .decision else { return false }
        let content = memory.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.count >= 8 else { return false }
        return true
    }

    private func shouldKeep(_ update: CandidateSharedLineUpdate) -> Bool {
        guard update.confidence >= minimumSharedLineConfidence else { return false }
        guard !update.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !update.lastPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    private func normalized(_ update: CandidateSharedLineUpdate) -> CandidateSharedLineUpdate {
        var copy = update
        copy.lastPosition = normalizedMilestones(update.lastPosition)
        return copy
    }

    private func normalizedMilestones(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in 2...12 {
            normalized = normalized.replacingOccurrences(of: " \(index). ", with: "\n\(index). ")
        }
        return normalized
    }

    private func normalizedKey(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .punctuationCharacters)
    }
}
