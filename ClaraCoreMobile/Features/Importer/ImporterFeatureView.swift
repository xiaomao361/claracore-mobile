import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImporterFeatureView: View {
    let inboxStore: InboxStore
    let contextCardStore: ContextCardStore
    let importerRegistry: ConversationImporterRegistry
    @Binding var selectedContextCardID: String?

    @State private var input = ""
    @State private var contextCards: [ContextCard] = []
    @State private var statusMessage: String?
    @State private var isImporting = false
    @State private var isFileImporterPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入 AI 对话")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Text("粘贴 AI 对话分享链接，或临时保存一段手动文本。")
                        .font(.system(size: 15))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }

                ClaraSectionLabel(title: "来源")

                ClaraCard(accent: importerMatch != nil ? ClaraDesign.memory : nil) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("角色卡", selection: selectedContextCardBinding) {
                            ForEach(contextCards) { card in
                                Text(card.title).tag(card.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(contextCards.isEmpty || isImporting)

                        TextEditor(text: $input)
                            .frame(minHeight: 160)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(ClaraDesign.ink)
                            .padding(8)
                            .background(ClaraDesign.surfaceMuted.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))

                        HStack {
                            Button {
                                importInput()
                            } label: {
                                Label("导入", systemImage: "square.and.arrow.down")
                            }
                            .disabled(trimmedInput.isEmpty || isImporting)
                            .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                            Button {
                                pasteFromClipboard()
                            } label: {
                                Label("粘贴", systemImage: "doc.on.clipboard")
                            }
                            .disabled(isImporting)
                            .buttonStyle(ClaraSecondaryButtonStyle())

                            Button {
                                isFileImporterPresented = true
                            } label: {
                                Label("文件", systemImage: "doc")
                            }
                            .disabled(isImporting)
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }
                    }
                }

                ClaraSectionLabel(title: "识别")

                ClaraCard {
                    VStack(spacing: 14) {
                        HStack {
                            Text("已支持的分享链接")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            ClaraStatusPill(
                                title: importerMatch?.preview.sourceApp ?? importerMatch?.preview.title ?? "待识别",
                                color: importerMatch != nil ? ClaraDesign.memory : ClaraDesign.inkMuted,
                                systemImage: importerMatch != nil ? "checkmark" : nil
                            )
                        }

                        Divider()
                            .background(ClaraDesign.hairline)

                        HStack {
                            Text("兜底方式")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            Text(importerMatch?.preview.detail ?? fallbackLabel)
                                .foregroundStyle(ClaraDesign.inkMuted)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if let statusMessage {
                    ClaraCard(accent: statusMessage.hasPrefix("已导入") || statusMessage.hasPrefix("已有") ? ClaraDesign.memory : ClaraDesign.danger) {
                        Text(statusMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(statusMessage.hasPrefix("已导入") || statusMessage.hasPrefix("已有") ? ClaraDesign.memory : ClaraDesign.danger)
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .claraKeyboardDismissable()
        .task {
            loadContextCards()
        }
        .overlay {
            if isImporting {
                ProgressView()
                    .tint(ClaraDesign.memory)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var importInputValue: ConversationImportInput {
        ConversationImportInput(rawValue: trimmedInput)
    }

    private var importerMatch: ConversationImporterMatch? {
        guard !trimmedInput.isEmpty else { return nil }
        return importerRegistry.match(for: importInputValue)
    }

    private var selectedContextCardBinding: Binding<String> {
        Binding(
            get: { selectedContextCardID ?? contextCards.first?.id ?? ContextCardStore.defaultCardID },
            set: { selectedContextCardID = $0 }
        )
    }

    private var fallbackLabel: String {
        switch importInputValue {
        case .text:
            "输入文本后可作为手动文本导入"
        case let .url(url):
            "\(url.host ?? "未知链接") 将进入通用链接导入"
        case let .file(url):
            "\(url.lastPathComponent) 将作为文本文件导入"
        }
    }

    private func pasteFromClipboard() {
        input = UIPasteboard.general.string ?? ""
    }

    private func loadContextCards() {
        do {
            _ = try contextCardStore.defaultCard()
            contextCards = try contextCardStore.list()
            if selectedContextCardID == nil {
                selectedContextCardID = contextCards.first?.id
            }
            statusMessage = nil
        } catch {
            statusMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func importInput() {
        let value = trimmedInput
        guard !value.isEmpty else { return }
        importCapture(from: ConversationImportInput(rawValue: value))
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            importCapture(from: .file(url))
        case let .failure(error):
            statusMessage = error.localizedDescription
        }
    }

    private func importCapture(from inputValue: ConversationImportInput) {
        let contextCardId = selectedContextCardID ?? contextCards.first?.id

        isImporting = true
        statusMessage = nil

        Task {
            do {
                var capture = try await importerRegistry.importCapture(from: inputValue)
                capture.contextCardId = contextCardId
                if let existing = try inboxStore.existing(
                    contentHash: capture.contentHash,
                    sourceApp: capture.sourceApp,
                    sourceThreadId: capture.sourceThreadId
                ) {
                    await MainActor.run {
                        statusMessage = "已有相同导入：\(existing.id.prefix(8))"
                        isImporting = false
                    }
                    return
                }
                let item = try inboxStore.enqueue(capture)

                await MainActor.run {
                    input = ""
                    statusMessage = "已导入收件箱：\(item.id.prefix(8))"
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    ImporterFeatureView(
        inboxStore: InboxStore(database: database),
        contextCardStore: ContextCardStore(database: database),
        importerRegistry: ConversationImporterRegistry.live(),
        selectedContextCardID: .constant(ContextCardStore.defaultCardID)
    )
}
