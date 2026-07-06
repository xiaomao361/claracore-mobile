import Foundation

struct LocalOrganizationRulebook: Equatable {
    static let current = LocalOrganizationRulebook()

    let version = "local-v1"
    let maximumSentences = 8
    let maximumMemoryCandidates = 4
    let memoryTags = ["local", "conversation"]
    let weakSentences = ["好的", "嗯", "是的", "谢谢", "继续", "OK", "ok"]
    let speakerOnlySentences = ["用户", "助手", "User", "Assistant"]
    let preferenceKeywords = ["偏好", "希望", "想要", "倾向", "更喜欢"]
    let decisionKeywords = ["决定", "采用", "确认", "选定", "先做", "不做"]
    let taskKeywords = ["待办", "下一步", "需要", "计划"]

    var displayName: String {
        "本机规则 \(version)"
    }

    var settingsSummary: String {
        "从用户主动导入的文本中保守摘取句子，按关键词区分事实、偏好、决定和待办；最多保留 \(maximumMemoryCandidates) 条候选记忆和 1 条共同线，不推断原文没有明确出现的信息。"
    }

    var privacySummary: String {
        "本机规则只在设备内运行，不需要 API Key，也不会把导入内容发送给模型提供方。"
    }
}
