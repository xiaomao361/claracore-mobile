import SwiftUI
import UIKit

struct ArchiveFeatureView: View {
    let store: ImportSessionStore
    let contextCardId: String?
    let contextCardTitle: String

    @State private var query = ""
    @State private var sessions: [ArchivedImportSession] = []
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isLoading = false
    @State private var hasMore = true

    private let pageSize = 20

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    ClaraSectionLabel(title: "原始对话")
                    Spacer()
                    ClaraStatusPill(
                        title: contextCardTitle,
                        color: ClaraDesign.continuity,
                        systemImage: "person.text.rectangle"
                    )
                }

                ClaraCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            TextField("搜索原文、标题或来源", text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onSubmit { search() }
                        } icon: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ClaraDesign.inkMuted)
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(ClaraDesign.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(ClaraDesign.surfaceMuted.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))

                        HStack(spacing: 10) {
                            Button {
                                search()
                            } label: {
                                Label("搜索", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(ClaraSecondaryButtonStyle())

                            Button {
                                query = ""
                                loadArchive(reset: true)
                            } label: {
                                Label("最近", systemImage: "clock")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }
                    }
                }

                if sessions.isEmpty, !isLoading {
                    ClaraEmptyState(
                        title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无原文" : "没有匹配原文",
                        message: "导入并整理后的原始对话会保留在这里，方便回看和追溯。",
                        systemImage: "archivebox",
                        accent: ClaraDesign.reflection
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sessions) { item in
                            NavigationLink {
                                ArchiveDetailView(
                                    store: store,
                                    item: item,
                                    onDeleted: handleDeletedArchive
                                )
                            } label: {
                                ArchiveSessionCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hasMore || isLoading {
                        LoadMoreRow(
                            isLoading: isLoading,
                            title: hasMore ? "加载更多原文" : "正在加载原文..."
                        )
                        .onAppear {
                            loadMoreIfNeeded()
                        }
                    }
                }

                if let errorMessage {
                    ClaraActionStatus(message: errorMessage, tone: .error)
                }

                if let statusMessage {
                    ClaraActionStatus(message: statusMessage, tone: .success)
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .claraKeyboardDismissable()
        .task { loadArchive(reset: true) }
        .onChange(of: contextCardId) { _, _ in
            query = ""
            loadArchive(reset: true)
        }
    }

    private func loadArchive(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        do {
            let offset = reset ? 0 : sessions.count
            let page = try store.archive(limit: pageSize, offset: offset, contextCardId: contextCardId)
            if reset {
                sessions = page
            } else {
                appendUnique(page)
            }
            hasMore = page.count == pageSize
            errorMessage = nil
            if reset {
                statusMessage = nil
            }
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
        isLoading = false
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading else { return }
        loadArchive(reset: false)
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadArchive(reset: true)
            return
        }
        do {
            sessions = try store.searchArchive(query: trimmed, limit: pageSize, contextCardId: contextCardId)
            hasMore = false
            errorMessage = nil
            statusMessage = nil
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }

    private func appendUnique(_ page: [ArchivedImportSession]) {
        let existingIDs = Set(sessions.map(\.id))
        sessions.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
    }

    private func handleDeletedArchive(id: String) {
        sessions.removeAll { $0.id == id }
        statusMessage = "原文 Archive 已删除。已写入的记忆和共同线不会被同时删除。"
        errorMessage = nil
    }
}

private struct ArchiveSessionCard: View {
    var item: ArchivedImportSession

    var body: some View {
        ClaraCard(accent: ClaraDesign.reflection) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.session.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ClaraDesign.ink)
                            .lineLimit(2)

                        Text(item.preview)
                            .font(.system(size: 14))
                            .foregroundStyle(ClaraDesign.inkMuted)
                            .lineLimit(3)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ClaraDesign.inkMuted)
                        .padding(.top, 3)
                }

                ArchivePillRow(item: item)
            }
        }
    }
}

private struct ArchiveDetailView: View {
    let store: ImportSessionStore
    var item: ArchivedImportSession
    var onDeleted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClaraCard(accent: ClaraDesign.reflection) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.session.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ClaraDesign.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        ArchivePillRow(item: item)

                        if let sourceThreadId = item.session.sourceThreadId {
                            Divider()
                                .background(ClaraDesign.hairline)

                            Label(sourceThreadId, systemImage: "link")
                                .font(.system(size: 13))
                                .foregroundStyle(ClaraDesign.inkMuted)
                                .textSelection(.enabled)
                        }
                    }
                }

                ClaraSectionLabel(title: "处理结果")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ArchiveMetricRow(
                            title: "分段",
                            value: "\(item.segmentCount)",
                            systemImage: "square.split.2x1"
                        )
                        ArchiveMetricRow(
                            title: "写入记忆",
                            value: "\(item.committedMemoryIds.count)",
                            systemImage: "square.stack"
                        )
                        ArchiveMetricRow(
                            title: "更新共同线",
                            value: "\(item.committedLineIds.count)",
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                }

                ClaraSectionLabel(title: "原文")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = item.rawContent
                                statusMessage = "原文已复制。"
                            } label: {
                                Label("复制原文", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClaraSecondaryButtonStyle())

                            ShareLink(item: item.rawContent) {
                                Label("分享", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClaraSecondaryButtonStyle())
                        }
                        .disabled(item.rawContent.isEmpty)

                        Divider()
                            .background(ClaraDesign.hairline)

                        Button(role: .destructive) {
                            isDeleteConfirmationPresented = true
                        } label: {
                            Label("删除原文 Archive", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.danger))

                        Text(item.rawContent.isEmpty ? "没有保存到原文；可从分段记录追溯处理内容。" : item.rawContent)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(item.rawContent.isEmpty ? ClaraDesign.inkMuted : ClaraDesign.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let statusMessage {
                    ClaraActionStatus(message: statusMessage, tone: .success)
                }

                if let errorMessage {
                    ClaraActionStatus(message: errorMessage, tone: .error)
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .navigationTitle("原文详情")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除原文 Archive？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("删除原文 Archive", role: .destructive) {
                deleteArchive()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除本次导入保存的原文、分段和导入记录。已经写入的记忆和共同线不会被同时删除。")
        }
    }

    private func deleteArchive() {
        do {
            try store.deleteArchivedSession(id: item.id)
            onDeleted(item.id)
            dismiss()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }
}

private struct ArchivePillRow: View {
    var item: ArchivedImportSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ClaraStatusPill(
                title: item.session.sourceApp ?? sourceTitle(item.session.source),
                color: ClaraDesign.reflection,
                systemImage: sourceImage(item.session.source)
            )
            ClaraStatusPill(
                title: statusTitle(item.session.status),
                color: statusColor(item.session.status),
                systemImage: "checkmark.circle"
            )
            ClaraStatusPill(
                title: item.session.createdAt.formatted(date: .abbreviated, time: .shortened),
                color: ClaraDesign.inkMuted,
                systemImage: "calendar"
            )
        }
    }

    private func sourceTitle(_ source: RawCapture.Source) -> String {
        switch source {
        case .manual:
            "手动"
        case .clipboard:
            "剪贴板"
        case .share:
            "分享"
        case .file:
            "文件"
        case .url:
            "链接"
        }
    }

    private func sourceImage(_ source: RawCapture.Source) -> String {
        switch source {
        case .manual:
            "keyboard"
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

    private func statusTitle(_ status: ImportSession.Status) -> String {
        switch status {
        case .importing:
            "导入中"
        case .segmenting:
            "已分段"
        case .reflecting:
            "整理中"
        case .digested:
            "已整理"
        case .committed:
            "已提交"
        case .failed:
            "失败"
        }
    }

    private func statusColor(_ status: ImportSession.Status) -> Color {
        switch status {
        case .failed:
            ClaraDesign.danger
        case .digested, .committed:
            ClaraDesign.memory
        default:
            ClaraDesign.inkMuted
        }
    }
}

private struct ArchiveMetricRow: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(ClaraDesign.reflection)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(ClaraDesign.ink)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ClaraDesign.ink)
        }
    }
}

#Preview {
    let database = try! AppDatabase(path: FileManager.default.temporaryDirectory.appendingPathComponent("archive-preview.sqlite").path)
    let store = ImportSessionStore(database: database)
    return NavigationStack {
        ArchiveFeatureView(
            store: store,
            contextCardId: ContextCardStore.defaultCardID,
            contextCardTitle: "默认角色"
        )
    }
}
