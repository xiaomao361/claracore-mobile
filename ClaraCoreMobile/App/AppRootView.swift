import SwiftUI

struct AppRootView: View {
    @AppStorage("activeContextCardID") private var persistedContextCardID = ""
    @State private var dependencies: AppDependencies?
    @State private var selectedContextCardID: String?
    @State private var selectedTab: AppTab = .importer
    @State private var focusedContinuityLineID: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let dependencies {
                tabShell(dependencies: dependencies)
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
    }

    private var startupView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage {
                    ContentUnavailableView("启动失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView()
                }
            }
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
                    }
                )
                .navigationTitle(AppTab.importer.title)
            }
            .tabItem { AppTab.importer.label }
            .tag(AppTab.importer)

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

    private func bootstrap() {
        do {
            dependencies = try AppDependencies.live()
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
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AppRootView()
}
