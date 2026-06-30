import Foundation

struct DraftDigestReconciler {
    var summaryLimit = 12
    var memoryLimit = 6
    var sharedLineLimit = 12
    var minimumMemoryConfidence = 0.76
    var minimumSharedLineConfidence = 0.72

    func digest(
        session: ImportSession,
        drafts: [SegmentReflectionDraft],
        summaryOverride: String? = nil,
        conflicts: [String] = []
    ) -> DigestResult {
        let memories = dedupeMemories(drafts.flatMap(\.candidateMemories))
        let sharedLines = dedupeSharedLines(drafts.flatMap(\.candidateSharedLineUpdates))

        return DigestResult(
            sessionId: session.id,
            summary: normalizedSummary(from: drafts, override: summaryOverride),
            candidateMemories: memories.isEmpty ? fallbackMemories(session: session, from: drafts, sharedLines: sharedLines) : memories,
            candidateSharedLineUpdates: sharedLines,
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

    private func fallbackMemories(
        session: ImportSession,
        from drafts: [SegmentReflectionDraft],
        sharedLines: [CandidateSharedLineUpdate]
    ) -> [CandidateMemory] {
        guard !sharedLines.isEmpty else { return [] }

        let summaryCandidates = drafts.flatMap { draft in
            fallbackSentences(from: draft.summary).map { sentence in
                FallbackMemoryInput(
                    sentence: sentence,
                    title: nil,
                    provenance: ReflectionProvenance(
                        sessionId: session.id,
                        segmentId: draft.segmentId,
                        characterRange: 0..<0
                    )
                )
            }
        }

        let lineCandidates = sharedLines.flatMap { line in
            fallbackSentences(from: "\(line.lastPosition)\n\(line.nextStep ?? "")").map { sentence in
                FallbackMemoryInput(
                    sentence: sentence,
                    title: line.title,
                    provenance: line.provenance
                )
            }
        }

        let candidates = (summaryCandidates + lineCandidates)
            .compactMap { fallbackMemory(from: $0) }

        return dedupeMemories(candidates).prefix(3).map { $0 }
    }

    private func fallbackMemory(from input: FallbackMemoryInput) -> CandidateMemory? {
        let sentence = cleanFallbackSentence(input.sentence)
        guard sentence.count >= 8 else { return nil }
        guard !isWeakFallbackSentence(sentence) else { return nil }
        guard let kind = fallbackMemoryKind(for: sentence) else { return nil }

        let content: String
        if shouldAttachLineTitle(to: sentence), let title = input.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            content = "\(title)：\(sentence)"
        } else {
            content = sentence
        }

        return CandidateMemory(
            kind: kind,
            content: ensureTerminalPunctuation(content),
            confidence: 0.78,
            tags: ["fallback", "shared-line"],
            provenance: input.provenance
        )
    }

    private func fallbackSentences(from value: String) -> [String] {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "。")
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?"))
            .map(cleanFallbackSentence)
            .filter { !$0.isEmpty }
    }

    private func cleanFallbackSentence(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = result.first, first.isNumber || first == "." || first == "、" || first == "-" || first == " " {
            result.removeFirst()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private func fallbackMemoryKind(for sentence: String) -> CandidateMemory.Kind? {
        if containsAny(sentence, ["偏好", "希望", "倾向", "更喜欢"]) {
            return .preference
        }
        if containsAny(sentence, ["决定", "采用", "默认使用", "选定", "确定用", "v1 先", "V1 先"]) {
            return .decision
        }
        if containsAny(sentence, ["已完成", "已确认", "已定位", "诊断结论", "失败点", "当前卡在", "卡在", "不可用", "已经修复"]) {
            return .fact
        }
        return nil
    }

    private func isWeakFallbackSentence(_ sentence: String) -> Bool {
        let weakValues = [
            "已确认问题",
            "已完成导入",
            "正在验证",
            "继续验证",
            "继续测试",
            "开始整理",
            "整理完成",
            "下一步"
        ]
        return weakValues.contains { sentence.contains($0) }
    }

    private func shouldAttachLineTitle(to sentence: String) -> Bool {
        sentence.hasPrefix("已") || sentence.hasPrefix("正在") || sentence.hasPrefix("配置") || sentence.hasPrefix("问题")
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private func ensureTerminalPunctuation(_ value: String) -> String {
        guard let last = value.last, !"。！？.!?".contains(last) else { return value }
        return "\(value)。"
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

private struct FallbackMemoryInput {
    var sentence: String
    var title: String?
    var provenance: ReflectionProvenance
}
