import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImporterFeatureView: View {
    @AppStorage(ExternalModelProcessingConsentStore.userDefaultsKey) private var hasAcceptedThirdPartyAIProcessing = false

    let inboxStore: InboxStore
    let preparer: ImportSessionPreparer
    let reflectionRunner: ReflectionRunner
    let digestCommitter: DigestCommitter
    let reflectionConfiguration: ReflectionConfiguration
    let contextCardStore: ContextCardStore
    let continuityStore: ContinuityStore
    let importerRegistry: ConversationImporterRegistry
    @Binding var selectedContextCardID: String?
    let onShowMemories: () -> Void
    let onShowContinuity: (String?) -> Void

    @State private var input = ""
    @State private var contextCards: [ContextCard] = []
    @State private var activeLines: [ContinuityLine] = []
    @State private var selectedTargetLineID = ImportTargetLine.newLineID
    @State private var statusMessage: String?
    @State private var isImporting = false
    @State private var isFileImporterPresented = false
    @State private var progress: ReflectionProgress?
    @State private var lastCommitResult: DigestCommitResult?
    @State private var duplicateResult: DuplicateImportResult?
    @State private var duplicateImportInput: ConversationImportInput?
    @State private var isSourceExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("粘贴链接、文本或选择文件后，会自动整理并写入记忆和共同线。")
                        .font(.system(size: 15))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }

                if let lastCommitResult, !isSourceExpanded, !isImporting {
                    ImportResultCard(
                        result: lastCommitResult,
                        onNewImport: beginNewImport,
                        onShowMemories: onShowMemories,
                        onShowContinuity: onShowContinuity
                    )
                }

                if let duplicateResult, !isImporting {
                    DuplicateImportCard(
                        result: duplicateResult,
                        onShowMemories: onShowMemories,
                        onShowContinuity: onShowContinuity,
                        onRetry: retryDuplicateImport,
                        onNewImport: beginNewImport
                    )
                }

                if isSourceExpanded || (lastCommitResult == nil && duplicateResult == nil) || isImporting {
                    ClaraSectionLabel(title: "来源")

                    ClaraCard(accent: importerMatch != nil ? ClaraDesign.memory : nil) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("导入到")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ClaraDesign.inkMuted)
                                Spacer()
                                ClaraStatusPill(
                                    title: currentContextCardTitle,
                                    color: ClaraDesign.continuity,
                                    systemImage: "person.text.rectangle"
                                )
                            }

                            Picker("角色卡", selection: selectedContextCardBinding) {
                                ForEach(contextCards) { card in
                                    Text(card.title).tag(card.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(contextCards.isEmpty || isImporting)

                            ImportDestinationSelector(
                                activeLines: activeLines,
                                selectedTargetLineID: $selectedTargetLineID,
                                isDisabled: isImporting
                            )

                            TextEditor(text: $input)
                                .frame(minHeight: 128)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(ClaraDesign.ink)
                                .padding(8)
                                .background(ClaraDesign.surfaceMuted.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))

                            ImportEngineStatusRow(status: organizationEngineStatus)

                            VStack(spacing: 10) {
                                Button {
                                    importInput()
                                } label: {
                                    Label("导入并整理", systemImage: "sparkles")
                                        .frame(maxWidth: .infinity)
                                }
                                .disabled(trimmedInput.isEmpty || isImporting)
                                .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                                HStack(spacing: 10) {
                                    Button {
                                        pasteFromClipboard()
                                    } label: {
                                        Label("粘贴", systemImage: "doc.on.clipboard")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(isImporting)
                                    .buttonStyle(ClaraSecondaryButtonStyle())

                                    Button {
                                        isFileImporterPresented = true
                                    } label: {
                                        Label("文件", systemImage: "doc")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(isImporting)
                                    .buttonStyle(ClaraSecondaryButtonStyle())
                                }
                            }
                        }
                    }

                    if !trimmedInput.isEmpty || isImporting {
                        ClaraSectionLabel(title: "识别")

                        ClaraCard {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("来源格式")
                                        .foregroundStyle(ClaraDesign.ink)
                                    Spacer()
                                    ClaraStatusPill(
                                        title: importerMatch?.preview.sourceApp ?? importerMatch?.preview.title ?? "通用导入",
                                        color: importerMatch != nil ? ClaraDesign.memory : ClaraDesign.inkMuted,
                                        systemImage: importerMatch != nil ? "checkmark" : nil
                                    )
                                }

                                Divider()
                                    .background(ClaraDesign.hairline)

                                HStack(alignment: .firstTextBaseline) {
                                    Text("处理方式")
                                        .foregroundStyle(ClaraDesign.ink)
                                    Spacer()
                                    Text(importerMatch?.preview.detail ?? fallbackLabel)
                                        .foregroundStyle(ClaraDesign.inkMuted)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
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
                    ClaraActionStatus(
                        message: statusMessage,
                        tone: isSuccessStatus(statusMessage) ? .success : .error
                    )
                }

                if let lastCommitResult, isSourceExpanded || isImporting {
                    ImportResultCard(
                        result: lastCommitResult,
                        onNewImport: beginNewImport,
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
            loadActiveLines()
        }
        .onChange(of: selectedContextCardID) { _, _ in
            loadActiveLines()
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

    private var currentContextCardTitle: String {
        let currentId = selectedContextCardID ?? contextCards.first?.id
        guard let currentId, let card = contextCards.first(where: { $0.id == currentId }) else {
            return "默认角色"
        }
        return card.title
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

    private var organizationEngineStatus: OrganizationEngineStatus {
        OrganizationEngineStatus(
            preferredMode: reflectionConfiguration.preferredEngineMode,
            effectiveMode: reflectionConfiguration.mode,
            hasSavedModelKey: reflectionConfiguration.hasSavedModelKey,
            hasAcceptedExternalProcessing: reflectionConfiguration.hasAcceptedExternalProcessing || hasAcceptedThirdPartyAIProcessing,
            modelProvider: reflectionConfiguration.modelProvider ?? .deepSeekDefault
        )
    }

    private func pasteFromClipboard() {
        input = UIPasteboard.general.string ?? ""
        isSourceExpanded = true
        lastCommitResult = nil
        duplicateResult = nil
        duplicateImportInput = nil
    }

    private func beginNewImport() {
        input = ""
        statusMessage = nil
        progress = nil
        lastCommitResult = nil
        duplicateResult = nil
        duplicateImportInput = nil
        isSourceExpanded = true
    }

    private func loadContextCards() {
        do {
            _ = try contextCardStore.defaultCard()
            contextCards = try contextCardStore.list()
            if selectedContextCardID == nil {
                selectedContextCardID = contextCards.first?.id
            }
            loadActiveLines()
            statusMessage = nil
        } catch {
            statusMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func loadActiveLines() {
        do {
            activeLines = try continuityStore.active(limit: 50, contextCardId: selectedContextCardID ?? contextCards.first?.id)
            if selectedTargetLineID != ImportTargetLine.newLineID,
               !activeLines.contains(where: { $0.id == selectedTargetLineID }) {
                selectedTargetLineID = ImportTargetLine.newLineID
            }
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

    private func importCapture(from inputValue: ConversationImportInput, allowDuplicate: Bool = false) {
        let contextCardId = selectedContextCardID ?? contextCards.first?.id
        let targetLineId = selectedTargetLineID == ImportTargetLine.newLineID ? nil : selectedTargetLineID
        if reflectionConfiguration.mode == .remoteModel, !hasAcceptedThirdPartyAIProcessing {
            statusMessage = "请先到设置里确认外部模型处理说明，再导入并整理。"
            return
        }

        isImporting = true
        progress = .preparing
        statusMessage = nil
        lastCommitResult = nil
        duplicateResult = nil
        duplicateImportInput = nil

        Task {
            var enqueuedItem: InboxItem?
            do {
                var capture = try await importerRegistry.importCapture(from: inputValue)
                capture.contextCardId = contextCardId
                if !allowDuplicate, let existing = try inboxStore.existing(
                    contentHash: capture.contentHash,
                    sourceApp: capture.sourceApp,
                    sourceThreadId: capture.sourceThreadId
                ) {
                    await MainActor.run {
                        duplicateResult = DuplicateImportResult(item: existing)
                        duplicateImportInput = inputValue
                        isSourceExpanded = false
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
                let committed = try digestCommitter.commit(
                    result.digest,
                    contextCardId: result.session.contextCardId,
                    targetLineId: targetLineId
                )
                try inboxStore.updateCommitResult(
                    id: item.id,
                    memoryIds: committed.memories.map(\.id),
                    lineIds: committed.continuityLines.map(\.id)
                )
                try inboxStore.updateStatus(id: item.id, status: .committed)

                await MainActor.run {
                    input = ""
                    statusMessage = nil
                    lastCommitResult = committed
                    loadActiveLines()
                    isSourceExpanded = false
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

    private func retryDuplicateImport() {
        if let duplicateImportInput {
            importCapture(from: duplicateImportInput, allowDuplicate: true)
            return
        }
        let value = trimmedInput
        guard !value.isEmpty else { return }
        importCapture(from: ConversationImportInput(rawValue: value), allowDuplicate: true)
    }

    private func statusTitle(for progress: ReflectionProgress) -> String {
        switch progress {
        case .preparing:
            "正在准备整理..."
        case let .segmenting(total):
            "已切分为 \(total) 段。"
        case let .reflectingSegment(current, total):
            reflectionConfiguration.mode == .remoteModel ? "正在用外部模型整理第 \(current)/\(total) 段。" : "正在用本机规则整理第 \(current)/\(total) 段。"
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
            reflectionConfiguration.mode == .remoteModel ? "正在处理第 \(current) / \(total) 段，内容会发送到已配置的模型提供方" : "正在处理第 \(current) / \(total) 段，内容保留在本机"
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

private enum ImportTargetLine {
    static let newLineID = "__new_line__"
}

private struct ImportEngineStatusRow: View {
    var status: OrganizationEngineStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.statusPillIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(status.isExternalModelEnabled ? ClaraDesign.memory : ClaraDesign.reflection)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("本次整理机制")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ClaraDesign.ink)
                    ClaraStatusPill(
                        title: status.isExternalModelEnabled ? "外部模型" : "本机规则",
                        color: status.isExternalModelEnabled ? ClaraDesign.memory : ClaraDesign.reflection,
                        systemImage: nil
                    )
                }

                Text(status.importSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(ClaraDesign.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if status.preferredMode == .externalModel, !status.isExternalModelEnabled {
                    Text(status.activationDecisionSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(ClaraDesign.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let unmetRequirementsSummary = status.unmetRequirementsSummary {
                        Text(unmetRequirementsSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ClaraDesign.reflection)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(ClaraDesign.surfaceMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
    }
}

private struct ImportDestinationSelector: View {
    var activeLines: [ContinuityLine]
    @Binding var selectedTargetLineID: String
    var isDisabled: Bool

    @State private var query = ""

    private var selectedLine: ContinuityLine? {
        activeLines.first { $0.id == selectedTargetLineID }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredLines: [ContinuityLine] {
        guard !trimmedQuery.isEmpty else {
            return activeLines
        }
        return activeLines.filter { line in
            line.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                line.lastPosition.localizedCaseInsensitiveContains(trimmedQuery) ||
                (line.nextStep?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }

    private var visibleLines: ArraySlice<ContinuityLine> {
        filteredLines.prefix(trimmedQuery.isEmpty ? 4 : 8)
    }

    private var overflowLines: ArraySlice<ContinuityLine> {
        trimmedQuery.isEmpty ? activeLines.dropFirst(4) : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("整理目标", systemImage: "arrow.triangle.merge")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ClaraDesign.inkMuted)
                Spacer()
                ClaraStatusPill(
                    title: selectedLine?.title ?? "新建共同线",
                    color: selectedLine == nil ? ClaraDesign.memory : ClaraDesign.continuity,
                    systemImage: selectedLine == nil ? "plus" : "point.topleft.down.curvedto.point.bottomright.up"
                )
            }

            Button {
                selectedTargetLineID = ImportTargetLine.newLineID
            } label: {
                ImportDestinationRow(
                    title: "新建共同线",
                    detail: "从这次导入开始一条新的继续点",
                    nextStep: nil,
                    systemImage: "plus.circle",
                    color: ClaraDesign.memory,
                    isSelected: selectedLine == nil
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            if !activeLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("接到已有线")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ClaraDesign.inkMuted)

                    if activeLines.count > 4 {
                        Label {
                            TextField("搜索共同线", text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .disabled(isDisabled)
                        } icon: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ClaraDesign.inkMuted)
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(ClaraDesign.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(ClaraDesign.surfaceMuted.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
                    }

                    ForEach(Array(visibleLines)) { line in
                        Button {
                            selectedTargetLineID = line.id
                        } label: {
                            ImportDestinationRow(
                                title: line.title,
                                detail: line.currentMilestone ?? line.lastPosition,
                                nextStep: line.nextStep,
                                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                                color: ClaraDesign.continuity,
                                isSelected: selectedTargetLineID == line.id
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                    }

                    if !trimmedQuery.isEmpty, visibleLines.isEmpty {
                        Text("没有匹配的共同线。")
                            .font(.system(size: 13))
                            .foregroundStyle(ClaraDesign.inkMuted)
                            .padding(.vertical, 4)
                    }

                    if !overflowLines.isEmpty {
                        Menu {
                            ForEach(Array(overflowLines)) { line in
                                Button(line.title) {
                                    selectedTargetLineID = line.id
                                }
                            }
                        } label: {
                            Label("更多共同线", systemImage: "ellipsis.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(ClaraDesign.continuity)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(ClaraDesign.continuity.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
                        }
                        .disabled(isDisabled)
                    }
                }
            }
        }
    }
}

private struct ImportDestinationRow: View {
    var title: String
    var detail: String
    var nextStep: String?
    var systemImage: String
    var color: Color
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSelected ? color : ClaraDesign.inkMuted)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ClaraDesign.ink)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(ClaraDesign.inkMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let nextStep, !nextStep.isEmpty {
                    Text("下一步：\(nextStep)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? color.opacity(0.10) : ClaraDesign.surfaceMuted.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous)
                .stroke(isSelected ? color.opacity(0.55) : ClaraDesign.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct DuplicateImportResult: Equatable {
    var itemId: String
    var sourceTitle: String
    var lineIds: [String]
    var memoryCount: Int
    var lineCount: Int
    var hasResolvableResult: Bool

    init(item: InboxItem) {
        itemId = item.id
        sourceTitle = item.sourceApp ?? item.metadata["title"] ?? item.source.rawValue
        let memoryIds = item.metadata["committed_memory_ids"]?
            .split(separator: ",")
            .map(String.init) ?? []
        let lineIds = item.metadata["committed_line_ids"]?
            .split(separator: ",")
            .map(String.init) ?? []
        self.lineIds = lineIds
        memoryCount = memoryIds.count
        lineCount = lineIds.count
        hasResolvableResult = !memoryIds.isEmpty || !lineIds.isEmpty
    }
}

private struct DuplicateImportCard: View {
    var result: DuplicateImportResult
    var onShowMemories: () -> Void
    var onShowContinuity: (String?) -> Void
    var onRetry: () -> Void
    var onNewImport: () -> Void

    var body: some View {
        ClaraCard(accent: ClaraDesign.continuity) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Label("已经导入过", systemImage: "checkmark.seal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Spacer()
                    ClaraStatusPill(
                        title: String(result.itemId.prefix(8)),
                        color: ClaraDesign.continuity,
                        systemImage: "tray.full"
                    )
                }

                Text("\(result.sourceTitle) 已经整理过，没有重复写入。")
                    .font(.system(size: 14))
                    .foregroundStyle(ClaraDesign.inkMuted)

                if result.hasResolvableResult {
                    HStack(spacing: 8) {
                        ClaraStatusPill(title: "记忆 \(result.memoryCount)", color: ClaraDesign.memory, systemImage: "square.stack")
                        ClaraStatusPill(title: "共同线 \(result.lineCount)", color: ClaraDesign.continuity, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                } else {
                    Text("这条旧记录没有保存结果索引，可以重新整理一次。")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }

                VStack(spacing: 10) {
                    if result.memoryCount > 0 {
                        Button {
                            onShowMemories()
                        } label: {
                            Label("查看记忆", systemImage: "square.stack")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaraSecondaryButtonStyle())
                    }

                    if result.lineCount > 0 {
                        Button {
                            onShowContinuity(result.lineIds.first)
                        } label: {
                            Label("查看共同线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaraSecondaryButtonStyle())
                    }

                    Button {
                        onRetry()
                    } label: {
                        Label("重新整理一次", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraSecondaryButtonStyle())

                    Button {
                        onNewImport()
                    } label: {
                        Label("继续导入", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraSecondaryButtonStyle())
                }
            }
        }
    }
}

private struct ImportResultCard: View {
    var result: DigestCommitResult
    var onNewImport: () -> Void
    var onShowMemories: () -> Void
    var onShowContinuity: (String?) -> Void

    var body: some View {
        ClaraCard(accent: ClaraDesign.memory) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Label(result.committedCount > 0 ? "整理完成" : "没有写入新内容", systemImage: result.committedCount > 0 ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        ClaraStatusPill(
                            title: "记忆 \(result.memories.count)",
                            color: result.memories.isEmpty ? ClaraDesign.inkMuted : ClaraDesign.memory,
                            systemImage: "square.stack"
                        )
                        ClaraStatusPill(
                            title: "共同线 \(result.continuityLines.count)",
                            color: result.continuityLines.isEmpty ? ClaraDesign.inkMuted : ClaraDesign.continuity,
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                }

                if result.committedCount == 0 {
                    Text("这次导入已处理，但没有形成新的记忆或共同线。可以换一段更完整的对话再试。")
                        .font(.system(size: 14))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }

                ResultPreviewSection(
                    title: "记忆",
                    emptyTitle: "没有新增记忆",
                    systemImage: "square.stack",
                    values: result.memories.prefix(3).map(\.content)
                )

                ResultPreviewSection(
                    title: "写入共同线",
                    emptyTitle: "没有写入共同线",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    values: result.continuityLines.prefix(3).map { line in
                        if let currentMilestone = line.currentMilestone {
                            return "\(line.title)：\(currentMilestone)"
                        }
                        return line.title
                    }
                )

                VStack(spacing: 10) {
                    if !result.memories.isEmpty {
                        Button {
                            onShowMemories()
                        } label: {
                            Label("查看记忆", systemImage: "square.stack")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaraSecondaryButtonStyle())
                    }

                    if !result.continuityLines.isEmpty {
                        Button {
                            onShowContinuity(result.continuityLines.first?.id)
                        } label: {
                            Label("查看共同线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaraSecondaryButtonStyle())
                    }

                    Button {
                        onNewImport()
                    } label: {
                        Label("继续导入", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraSecondaryButtonStyle())
                }
            }
        }
    }
}

private struct ResultPreviewSection: View {
    var title: String
    var emptyTitle: String
    var systemImage: String
    var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ClaraDesign.inkMuted)

            if values.isEmpty {
                Text(emptyTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(ClaraDesign.inkMuted)
            } else {
                ForEach(values, id: \.self) { value in
                    Label(value, systemImage: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(ClaraDesign.ink)
                        .lineLimit(2)
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
        reflectionConfiguration: ReflectionConfiguration(mode: .localPlaceholder, modelProvider: .deepSeekDefault),
        contextCardStore: ContextCardStore(database: database),
        continuityStore: ContinuityStore(database: database),
        importerRegistry: ConversationImporterRegistry.live(),
        selectedContextCardID: .constant(ContextCardStore.defaultCardID),
        onShowMemories: {},
        onShowContinuity: { _ in }
    )
}
