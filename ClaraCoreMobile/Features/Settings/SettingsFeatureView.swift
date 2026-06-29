import SwiftUI

struct SettingsFeatureView: View {
    let contextCardStore: ContextCardStore
    let apiKeyStore: APIKeyStore
    let reflectionConfiguration: ReflectionConfiguration
    let onConfigurationChanged: () -> Void

    @State private var contextCard: ContextCard?
    @State private var cardTitle = ""
    @State private var agentProfile = ""
    @State private var userProfile = ""
    @State private var deepSeekAPIKey = ""
    @State private var hasSavedDeepSeekKey = false
    @State private var isTestingDeepSeek = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClaraSectionLabel(title: "角色卡")

                ClaraCard(accent: ClaraDesign.continuity) {
                    VStack(alignment: .leading, spacing: 14) {
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
                            .disabled(contextCard == nil)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }
                    }
                }

                ClaraSectionLabel(title: "整理模型")

                ClaraCard(accent: reflectionConfiguration.mode == .deepSeek ? ClaraDesign.memory : ClaraDesign.reflection) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前模式")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            ClaraStatusPill(
                                title: reflectionConfiguration.mode.title,
                                color: reflectionConfiguration.mode == .deepSeek ? ClaraDesign.memory : ClaraDesign.reflection,
                                systemImage: reflectionConfiguration.mode == .deepSeek ? "checkmark.seal" : "sparkles"
                            )
                        }

                        if reflectionConfiguration.mode == .localPlaceholder {
                            Text("本地占位模式只会生成摘要，不会提取候选记忆或共同线。配置 DeepSeek 后，收件箱里的整理才会进入真实提取流程。")
                                .font(.system(size: 14))
                                .foregroundStyle(ClaraDesign.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                ClaraSectionLabel(title: "DeepSeek")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SecureField("API Key", text: $deepSeekAPIKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button {
                                saveDeepSeekKey()
                            } label: {
                                Label("保存", systemImage: "key")
                            }
                            .disabled(deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                            Spacer()

                            Button(role: .destructive) {
                                deleteDeepSeekKey()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .disabled(!hasSavedDeepSeekKey)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }

                        Button {
                            testDeepSeekConnection()
                        } label: {
                            Label(isTestingDeepSeek ? "正在测试" : "测试连接", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!hasSavedDeepSeekKey || isTestingDeepSeek)
                        .buttonStyle(ClaraSecondaryButtonStyle())

                        if hasSavedDeepSeekKey {
                            ClaraStatusPill(title: "已保存到本机 Keychain", color: ClaraDesign.memory, systemImage: "lock")
                        }
                    }
                }

                if let statusMessage {
                    ClaraCard(accent: ClaraDesign.memory) {
                        Text(statusMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(ClaraDesign.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
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

    private func loadState() {
        do {
            contextCard = try contextCardStore.defaultCard()
            resetContextCardDraft()
            hasSavedDeepSeekKey = try apiKeyStore.read(service: .deepSeek) != nil
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func resetContextCardDraft() {
        guard let contextCard else { return }
        cardTitle = contextCard.title
        agentProfile = contextCard.agentProfile
        userProfile = contextCard.userProfile
    }

    private func saveContextCard() {
        do {
            let card = try contextCardStore.defaultCard()
            try contextCardStore.update(
                id: card.id,
                title: cardTitle,
                agentProfile: agentProfile,
                userProfile: userProfile
            )
            contextCard = try contextCardStore.defaultCard()
            resetContextCardDraft()
            statusMessage = "角色卡已更新。之后复制回召包会使用新的 Agent / 用户描述。"
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func saveDeepSeekKey() {
        do {
            let trimmed = deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try apiKeyStore.save(trimmed, service: .deepSeek)
            deepSeekAPIKey = ""
            hasSavedDeepSeekKey = true
            statusMessage = "DeepSeek 已启用。之后收件箱整理会使用 DeepSeek 提取候选项。"
            onConfigurationChanged()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func deleteDeepSeekKey() {
        do {
            try apiKeyStore.delete(service: .deepSeek)
            hasSavedDeepSeekKey = false
            statusMessage = "DeepSeek key 已删除，整理会回到本地占位模式。"
            onConfigurationChanged()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func testDeepSeekConnection() {
        guard !isTestingDeepSeek else { return }
        isTestingDeepSeek = true
        statusMessage = "正在测试 DeepSeek 连接..."

        Task {
            do {
                guard let key = try apiKeyStore.read(service: .deepSeek), !key.isEmpty else {
                    throw DeepSeekReflectionService.ServiceError.missingAPIKey
                }
                try await DeepSeekReflectionService(apiKey: key).validateConnection()

                await MainActor.run {
                    isTestingDeepSeek = false
                    statusMessage = "DeepSeek 连接正常。可以开始整理真实导入内容。"
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isTestingDeepSeek = false
                    statusMessage = nil
                    errorMessage = ClaraErrorPresenter.message(for: error)
                }
            }
        }
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    SettingsFeatureView(
        contextCardStore: ContextCardStore(database: database),
        apiKeyStore: KeychainAPIKeyStore(serviceName: "preview"),
        reflectionConfiguration: ReflectionConfiguration(mode: .localPlaceholder),
        onConfigurationChanged: {}
    )
}
