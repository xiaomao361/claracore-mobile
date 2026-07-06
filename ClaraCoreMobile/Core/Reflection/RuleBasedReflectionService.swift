import Foundation

struct RuleBasedReflectionService: ReflectionService {
    private let rulebook: LocalOrganizationRulebook

    init(rulebook: LocalOrganizationRulebook = .current) {
        self.rulebook = rulebook
    }

    func reflect(segment: CaptureSegment) async throws -> SegmentReflectionDraft {
        let sentences = informativeSentences(from: segment.content)
        let summary = sentences.first ?? ""
        let provenance = ReflectionProvenance(
            sessionId: segment.sessionId,
            segmentId: segment.id,
            characterRange: segment.characterRange
        )

        return SegmentReflectionDraft(
            segmentId: segment.id,
            summary: summary,
            candidateMemories: memoryCandidates(from: sentences, provenance: provenance),
            candidateSharedLineUpdates: sharedLineCandidates(from: sentences, segment: segment, provenance: provenance),
            uncertainItems: summary.isEmpty ? ["empty_segment"] : []
        )
    }

    func reconcile(session: ImportSession, drafts: [SegmentReflectionDraft]) async throws -> DigestResult {
        DraftDigestReconciler(summaryLimit: 5).digest(session: session, drafts: drafts)
    }

    private func informativeSentences(from content: String) -> [String] {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "。")
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?"))
            .map(cleanSentence)
            .filter { sentence in
                sentence.count >= 6 &&
                    !isSpeakerOnly(sentence) &&
                    !isWeakSentence(sentence)
            }
            .prefix(rulebook.maximumSentences)
            .map(ensureTerminalPunctuation)
    }

    private func memoryCandidates(from sentences: [String], provenance: ReflectionProvenance) -> [CandidateMemory] {
        sentences
            .prefix(rulebook.maximumMemoryCandidates)
            .enumerated()
            .map { index, sentence in
                CandidateMemory(
                    kind: memoryKind(for: sentence),
                    content: sentence,
                    confidence: max(0.78, 0.86 - Double(index) * 0.02),
                    tags: rulebook.memoryTags,
                    provenance: provenance
                )
            }
    }

    private func sharedLineCandidates(
        from sentences: [String],
        segment: CaptureSegment,
        provenance: ReflectionProvenance
    ) -> [CandidateSharedLineUpdate] {
        guard let first = sentences.first else { return [] }
        let title = compactTitle(from: first)
        let milestones = sentences
            .prefix(4)
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        return [
            CandidateSharedLineUpdate(
                title: title,
                lastPosition: milestones,
                nextStep: "继续基于这段对话材料整理上下文。",
                stateSummary: first,
                currentInterpretation: "本机规则根据用户主动导入的对话材料提取了可继续的上下文。",
                interpretationStatus: "needs_review",
                emotionalArc: [],
                affectiveTrace: [],
                realityLine: milestones,
                boundaryNotes: "本机规则只做保守摘录，不推断未明确出现的信息。",
                misreadRisks: "不要把摘录内容当作完整结论；必要时回看原文 Archive。",
                confidence: 0.74,
                provenance: provenance
            )
        ]
    }

    private func cleanSentence(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = result.first, first.isNumber || first == "." || first == "、" || first == "-" || first == " " {
            result.removeFirst()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for prefix in ["用户：", "用户:", "助手：", "助手:", "User:", "Assistant:"] where result.hasPrefix(prefix) {
            result.removeFirst(prefix.count)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private func isSpeakerOnly(_ sentence: String) -> Bool {
        rulebook.speakerOnlySentences.contains(sentence)
    }

    private func isWeakSentence(_ sentence: String) -> Bool {
        rulebook.weakSentences.contains(sentence)
    }

    private func memoryKind(for sentence: String) -> CandidateMemory.Kind {
        if containsAny(sentence, rulebook.preferenceKeywords) {
            return .preference
        }
        if containsAny(sentence, rulebook.decisionKeywords) {
            return .decision
        }
        if containsAny(sentence, rulebook.taskKeywords) {
            return .task
        }
        return .fact
    }

    private func compactTitle(from sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 18 else { return trimmed }
        return "\(trimmed.prefix(18))..."
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.localizedCaseInsensitiveContains($0) }
    }

    private func ensureTerminalPunctuation(_ value: String) -> String {
        guard let last = value.last, !"。！？.!?".contains(last) else { return value }
        return "\(value)。"
    }
}
