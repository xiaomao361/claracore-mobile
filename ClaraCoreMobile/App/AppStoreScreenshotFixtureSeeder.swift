import Foundation

enum AppStoreScreenshotFixtureSeeder {
    enum Target: String {
        case `import` = "import"
        case importResult = "import-result"
        case archive
        case memory
        case sharedLine = "shared-line"
        case recallPackage = "recall-package"
        case settings
        case settingsSupport = "settings-support"
    }

    static let environmentKey = "CLARACORE_SCREENSHOT_MODE"
    static let tabEnvironmentKey = "CLARACORE_SCREENSHOT_TAB"
    private static let sampleSessionID = "app-store-screenshot-sample-import"
    private static let sampleThreadID = "app-store-screenshot-fixture"
    private static let sampleLineTitle = "ClaraCore 上架准备共同线"
    private static let sampleMemoryTag = "screenshot-sample"
    private static let sampleModelConfiguration = ModelProviderConfiguration(
        providerName: "示例 OpenAI-compatible",
        baseURLString: "https://api.example.com/v1",
        model: "context-organizer-demo"
    )

    static func seedIfRequested(
        dependencies: AppDependencies,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        guard environment[environmentKey] == "1" else { return }
        try seed(dependencies: dependencies, target: target(environment: environment))
    }

    static func initialTab(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppTab {
        guard environment[environmentKey] == "1" else { return .importer }
        switch target(environment: environment) {
        case .archive:
            return .archive
        case .memory:
            return .memoria
        case .sharedLine:
            return .continuity
        case .settings, .settingsSupport:
            return .settings
        default:
            return .importer
        }
    }

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentKey] == "1"
    }

    static func target(environment: [String: String] = ProcessInfo.processInfo.environment) -> Target {
        guard isEnabled(environment: environment),
              let value = environment[tabEnvironmentKey],
              let target = Target(rawValue: value) else {
            return .import
        }
        return target
    }

    static func seed(dependencies: AppDependencies, target: Target = target()) throws {
        try seedModelConfigurationIfNeeded(dependencies: dependencies)
        guard target != .import else { return }
        let contextCard = try dependencies.contextCardStore.defaultCard()
        let line = try seedLineIfNeeded(dependencies: dependencies, contextCardID: contextCard.id)
        try seedMemoriesIfNeeded(dependencies: dependencies, contextCardID: contextCard.id, lineID: line.id)
        try seedArchiveIfNeeded(dependencies: dependencies, contextCardID: contextCard.id, lineID: line.id)
    }

    static func sampleCommitResult(line: ContinuityLine) -> DigestCommitResult {
        let now = Date()
        return DigestCommitResult(
            memories: [
                Memory(
                    id: "app-store-screenshot-memory-local",
                    content: "默认使用本机规则整理导入内容；外部模型必须完成配置、同意和 Key 后才会启用。",
                    tags: [sampleMemoryTag, "local-first"],
                    isPrivate: false,
                    isArchived: false,
                    sourceAgent: "screenshot-fixture",
                    lineId: line.id,
                    contextCardId: line.contextCardId,
                    confidence: 0.96,
                    importance: 0.82,
                    createdAt: now,
                    updatedAt: now
                ),
                Memory(
                    id: "app-store-screenshot-memory-release",
                    content: "上传前需要补齐截图、公开文档、签名归档和干净 release checkpoint。",
                    tags: [sampleMemoryTag, "release"],
                    isPrivate: false,
                    isArchived: false,
                    sourceAgent: "screenshot-fixture",
                    lineId: line.id,
                    contextCardId: line.contextCardId,
                    confidence: 0.94,
                    importance: 0.88,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            continuityLines: [line]
        )
    }

    private static func seedModelConfigurationIfNeeded(dependencies: AppDependencies) throws {
        try ModelProviderConfigurationStore.save(
            sampleModelConfiguration,
            userDefaults: dependencies.userDefaults
        )
        OrganizationEngineModeStore.save(.externalModel, userDefaults: dependencies.userDefaults)
        dependencies.userDefaults.set(
            true,
            forKey: ExternalModelProcessingConsentStore.userDefaultsKey
        )
    }

    private static func seedLineIfNeeded(dependencies: AppDependencies, contextCardID: String) throws -> ContinuityLine {
        if let existing = try dependencies.continuityStore.active(contextCardId: contextCardID)
            .first(where: { $0.title == sampleLineTitle }) {
            return existing
        }

        return try dependencies.continuityStore.create(
            title: sampleLineTitle,
            lastPosition: """
            1. 用户决定先把 ClaraCore Mobile 做成对话 Archive 和上下文整理工具。
            2. 默认走本机规则，外部模型只在保存配置、Key 和同意说明后启用。
            3. 上架前需要完成截图包、公开文档同步和签名归档验证。
            """,
            nextStep: "补齐最终截图后，用 final submission gate 做上传前检查。",
            contextCardId: contextCardID,
            stateSummary: "围绕 App Store 上架准备，正在收敛为本地优先、用户主动导入、可复制回召包的工具。",
            currentInterpretation: "用户需要一个可审核、可解释、不会误导为后台抓取的对话上下文工具。",
            interpretationStatus: "active",
            emotionalArc: ["从功能探索转向上架审查", "从外部模型依赖转向本机默认"],
            affectiveTrace: [
                AffectiveTraceNode(
                    tone: "谨慎推进",
                    valence: "constructive",
                    intensity: "medium",
                    stability: "release",
                    signals: ["关注 App Review 风险", "避免用户误解外部模型启用状态"],
                    note: "样例数据仅用于 App Store 截图，不包含真实用户内容。"
                )
            ],
            realityLine: "当前本地 readiness 已能通过；最终上传仍依赖开发者签名、公开材料和完整截图包。",
            boundaryNotes: "不要暗示自动读取其他应用，也不要展示真实 API Key 或私密对话。",
            misreadRisks: "如果截图只强调 AI，审核和用户都可能误解产品会处理 AI 聊天；应使用对话上下文整理表述。"
        )
    }

    private static func seedMemoriesIfNeeded(
        dependencies: AppDependencies,
        contextCardID: String,
        lineID: String
    ) throws {
        let existing = try dependencies.memoriaStore.recent(limit: 50, contextCardId: contextCardID)
        guard !existing.contains(where: { $0.tags.contains(sampleMemoryTag) }) else { return }

        _ = try dependencies.memoriaStore.store(
            content: "ClaraCore Mobile 默认使用本机规则整理导入内容；未保存外部模型 Key 和同意说明时不会发送到模型提供方。",
            tags: [sampleMemoryTag, "privacy", "local-first"],
            isPrivate: false,
            lineId: lineID,
            contextCardId: contextCardID,
            confidence: 0.96,
            importance: 0.82
        )
        _ = try dependencies.memoriaStore.store(
            content: "App Store 上传前必须补齐 iPhone 和 iPad 各 8 张截图，并确保公开隐私政策和支持文档与本地 release 文档一致。",
            tags: [sampleMemoryTag, "app-store", "release"],
            isPrivate: false,
            lineId: lineID,
            contextCardId: contextCardID,
            confidence: 0.94,
            importance: 0.88
        )
    }

    private static func seedArchiveIfNeeded(
        dependencies: AppDependencies,
        contextCardID: String,
        lineID: String
    ) throws {
        if try dependencies.importSessionStore.archivedSession(id: sampleSessionID) != nil {
            return
        }

        let rawContent = """
        用户：我想确认 ClaraCore Mobile 上架前到底还缺什么。
        助手：本地 readiness 已通过；真正上传前还需要开发者证书、签名归档、完整截图包、公开文档同步和一次干净 release checkpoint。
        用户：外部模型会不会让用户迷惑？
        助手：默认使用本机规则。只有保存模型配置、保存 Key、确认外部处理说明并选择外部模型后，才会在主动导入整理时使用外部模型。
        用户：截图里不要出现真实隐私内容。
        助手：截图样例应使用安全示例文本，展示主动导入、原文 Archive、记忆、共同线和回召包，不展示真实密钥。
        """
        let capture = RawCapture(
            id: sampleSessionID,
            source: .url,
            rawContent: rawContent,
            sourceApp: "DeepSeek",
            sourceThreadId: sampleThreadID,
            contextCardId: contextCardID,
            metadata: ["fixture": "app-store-screenshot"]
        )

        _ = try dependencies.inboxStore.enqueue(capture)
        _ = try dependencies.importSessionStore.create(from: capture, title: "上架准备对话样例")
        try dependencies.importSessionStore.addSegments([
            CaptureSegment(
                sessionId: capture.id,
                sequence: 0,
                content: rawContent,
                characterRange: 0..<rawContent.count,
                status: .reflected
            )
        ])
        try dependencies.importSessionStore.updateStatus(sessionId: capture.id, status: .committed)
        try dependencies.inboxStore.updateStatus(id: capture.id, status: .committed)
        try dependencies.inboxStore.updateCommitResult(
            id: capture.id,
            memoryIds: try dependencies.memoriaStore.related(toLineId: lineID).map(\.id),
            lineIds: [lineID]
        )
    }
}
