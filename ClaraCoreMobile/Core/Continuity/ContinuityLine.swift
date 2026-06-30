import Foundation

struct AffectiveTraceNode: Codable, Equatable, Identifiable {
    var id: String
    var tone: String
    var valence: String
    var intensity: String
    var stability: String
    var signals: [String]
    var note: String

    init(
        id: String = UUID().uuidString,
        tone: String = "",
        valence: String = "unclear",
        intensity: String = "medium",
        stability: String = "session",
        signals: [String] = [],
        note: String = ""
    ) {
        self.id = id
        self.tone = tone
        self.valence = valence
        self.intensity = intensity
        self.stability = stability
        self.signals = signals
        self.note = note
    }
}

struct ContinuityLine: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case active
        case archived
    }

    var id: String
    var title: String
    var lastPosition: String
    var nextStep: String?
    var contextCardId: String? = nil
    var stateSummary: String = ""
    var currentInterpretation: String = ""
    var interpretationStatus: String = "active"
    var emotionalArc: [String] = []
    var affectiveTrace: [AffectiveTraceNode] = []
    var realityLine: String = ""
    var boundaryNotes: String = ""
    var misreadRisks: String = ""
    var status: Status
    var createdAt: Date
    var updatedAt: Date

    var milestoneSteps: [String] {
        let lines = lastPosition
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let parsed = lines.map(Self.stripMilestonePrefix)
        return parsed.isEmpty ? [lastPosition.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty } : parsed
    }

    private static func stripMilestonePrefix(_ line: String) -> String {
        let patterns = [
            #"^\d+[\.、\)]\s*"#,
            #"^[-*]\s+"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                let stripped = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if stripped != line {
                    return stripped
                }
            }
        }

        return line
    }

    var milestoneProgressTitle: String {
        let count = milestoneSteps.count
        guard count > 1 else {
            return "当前里程"
        }
        return "当前里程 \(count)"
    }

    var completedMilestoneSteps: [String] {
        guard milestoneSteps.count > 1 else { return [] }
        return Array(milestoneSteps.dropLast())
    }

    var currentMilestone: String? {
        milestoneSteps.last
    }

    var journeyProgressTitle: String {
        let completedCount = completedMilestoneSteps.count
        guard completedCount > 0 else { return "当前站" }
        return "已过 \(completedCount) 站"
    }

    var latestAffectiveTrace: AffectiveTraceNode? {
        affectiveTrace.last
    }

    var hasRichState: Bool {
        !stateSummary.isEmpty ||
            !currentInterpretation.isEmpty ||
            !emotionalArc.isEmpty ||
            !affectiveTrace.isEmpty ||
            !realityLine.isEmpty ||
            !boundaryNotes.isEmpty ||
            !misreadRisks.isEmpty
    }

    var interpretationStatusTitle: String {
        switch interpretationStatus {
        case "needs_review":
            return "待确认"
        case "stale":
            return "可能过期"
        case "closed":
            return "已关闭"
        default:
            return "进行中"
        }
    }
}
