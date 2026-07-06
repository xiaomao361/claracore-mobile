import SwiftUI

struct AppRootView: View {
    @AppStorage("activeContextCardID") private var persistedContextCardID = ""
    @State private var dependencies: AppDependencies?
    @State private var selectedContextCardID: String?
    @State private var selectedTab: AppTab
    @State private var focusedContinuityLineID: String?
    @State private var errorMessage: String?
    @State private var isStartupResetConfirmationPresented = false

    init() {
        _selectedTab = State(initialValue: AppStoreScreenshotFixtureSeeder.initialTab())
    }

    var body: some View {
        Group {
            if let dependencies {
                if AppStoreScreenshotFixtureSeeder.target() == .recallPackage {
                    screenshotRecallPackage(dependencies: dependencies)
                } else {
                    tabShell(dependencies: dependencies)
                }
            } else {
                startupView
            }
        }
        .task {
            guard dependencies == nil else { return }
            bootstrap()
        }
        .onChange(of: selectedContextCardID) { _, newValue in
            persistedContextCardID = newValue ?? ""
        }
        .confirmationDialog("清除本机数据并重试启动？", isPresented: $isStartupResetConfirmationPresented, titleVisibility: .visible) {
            Button("清除本机数据并重试", role: .destructive) {
                resetLocalDataAndBootstrap()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除本机 Archive、Inbox、记忆、共同线、角色卡、模型配置和 Key，然后恢复默认角色卡并重新启动应用。此操作不能撤销。")
        }
    }

    private var startupView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage {
                    ContentUnavailableView("启动失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))

                    Button {
                        bootstrap()
                    } label: {
                        Label("重试启动", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                    Button(role: .destructive) {
                        isStartupResetConfirmationPresented = true
                    } label: {
                        Label("清除本机数据并重试", systemImage: "trash.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraSecondaryButtonStyle())
                } else {
                    ProgressView()
                }
            }
            .padding(20)
            .navigationTitle("ClaraCore")
        }
    }

    private func tabShell(dependencies: AppDependencies) -> some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ImporterFeatureView(
                    inboxStore: dependencies.inboxStore,
                    preparer: dependencies.importSessionPreparer,
                    reflectionRunner: dependencies.reflectionRunner,
                    digestCommitter: dependencies.digestCommitter,
                    reflectionConfiguration: dependencies.reflectionConfiguration,
                    contextCardStore: dependencies.contextCardStore,
                    continuityStore: dependencies.continuityStore,
                    importerRegistry: dependencies.conversationImporterRegistry,
                    selectedContextCardID: $selectedContextCardID,
                    onShowMemories: { selectedTab = .memoria },
                    onShowContinuity: { lineId in
                        focusedContinuityLineID = lineId
                        selectedTab = .continuity
                    },
                    onShowSettings: { selectedTab = .settings }
                )
                .navigationTitle(AppTab.importer.title)
            }
            .tabItem { AppTab.importer.label }
            .tag(AppTab.importer)

            NavigationStack {
                ArchiveFeatureView(
                    store: dependencies.importSessionStore,
                    contextCardId: selectedContextCardID,
                    contextCardTitle: currentContextCardTitle(dependencies: dependencies)
                )
                    .navigationTitle(AppTab.archive.title)
            }
            .tabItem { AppTab.archive.label }
            .tag(AppTab.archive)

            NavigationStack {
                MemoriaFeatureView(
                    store: dependencies.memoriaStore,
                    contextCardId: selectedContextCardID,
                    contextCardTitle: currentContextCardTitle(dependencies: dependencies)
                )
                    .navigationTitle(AppTab.memoria.title)
            }
            .tabItem { AppTab.memoria.label }
            .tag(AppTab.memoria)

            NavigationStack {
                ContinuityFeatureView(
                    store: dependencies.continuityStore,
                    memoriaStore: dependencies.memoriaStore,
                    contextCardStore: dependencies.contextCardStore,
                    contextCardId: selectedContextCardID,
                    contextCardTitle: currentContextCardTitle(dependencies: dependencies),
                    focusedLineID: $focusedContinuityLineID
                )
                    .navigationTitle(AppTab.continuity.title)
            }
            .tabItem { AppTab.continuity.label }
            .tag(AppTab.continuity)

            NavigationStack {
                SettingsFeatureView(
                    contextCardStore: dependencies.contextCardStore,
                    apiKeyStore: dependencies.apiKeyStore,
                    reflectionConfiguration: dependencies.reflectionConfiguration,
                    selectedContextCardID: $selectedContextCardID,
                    onConfigurationChanged: bootstrap
                )
                    .navigationTitle(AppTab.settings.title)
            }
            .tabItem { AppTab.settings.label }
            .tag(AppTab.settings)
        }
        .tint(ClaraDesign.memory)
    }

    private func currentContextCardTitle(dependencies: AppDependencies) -> String {
        if let selectedContextCardID,
           let card = try? dependencies.contextCardStore.get(id: selectedContextCardID) {
            return card.title
        }
        if let card = try? dependencies.contextCardStore.defaultCard() {
            return card.title
        }
        return "默认角色"
    }

    private func screenshotRecallPackage(dependencies: AppDependencies) -> some View {
        NavigationStack {
            if let line = try? dependencies.continuityStore.active(limit: 1).first {
                RecallPackageView(
                    line: line,
                    memoriaStore: dependencies.memoriaStore,
                    contextCardStore: dependencies.contextCardStore
                )
            } else {
                ContentUnavailableView("暂无共同线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
        }
    }

    private func bootstrap() {
        do {
            dependencies = try AppDependencies.live()
            if let dependencies {
                try AppStoreScreenshotFixtureSeeder.seedIfRequested(dependencies: dependencies)
            }
            if selectedContextCardID == nil {
                if !persistedContextCardID.isEmpty,
                   try dependencies?.contextCardStore.get(id: persistedContextCardID) != nil {
                    selectedContextCardID = persistedContextCardID
                } else {
                    selectedContextCardID = try dependencies?.contextCardStore.defaultCard().id
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func resetLocalDataAndBootstrap() {
        do {
            try AppDatabase.deleteDefaultDatabaseDirectory()
            try KeychainAPIKeyStore().delete(service: .modelProvider)
            try KeychainAPIKeyStore().delete(service: .deepSeek)
            ModelProviderConfigurationStore.reset()
            OrganizationEngineModeStore.save(.localRules)
            ExternalModelProcessingConsentStore.reset()
            persistedContextCardID = ""
            selectedContextCardID = nil
            dependencies = nil
            bootstrap()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }
}

#Preview {
    AppRootView()
}
