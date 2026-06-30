import SwiftUI
import UIKit

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
    @State private var availableModels: [ModelProviderClient.Model] = []
    @State private var hasSavedModelKey = false
    @State private var isTestingModel = false
    @State private var isLoadingModels = false
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

                ClaraSectionLabel(title: "整理引擎")

                ClaraCard(accent: isRemoteModelEnabled ? ClaraDesign.memory : ClaraDesign.reflection) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isRemoteModelEnabled ? "远程整理已启用" : "本地占位")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ClaraDesign.ink)
                                Text(isRemoteModelEnabled ? "导入后会调用下方模型配置，生成记忆和共同线。" : "未保存模型 Key 时不会远程整理，也不会自动写入候选记忆。")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ClaraDesign.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            ClaraStatusPill(
                                title: currentModeTitle,
                                color: isRemoteModelEnabled ? ClaraDesign.memory : ClaraDesign.reflection,
                                systemImage: isRemoteModelEnabled ? "checkmark.seal" : "sparkles"
                            )
                        }

                        HStack(spacing: 8) {
                            ClaraStatusPill(title: currentModelDraft.trimmedProviderName, color: ClaraDesign.memory, systemImage: "server.rack")
                            ClaraStatusPill(title: currentModelDraft.trimmedModel.isEmpty ? "未选择模型" : currentModelDraft.trimmedModel, color: ClaraDesign.continuity, systemImage: "cpu")
                        }
                    }
                }

                ClaraSectionLabel(title: "模型配置")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("OpenAI-compatible")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ClaraDesign.ink)
                                Spacer()
                                ClaraStatusPill(title: hasSavedModelKey ? "Key 已保存" : "需要 Key", color: hasSavedModelKey ? ClaraDesign.memory : ClaraDesign.reflection, systemImage: hasSavedModelKey ? "lock" : "key")
                            }
                            Text("填写兼容 Chat Completions 的地址和 Key，先查询模型，再选择默认整理模型。DeepSeek 只是默认预设之一。")
                                .font(.system(size: 13))
                                .foregroundStyle(ClaraDesign.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ClaraInlineField(
                                title: "Provider",
                                subtitle: "只用于界面显示，例如 DeepSeek / OpenAI / 自部署。",
                                text: $modelProviderName,
                                placeholder: "Provider 名称"
                            )

                            ClaraInlineField(
                                title: "Base URL",
                                subtitle: "不需要写 /chat/completions。示例：https://api.openai.com/v1",
                                text: $modelBaseURL,
                                placeholder: "https://api.deepseek.com",
                                keyboardType: .URL
                            )

                            VStack(alignment: .leading, spacing: 7) {
                                Text("API Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ClaraDesign.ink)
                                SecureField(hasSavedModelKey ? "已保存，留空则不修改" : "输入模型 API Key", text: $modelAPIKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                Text("Key 只保存到本机 Keychain；查询模型和测试连接会把它作为 Authorization header 发给上面的 Base URL。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ClaraDesign.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                loadAvailableModels()
                            } label: {
                                Label(isLoadingModels ? "正在查询" : "查询模型", systemImage: "list.bullet.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!canLoadModels || isLoadingModels)
                            .buttonStyle(ClaraSecondaryButtonStyle())

                            Button {
                                testModelConnection()
                            } label: {
                                Label(isTestingModel ? "正在测试" : "测试连接", systemImage: "checkmark.seal")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!canTestModelConnection || isTestingModel)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("默认整理模型")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ClaraDesign.ink)
                                Spacer()
                                if !availableModels.isEmpty {
                                    ClaraStatusPill(title: "\(availableModels.count) 个可选", color: ClaraDesign.continuity, systemImage: "checklist")
                                }
                            }

                            HStack(spacing: 10) {
                                Image(systemName: modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "cpu" : "checkmark.circle.fill")
                                    .foregroundStyle(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ClaraDesign.inkMuted : ClaraDesign.memory)
                                Text(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请先查询模型并选择" : modelName)
                                    .font(.system(size: 15, weight: modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .regular : .semibold))
                                    .foregroundStyle(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ClaraDesign.inkMuted : ClaraDesign.ink)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 11)
                            .background(ClaraDesign.surfaceMuted.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))

                            if !availableModels.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(availableModels.prefix(12)) { model in
                                        Button {
                                            modelName = model.id
                                            statusMessage = "已选择模型：\(model.id)"
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: modelName == model.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(modelName == model.id ? ClaraDesign.memory : ClaraDesign.inkMuted)
                                                Text(model.id)
                                                    .font(.system(size: 14, weight: modelName == model.id ? .semibold : .regular))
                                                    .foregroundStyle(ClaraDesign.ink)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 9)
                                            .background(modelName == model.id ? ClaraDesign.memory.opacity(0.10) : ClaraDesign.surfaceMuted.opacity(0.45))
                                            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if availableModels.count > 12 {
                                        Text("还有 \(availableModels.count - 12) 个模型未显示。当前只展示前 12 个，后续可以增加搜索筛选。")
                                            .font(.system(size: 12))
                                            .foregroundStyle(ClaraDesign.inkMuted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            } else {
                                Text("模型只能从查询结果中选择。请先填写 Base URL 和 API Key，然后点击“查询模型”。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ClaraDesign.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                saveModelConfiguration()
                            } label: {
                                Label("保存配置", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!canSaveModelConfiguration)
                            .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                            Button(role: .destructive) {
                                deleteModelKey()
                            } label: {
                                Label("删除 Key", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!hasSavedModelKey)
                            .buttonStyle(ClaraSecondaryButtonStyle())
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
        if isRemoteModelEnabled {
            return currentModelDraft.trimmedProviderName
        }
        return ReflectionConfiguration.Mode.localPlaceholder.title
    }

    private var isRemoteModelEnabled: Bool {
        hasSavedModelKey &&
            currentModelDraft.baseURL != nil &&
            !currentModelDraft.trimmedModel.isEmpty
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

    private var canLoadModels: Bool {
        currentModelDraft.baseURL != nil &&
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
            availableModels = []
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

    private func loadAvailableModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        statusMessage = "正在查询可用模型..."

        Task {
            do {
                let configuration = currentModelDraft
                guard let baseURL = configuration.baseURL else {
                    throw SettingsModelError.invalidConfiguration
                }
                let enteredKey = modelAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let savedKey = try readSavedModelKey()
                let key = enteredKey.isEmpty ? savedKey : enteredKey
                guard let key, !key.isEmpty else {
                    throw OpenAICompatibleReflectionService.ServiceError.missingAPIKey
                }

                let models = try await ModelProviderClient(baseURL: baseURL, apiKey: key).listModels()

                await MainActor.run {
                    availableModels = models
                    if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let firstModel = models.first {
                        modelName = firstModel.id
                    }
                    isLoadingModels = false
                    statusMessage = "已找到 \(models.count) 个可用模型。"
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                    statusMessage = nil
                    errorMessage = ClaraErrorPresenter.message(for: error)
                }
            }
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

private struct ClaraInlineField: View {
    var title: String
    var subtitle: String
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ClaraDesign.ink)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(ClaraDesign.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
