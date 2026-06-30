import Foundation

struct RecallContextPackage: Equatable {
    var contextCard: ContextCard
    var line: ContinuityLine
    var memories: [Memory]
    var request: String

    var formattedText: String {
        let memoryText: String
        if memories.isEmpty {
            memoryText = "暂无额外事实记忆。"
        } else {
            memoryText = memories.enumerated().map { index, memory in
                let kind = memory.kindLabel.map { "【\($0)】" } ?? ""
                return "\(index + 1). \(kind)\(memory.content)"
            }
            .joined(separator: "\n")
        }
        let continuityStateText = line.richRecallText

        return """
        你现在继续使用下面这个角色和用户关系。

        【角色】
        \(contextCard.agentProfile)

        【用户】
        \(contextCard.userProfile)

        【我们正在延续的事】
        标题：\(line.title)
        已经走到：
        \(line.lastPosition)
        接下来先做：\(line.nextStep?.isEmpty == false ? line.nextStep! : "先确认当前最需要推进的一步。")

        【连续性状态】
        \(continuityStateText)

        【需要记住的事实】
        \(memoryText)

        【这次请你这样继续】
        \(request)
        """
    }
}

struct RecallContextBuilder {
    static let defaultRequest = "请自然接着这个状态继续。不要把这些内容改写成报告；如果信息不足，先问我。"

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
            parts.append("状态摘要：\(stateSummary)")
        }
        if !currentInterpretation.isEmpty {
            parts.append("当前解释（\(interpretationStatusTitle)）：\(currentInterpretation)")
        }
        if !emotionalArc.isEmpty {
            parts.append("位置弧线：\n" + emotionalArc.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        }
        if let trace = latestAffectiveTrace {
            let signals = trace.signals.isEmpty ? "" : "；信号：\(trace.signals.joined(separator: "、"))"
            parts.append("情绪弧线：\(trace.tone.isEmpty ? "未命名" : trace.tone)，\(trace.valence)，\(trace.intensity)，\(trace.stability)\(signals)。\(trace.note)")
        }
        if !realityLine.isEmpty {
            parts.append("确认事实：\(realityLine)")
        }
        if !boundaryNotes.isEmpty {
            parts.append("边界：\(boundaryNotes)")
        }
        if !misreadRisks.isEmpty {
            parts.append("误读风险：\(misreadRisks)")
        }
        return parts.isEmpty ? "暂无额外弧线状态。" : parts.joined(separator: "\n")
    }
}
