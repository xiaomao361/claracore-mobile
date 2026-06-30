import SwiftUI

struct AppRootView: View {
    @State private var dependencies: AppDependencies?
    @State private var selectedContextCardID: String?
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
        TabView {
            NavigationStack {
                ImporterFeatureView(
                    inboxStore: dependencies.inboxStore,
                    preparer: dependencies.importSessionPreparer,
                    reflectionRunner: dependencies.reflectionRunner,
                    digestCommitter: dependencies.digestCommitter,
                    reflectionConfiguration: dependencies.reflectionConfiguration,
                    contextCardStore: dependencies.contextCardStore,
                    importerRegistry: dependencies.conversationImporterRegistry,
                    selectedContextCardID: $selectedContextCardID
                )
                .navigationTitle(AppTab.importer.title)
            }
            .tabItem { AppTab.importer.label }

            NavigationStack {
                MemoriaFeatureView(store: dependencies.memoriaStore)
                    .navigationTitle(AppTab.memoria.title)
            }
            .tabItem { AppTab.memoria.label }

            NavigationStack {
                ContinuityFeatureView(
                    store: dependencies.continuityStore,
                    memoriaStore: dependencies.memoriaStore,
                    contextCardStore: dependencies.contextCardStore
                )
                    .navigationTitle(AppTab.continuity.title)
            }
            .tabItem { AppTab.continuity.label }

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
        }
        .tint(ClaraDesign.memory)
    }

    private func bootstrap() {
        do {
            dependencies = try AppDependencies.live()
            if selectedContextCardID == nil {
                selectedContextCardID = try dependencies?.contextCardStore.defaultCard().id
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
