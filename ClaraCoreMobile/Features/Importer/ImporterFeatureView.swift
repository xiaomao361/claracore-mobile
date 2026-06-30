import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImporterFeatureView: View {
    let inboxStore: InboxStore
    let preparer: ImportSessionPreparer
    let reflectionRunner: ReflectionRunner
    let digestCommitter: DigestCommitter
    let reflectionConfiguration: ReflectionConfiguration
    let contextCardStore: ContextCardStore
    let importerRegistry: ConversationImporterRegistry
    @Binding var selectedContextCardID: String?
    let onShowMemories: () -> Void
    let onShowContinuity: () -> Void

    @State private var input = ""
    @State private var contextCards: [ContextCard] = []
    @State private var statusMessage: String?
    @State private var isImporting = false
    @State private var isFileImporterPresented = false
    @State private var progress: ReflectionProgress?
    @State private var lastCommitResult: DigestCommitResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入 AI 对话")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Text("粘贴链接、文本或选择文件后，会自动整理并写入记忆和共同线。")
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
                                Label("导入并整理", systemImage: "sparkles")
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

                if isImporting {
                    ImportProgressView(
                        title: progressTitle(for: progress),
                        detail: progressDetail(for: progress)
                    )
                }

                if let statusMessage {
                    ClaraCard(accent: isSuccessStatus(statusMessage) ? ClaraDesign.memory : ClaraDesign.danger) {
                        Text(statusMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(isSuccessStatus(statusMessage) ? ClaraDesign.memory : ClaraDesign.danger)
                    }
                }

                if let lastCommitResult {
                    ImportResultCard(
                        result: lastCommitResult,
                        onShowMemories: onShowMemories,
                        onShowContinuity: onShowContinuity
                    )
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
        guard reflectionConfiguration.mode == .deepSeek else {
            statusMessage = "请先到设置里保存并测试默认整理模型 Key。"
            return
        }

        isImporting = true
        progress = .preparing
        statusMessage = nil
        lastCommitResult = nil

        Task {
            var enqueuedItem: InboxItem?
            do {
                var capture = try await importerRegistry.importCapture(from: inputValue)
                capture.contextCardId = contextCardId
                if let existing = try inboxStore.existing(
                    contentHash: capture.contentHash,
                    sourceApp: capture.sourceApp,
                    sourceThreadId: capture.sourceThreadId
                ) {
                    await MainActor.run {
                        statusMessage = "已有相同导入：\(existing.id.prefix(8))，没有重复写入。"
                        isImporting = false
                        progress = nil
                    }
                    return
                }
                let item = try inboxStore.enqueue(capture)
                enqueuedItem = item

                await MainActor.run {
                    progress = .preparing
                    statusMessage = "正在准备整理..."
                }
                let prepared = try preparer.prepare(item: item)
                await MainActor.run {
                    progress = .segmenting(total: prepared.segments.count)
                    statusMessage = "已切分为 \(prepared.segments.count) 段，开始整理..."
                }
                let result = try await reflectionRunner.run(prepared: prepared) { progress in
                    Task { @MainActor in
                        self.progress = progress
                        self.statusMessage = statusTitle(for: progress)
                    }
                }
                let committed = try digestCommitter.commit(result.digest, contextCardId: result.session.contextCardId)
                try inboxStore.updateStatus(id: item.id, status: .committed)

                await MainActor.run {
                    input = ""
                    statusMessage = "已完成：写入 \(committed.memories.count) 条记忆，\(committed.continuityLines.count) 条共同线。"
                    lastCommitResult = committed
                    isImporting = false
                    progress = nil
                }
            } catch {
                if let enqueuedItem {
                    try? inboxStore.updateStatus(id: enqueuedItem.id, status: .discarded)
                }
                await MainActor.run {
                    statusMessage = "导入失败：\(ClaraErrorPresenter.message(for: error))"
                    isImporting = false
                    progress = nil
                }
            }
        }
    }

    private func statusTitle(for progress: ReflectionProgress) -> String {
        switch progress {
        case .preparing:
            "正在准备整理..."
        case let .segmenting(total):
            "已切分为 \(total) 段。"
        case let .reflectingSegment(current, total):
            "正在整理第 \(current)/\(total) 段。"
        case let .reconciling(total):
            "正在合并 \(total) 段整理结果。"
        case .ready:
            "整理完成，正在入库。"
        }
    }

    private func progressTitle(for progress: ReflectionProgress?) -> String {
        switch progress {
        case .preparing:
            "准备整理"
        case .segmenting:
            "切分内容"
        case .reflectingSegment:
            "模型整理"
        case .reconciling:
            "合并结果"
        case .ready:
            "写入记忆"
        case nil:
            "处理中"
        }
    }

    private func progressDetail(for progress: ReflectionProgress?) -> String {
        switch progress {
        case .preparing:
            "正在创建整理任务"
        case let .segmenting(total):
            "已生成 \(total) 个内容片段"
        case let .reflectingSegment(current, total):
            "正在处理第 \(current) / \(total) 段"
        case let .reconciling(total):
            "正在把 \(total) 段结果合成最终记忆和共同线"
        case .ready:
            "正在写入本机数据库"
        case nil:
            "正在更新状态"
        }
    }

    private func isSuccessStatus(_ value: String) -> Bool {
        value.hasPrefix("已完成") || value.hasPrefix("已有")
    }
}

private struct ImportResultCard: View {
    var result: DigestCommitResult
    var onShowMemories: () -> Void
    var onShowContinuity: () -> Void

    var body: some View {
        ClaraCard(accent: ClaraDesign.memory) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("本次整理结果", systemImage: "checkmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Spacer()
                    ClaraStatusPill(
                        title: "\(result.committedCount) 项",
                        color: ClaraDesign.memory,
                        systemImage: "tray.full"
                    )
                }

                if !result.memories.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("记忆")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ClaraDesign.inkMuted)
                        ForEach(result.memories.prefix(3)) { memory in
                            Label(memory.content, systemImage: "square.stack")
                                .font(.system(size: 14))
                                .foregroundStyle(ClaraDesign.ink)
                                .lineLimit(2)
                        }
                    }
                }

                if !result.continuityLines.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("共同线")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ClaraDesign.inkMuted)
                        ForEach(result.continuityLines.prefix(3)) { line in
                            Label(line.title, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.system(size: 14))
                                .foregroundStyle(ClaraDesign.ink)
                                .lineLimit(2)
                        }
                    }
                }

                HStack {
                    Button {
                        onShowMemories()
                    } label: {
                        Label("查看记忆", systemImage: "square.stack")
                    }
                    .disabled(result.memories.isEmpty)
                    .buttonStyle(ClaraSecondaryButtonStyle())

                    Button {
                        onShowContinuity()
                    } label: {
                        Label("查看共同线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .disabled(result.continuityLines.isEmpty)
                    .buttonStyle(ClaraSecondaryButtonStyle())
                }
            }
        }
    }
}

private struct ImportProgressView: View {
    var title: String
    var detail: String

    var body: some View {
        ClaraCard(accent: ClaraDesign.reflection) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(ClaraDesign.reflection)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ClaraDesign.ink)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }
            }
        }
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    let inboxStore = InboxStore(database: database)
    let sessionStore = ImportSessionStore(database: database)
    ImporterFeatureView(
        inboxStore: inboxStore,
        preparer: ImportSessionPreparer(
            inboxStore: inboxStore,
            sessionStore: sessionStore,
            segmenter: FixedSizeCaptureSegmenter()
        ),
        reflectionRunner: ReflectionRunner(
            sessionStore: sessionStore,
            reflectionService: RuleBasedReflectionService()
        ),
        digestCommitter: DigestCommitter(
            memoriaStore: MemoriaStore(database: database),
            continuityStore: ContinuityStore(database: database)
        ),
        reflectionConfiguration: ReflectionConfiguration(mode: .localPlaceholder),
        contextCardStore: ContextCardStore(database: database),
        importerRegistry: ConversationImporterRegistry.live(),
        selectedContextCardID: .constant(ContextCardStore.defaultCardID),
        onShowMemories: {},
        onShowContinuity: {}
    )
}
