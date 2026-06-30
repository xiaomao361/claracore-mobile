import SwiftUI

struct SettingsFeatureView: View {
    let contextCardStore: ContextCardStore
    let apiKeyStore: APIKeyStore
    let reflectionConfiguration: ReflectionConfiguration
    @Binding var selectedContextCardID: String?
    let onConfigurationChanged: () -> Void

    @State private var contextCards: [ContextCard] = []
    @State private var cardTitle = ""
    @State private var agentProfile = ""
    @State private var userProfile = ""
    @State private var modelProviderName = ""
    @State private var modelBaseURL = ""
    @State private var modelName = ""
    @State private var modelAPIKey = ""
    @State private var hasSavedModelKey = false
    @State private var isTestingModel = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClaraSectionLabel(title: "角色卡")

                ClaraCard(accent: ClaraDesign.continuity) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Picker("当前角色卡", selection: selectedContextCardBinding) {
                                ForEach(contextCards) { card in
                                    Text(card.title).tag(card.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedContextCardID) { _, _ in
                                resetContextCardDraft()
                            }

                            Spacer()

                            Button {
                                createContextCard()
                            } label: {
                                Label("新建", systemImage: "plus")
                            }
                            .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.continuity))
                        }

                        TextField("角色卡标题", text: $cardTitle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Agent 是谁")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ClaraDesign.inkMuted)
                            TextEditor(text: $agentProfile)
                                .frame(minHeight: 96)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(ClaraDesign.surfaceMuted.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("用户是谁")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ClaraDesign.inkMuted)
                            TextEditor(text: $userProfile)
                                .frame(minHeight: 112)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(ClaraDesign.surfaceMuted.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))
                        }

                        HStack {
                            Button {
                                saveContextCard()
                            } label: {
                                Label("保存角色卡", systemImage: "person.text.rectangle")
                            }
                            .disabled(!canSaveContextCard)
                            .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.continuity))

                            Spacer()

                            Button {
                                resetContextCardDraft()
                            } label: {
                                Label("还原", systemImage: "arrow.uturn.backward")
                            }
                            .disabled(currentContextCard == nil)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }
                    }
                }

                ClaraSectionLabel(title: "默认整理模型")

                ClaraCard(accent: reflectionConfiguration.mode == .remoteModel ? ClaraDesign.memory : ClaraDesign.reflection) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前模式")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            ClaraStatusPill(
                                title: currentModeTitle,
                                color: reflectionConfiguration.mode == .remoteModel ? ClaraDesign.memory : ClaraDesign.reflection,
                                systemImage: reflectionConfiguration.mode == .remoteModel ? "checkmark.seal" : "sparkles"
                            )
                        }

                        if reflectionConfiguration.mode == .localPlaceholder {
                            Text("本地占位模式只会生成摘要，不会提取候选记忆或共同线。配置默认模型 Key 后，导入会自动进入真实整理流程。")
                                .font(.system(size: 14))
                                .foregroundStyle(ClaraDesign.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                ClaraSectionLabel(title: "模型配置")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("OpenAI-compatible")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            ClaraStatusPill(title: modelProviderName.isEmpty ? "未配置" : modelProviderName, color: ClaraDesign.memory, systemImage: "server.rack")
                        }

                        TextField("Provider 名称，例如 DeepSeek / OpenAI / 自部署", text: $modelProviderName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        TextField("Base URL，例如 https://api.deepseek.com", text: $modelBaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)

                        TextField("Model，例如 deepseek-v4-pro / gpt-4.1", text: $modelName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField(hasSavedModelKey ? "API Key 已保存，留空则不修改" : "API Key", text: $modelAPIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button {
                                saveModelConfiguration()
                            } label: {
                                Label("保存配置", systemImage: "key")
                            }
                            .disabled(!canSaveModelConfiguration)
                            .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                            Spacer()

                            Button(role: .destructive) {
                                deleteModelKey()
                            } label: {
                                Label("删除 Key", systemImage: "trash")
                            }
                            .disabled(!hasSavedModelKey)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }

                        Button {
                            testModelConnection()
                        } label: {
                            Label(isTestingModel ? "正在测试" : "测试连接", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!canTestModelConnection || isTestingModel)
                        .buttonStyle(ClaraSecondaryButtonStyle())

                        if hasSavedModelKey {
                            ClaraStatusPill(title: "已保存到本机 Keychain", color: ClaraDesign.memory, systemImage: "lock")
                        }
                    }
                }

                if let statusMessage {
                    ClaraActionStatus(message: statusMessage, tone: .success)
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .claraKeyboardDismissable()
        .task {
            loadState()
        }
        .alert("设置错误", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var canSaveContextCard: Bool {
        !cardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !agentProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !userProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentModeTitle: String {
        if reflectionConfiguration.mode == .remoteModel,
           let provider = reflectionConfiguration.modelProvider {
            return provider.trimmedProviderName
        }
        return reflectionConfiguration.mode.title
    }

    private var canSaveModelConfiguration: Bool {
        currentModelDraft.baseURL != nil &&
            !currentModelDraft.trimmedModel.isEmpty &&
            (hasSavedModelKey || !modelAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var canTestModelConnection: Bool {
        currentModelDraft.baseURL != nil &&
            !currentModelDraft.trimmedModel.isEmpty &&
            (hasSavedModelKey || !modelAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var currentModelDraft: ModelProviderConfiguration {
        ModelProviderConfiguration(
            providerName: modelProviderName,
            baseURLString: modelBaseURL,
            model: modelName
        ).normalized
    }

    private var currentContextCard: ContextCard? {
        guard let selectedContextCardID else { return contextCards.first }
        return contextCards.first { $0.id == selectedContextCardID } ?? contextCards.first
    }

    private var selectedContextCardBinding: Binding<String> {
        Binding(
            get: { selectedContextCardID ?? contextCards.first?.id ?? ContextCardStore.defaultCardID },
            set: { selectedContextCardID = $0 }
        )
    }

    private func loadState() {
        do {
            _ = try contextCardStore.defaultCard()
            contextCards = try contextCardStore.list()
            if selectedContextCardID == nil {
                selectedContextCardID = contextCards.first?.id
            }
            resetContextCardDraft()
            resetModelConfigurationDraft()
            hasSavedModelKey = try readSavedModelKey() != nil
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func resetContextCardDraft() {
        guard let contextCard = currentContextCard else { return }
        cardTitle = contextCard.title
        agentProfile = contextCard.agentProfile
        userProfile = contextCard.userProfile
    }

    private func createContextCard() {
        do {
            let card = try contextCardStore.create(
                title: "新的角色卡",
                agentProfile: ContextCardStore.defaultAgentProfile,
                userProfile: ContextCardStore.defaultUserProfile
            )
            contextCards = try contextCardStore.list()
            selectedContextCardID = card.id
            resetContextCardDraft()
            statusMessage = "已创建新的角色卡。"
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func saveContextCard() {
        do {
            guard let card = currentContextCard else { return }
            try contextCardStore.update(
                id: card.id,
                title: cardTitle,
                agentProfile: agentProfile,
                userProfile: userProfile
            )
            contextCards = try contextCardStore.list()
            resetContextCardDraft()
            statusMessage = "角色卡已更新。之后复制回召包会使用新的 Agent / 用户描述。"
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func resetModelConfigurationDraft() {
        let configuration = ModelProviderConfigurationStore.load()
        modelProviderName = configuration.providerName
        modelBaseURL = configuration.baseURLString
        modelName = configuration.model
        modelAPIKey = ""
    }

    private func saveModelConfiguration() {
        do {
            let configuration = currentModelDraft
            guard configuration.baseURL != nil, !configuration.trimmedModel.isEmpty else {
                throw SettingsModelError.invalidConfiguration
            }
            try ModelProviderConfigurationStore.save(configuration)
            let trimmedKey = modelAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                try apiKeyStore.save(trimmedKey, service: .modelProvider)
                modelAPIKey = ""
                hasSavedModelKey = true
            }
            statusMessage = "默认整理模型已保存。之后导入会使用 \(configuration.trimmedProviderName) 的 \(configuration.trimmedModel)。"
            onConfigurationChanged()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func deleteModelKey() {
        do {
            try apiKeyStore.delete(service: .modelProvider)
            try apiKeyStore.delete(service: .deepSeek)
            hasSavedModelKey = false
            statusMessage = "模型 Key 已删除，整理会回到本地占位模式。"
            onConfigurationChanged()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func testModelConnection() {
        guard !isTestingModel else { return }
        isTestingModel = true
        statusMessage = "正在测试默认整理模型连接..."

        Task {
            do {
                let configuration = currentModelDraft
                guard let baseURL = configuration.baseURL, !configuration.trimmedModel.isEmpty else {
                    throw SettingsModelError.invalidConfiguration
                }
                let enteredKey = modelAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let savedKey = try readSavedModelKey()
                let key = enteredKey.isEmpty ? savedKey : enteredKey
                guard let key, !key.isEmpty else {
                    throw OpenAICompatibleReflectionService.ServiceError.missingAPIKey
                }
                try await OpenAICompatibleReflectionService(
                    apiKey: key,
                    model: configuration.trimmedModel,
                    baseURL: baseURL
                ).validateConnection()

                await MainActor.run {
                    isTestingModel = false
                    statusMessage = "\(configuration.trimmedProviderName) 连接正常。可以开始整理真实导入内容。"
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isTestingModel = false
                    statusMessage = nil
                    errorMessage = ClaraErrorPresenter.message(for: error)
                }
            }
        }
    }

    private func readSavedModelKey() throws -> String? {
        if let key = try apiKeyStore.read(service: .modelProvider), !key.isEmpty {
            return key
        }
        return try apiKeyStore.read(service: .deepSeek)
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    SettingsFeatureView(
        contextCardStore: ContextCardStore(database: database),
        apiKeyStore: KeychainAPIKeyStore(serviceName: "preview"),
        reflectionConfiguration: ReflectionConfiguration(mode: .localPlaceholder, modelProvider: .deepSeekDefault),
        selectedContextCardID: .constant(ContextCardStore.defaultCardID),
        onConfigurationChanged: {}
    )
}

private enum SettingsModelError: LocalizedError {
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "模型配置不完整。请确认 Base URL 和 Model 都有效。"
        }
    }
}
