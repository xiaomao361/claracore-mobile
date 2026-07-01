import Foundation

struct RecallContextPackage: Equatable {
    var contextCard: ContextCard
    var line: ContinuityLine
    var memories: [Memory]
    var request: String

    var formattedText: String {
        let memoryLines: String
        if memories.isEmpty {
            memoryLines = "- 暂时没有额外事实记忆。"
        } else {
            memoryLines = memories.map { memory in
                let kind = memory.kindLabel.map { "\($0)： " } ?? ""
                return "- \(kind)\(memory.content)"
            }
            .joined(separator: "\n")
        }
        let completedSteps = line.completedMilestoneSteps.map { "- \($0)" }.joined(separator: "\n")
        let completedSection = completedSteps.isEmpty ? "- 还没有明确的历史里程。" : completedSteps
        let currentStep = line.currentMilestone ?? line.lastPosition
        let nextStep = line.nextStep?.isEmpty == false ? line.nextStep! : "先确认当前最需要推进的一步。"
        let continuityStateText = line.richRecallText

        return """
        请接着这段关系和这条共同线继续，不要把它改写成总结或报告。

        你现在的角色：
        \(contextCard.agentProfile)

        你正在面对的用户：
        \(contextCard.userProfile)

        我们正在延续：
        \(line.title)

        已经走过：
        \(completedSection)

        现在停在：
        - \(currentStep)

        接下来先做：
        - \(nextStep)

        连续性状态：
        \(continuityStateText)

        需要记住的事实：
        \(memoryLines)

        这次请这样继续：
        \(request)
        """
    }
}

struct RecallContextBuilder {
    static let defaultRequest = "自然接着说就好。信息不够时先问我，不要补成正式报告。"

    func query(for line: ContinuityLine) -> String {
        [line.title, line.lastPosition, line.nextStep]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func build(
        contextCard: ContextCard,
        line: ContinuityLine,
        memories: [Memory],
        request: String = Self.defaultRequest
    ) -> RecallContextPackage {
        RecallContextPackage(contextCard: contextCard, line: line, memories: memories, request: request)
    }
}

private extension Memory {
    var kindLabel: String? {
        if tags.contains("preference") {
            return "偏好"
        }
        if tags.contains("decision") {
            return "决定"
        }
        if tags.contains("task") {
            return "任务"
        }
        if tags.contains("fact") {
            return "事实"
        }
        return nil
    }
}

private extension ContinuityLine {
    var richRecallText: String {
        var parts: [String] = []
        if !stateSummary.isEmpty {
            parts.append("- 当前状态：\(stateSummary)")
        }
        if !currentInterpretation.isEmpty {
            parts.append("- 当前理解（\(interpretationStatusTitle)）：\(currentInterpretation)")
        }
        if !emotionalArc.isEmpty {
            parts.append("- 位置弧线：\n" + emotionalArc.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if let trace = latestAffectiveTrace {
            let signals = trace.signals.isEmpty ? "" : "；信号：\(trace.signals.joined(separator: "、"))"
            parts.append("- 情绪弧线：\(trace.tone.isEmpty ? "未命名" : trace.tone)，\(trace.valence)，\(trace.intensity)，\(trace.stability)\(signals)。\(trace.note)")
        }
        if !realityLine.isEmpty {
            parts.append("- 已确认的现实：\(realityLine)")
        }
        if !boundaryNotes.isEmpty {
            parts.append("- 边界：\(boundaryNotes)")
        }
        if !misreadRisks.isEmpty {
            parts.append("- 容易误读的地方：\(misreadRisks)")
        }
        return parts.isEmpty ? "- 暂无额外弧线状态。" : parts.joined(separator: "\n")
    }
}
