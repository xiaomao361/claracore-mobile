import Foundation

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
}
