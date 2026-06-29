import SwiftUI

struct InboxFeatureView: View {
    let store: InboxStore
    let preparer: ImportSessionPreparer
    let reflectionRunner: ReflectionRunner
    let digestCommitter: DigestCommitter
    let reflectionConfiguration: ReflectionConfiguration

    @State private var items: [InboxItem] = []
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isOrganizing = false
    @State private var selectedResult: InboxReviewResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    ClaraStatusPill(title: "\(items.count) 条待处理", color: items.isEmpty ? ClaraDesign.inkMuted : ClaraDesign.review, systemImage: "tray")
                    Spacer()
                    if isOrganizing {
                        ClaraStatusPill(title: "解析中", color: ClaraDesign.reflection, systemImage: "sparkles")
                    } else {
                        Button {
                            reload()
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(ClaraCompactButtonStyle())
                    }
                }

                if items.isEmpty {
                    ClaraEmptyState(
                        title: "暂无待处理导入",
                        message: "从 DeepSeek 分享链接或手动文本导入后，需要整理的内容会先停在这里。",
                        systemImage: "tray",
                        accent: ClaraDesign.memory
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            ClaraCard(accent: accent(for: item)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label(sourceTitle(for: item), systemImage: sourceIcon(for: item))
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(ClaraDesign.ink)

                                        Spacer()

                                        Text(item.createdAt, style: .date)
                                            .font(.system(size: 13))
                                            .foregroundStyle(ClaraDesign.inkMuted)
                                    }

                                    Text(summary(for: item))
                                        .font(.system(size: 16))
                                        .foregroundStyle(ClaraDesign.ink)
                                        .lineLimit(4)

                                    HStack {
                                        ClaraStatusPill(title: statusTitle(for: item), color: accent(for: item))
                                        if let sourceThreadId = item.sourceThreadId {
                                            ClaraStatusPill(title: sourceThreadId, color: ClaraDesign.inkMuted, systemImage: "link")
                                        }
                                        ClaraStatusPill(title: String(item.contentHash.prefix(10)), color: ClaraDesign.inkMuted)
                                    }

                                    Button {
                                        organize(item)
                                    } label: {
                                        Label("整理", systemImage: "sparkles")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.review))
                                    .disabled(isOrganizing)
                                }
                            }
                            .contextMenu {
                                Button {
                                    organize(item)
                                } label: {
                                    Label("整理", systemImage: "sparkles")
                                }

                                Button(role: .destructive) {
                                    discard(item)
                                } label: {
                                    Label("丢弃", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .safeAreaInset(edge: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(ClaraDesign.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(ClaraDesign.surface)
            }
        }
        .task {
            reload()
        }
        .sheet(item: $selectedResult) { result in
            NavigationStack {
                ReviewDigestView(
                    result: result.reflectionResult,
                    committer: digestCommitter,
                    onCommit: { committed in
                        markCommitted(item: result.item, committed: committed)
                    }
                )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") {
                                selectedResult = nil
                            }
                        }
                    }
            }
        }
        .alert("收件箱错误", isPresented: errorBinding) {
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

    private func reload() {
        do {
            items = try store.pending()
            errorMessage = nil
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func discard(_ item: InboxItem) {
        do {
            try store.updateStatus(id: item.id, status: .discarded)
            statusMessage = "已丢弃：\(item.id.prefix(8))"
            reload()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func organize(_ item: InboxItem) {
        guard !isOrganizing else { return }
        guard reflectionConfiguration.mode == .deepSeek else {
            let message = "当前还没有启用 DeepSeek。请先到设置里保存并测试 DeepSeek Key，然后再整理收件箱内容。"
            errorMessage = message
            statusMessage = "整理未开始：\(message)"
            return
        }

        isOrganizing = true
        statusMessage = "正在整理「\(sourceTitle(for: item))」..."

        Task {
            do {
                let prepared = try preparer.prepare(item: item)
                let result = try await reflectionRunner.run(prepared: prepared) { progress in
                    Task { @MainActor in
                        statusMessage = statusTitle(for: progress, source: sourceTitle(for: item))
                    }
                }

                await MainActor.run {
                    selectedResult = InboxReviewResult(item: item, reflectionResult: result)
                    statusMessage = "已整理「\(result.session.title)」"
                    isOrganizing = false
                    reload()
                }
            } catch {
                await MainActor.run {
                    let message = ClaraErrorPresenter.message(for: error)
                    errorMessage = message
                    statusMessage = "整理失败：\(message)"
                    isOrganizing = false
                }
            }
        }
    }

    private func markCommitted(item: InboxItem, committed: DigestCommitResult) {
        do {
            try store.updateStatus(id: item.id, status: .committed)
            statusMessage = "已提交 \(committed.committedCount) 项，并从收件箱移除"
            reload()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func sourceTitle(for item: InboxItem) -> String {
        item.sourceApp ?? sourceName(for: item.source)
    }

    private func sourceIcon(for item: InboxItem) -> String {
        switch item.source {
        case .manual:
            "square.and.pencil"
        case .clipboard:
            "doc.on.clipboard"
        case .share:
            "square.and.arrow.down"
        case .file:
            "doc"
        case .url:
            "link"
        }
    }

    private func accent(for item: InboxItem) -> Color {
        switch item.status {
        case .pending:
            ClaraDesign.review
        case .reviewed:
            ClaraDesign.reflection
        case .committed:
            ClaraDesign.memory
        case .discarded:
            ClaraDesign.danger
        }
    }

    private func statusTitle(for item: InboxItem) -> String {
        switch item.status {
        case .pending:
            "待解析"
        case .reviewed:
            "待确认"
        case .committed:
            "已整理"
        case .discarded:
            "已忽略"
        }
    }

    private func statusTitle(for progress: ReflectionProgress, source: String) -> String {
        switch progress {
        case let .reflectingSegment(current, total):
            "正在整理「\(source)」第 \(current)/\(total) 段"
        case let .reconciling(total):
            "正在合并 \(total) 段整理结果"
        }
    }

    private func summary(for item: InboxItem) -> String {
        item.rawContent
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? item.rawContent
    }

    private func sourceName(for source: RawCapture.Source) -> String {
        switch source {
        case .manual:
            "手动文本"
        case .clipboard:
            "剪贴板"
        case .share:
            "系统分享"
        case .file:
            "文件"
        case .url:
            "链接"
        }
    }
}

private struct InboxReviewResult: Identifiable {
    var item: InboxItem
    var reflectionResult: ReflectionRunResult

    var id: String {
        reflectionResult.id
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    let inboxStore = InboxStore(database: database)
    let sessionStore = ImportSessionStore(database: database)
    return InboxFeatureView(
        store: inboxStore,
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
        reflectionConfiguration: ReflectionConfiguration(mode: .localPlaceholder)
    )
}
