import Foundation

struct RecallContextPackage: Equatable {
    var contextCard: ContextCard
    var line: ContinuityLine
    var memories: [Memory]
    var request: String

    var formattedText: String {
        var sections: [String] = []
        sections.append(
            """
            # Agent
            \(contextCard.agentProfile)

            # 用户
            \(contextCard.userProfile)
            """
        )

        sections.append(
            """
            # 共同线
            标题：\(line.title)
            里程碑：
            \(line.lastPosition)
            下一步：\(line.nextStep?.isEmpty == false ? line.nextStep! : "暂无")
            """
        )

        let memoryText: String
        if memories.isEmpty {
            memoryText = "暂无已选择事实记忆。"
        } else {
            memoryText = memories.enumerated().map { index, memory in
                let tags = memory.tags.isEmpty ? "" : " 标签：\(memory.tags.joined(separator: ", "))"
                return "\(index + 1). \(memory.content)\(tags)"
            }
            .joined(separator: "\n")
        }

        sections.append(
            """
            # 相关事实记忆
            \(memoryText)
            """
        )

        sections.append(
            """
            # 请求
            \(request)
            """
        )

        return sections.joined(separator: "\n\n")
    }
}

struct RecallContextBuilder {
    static let defaultRequest = "请基于以上上下文继续。不要假设未提供的信息；如果信息不足，先指出缺口。"

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
