import SwiftUI

struct MemoriaFeatureView: View {
    let store: MemoriaStore
    let contextCardId: String?
    let contextCardTitle: String

    @State private var query = ""
    @State private var results: [Memory] = []
    @State private var recent: [Memory] = []
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var editingMemory: Memory?
    @State private var kindFilter: MemoryKindFilter = .all
    @State private var sourceFilter: String = MemorySourceFilter.all
    @State private var onlyLinkedToLine = false
    @State private var isLoadingRecent = false
    @State private var hasMoreRecent = true

    private let pageSize = 20

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    ClaraSectionLabel(title: "最近记忆")
                    Spacer()
                    ClaraStatusPill(
                        title: contextCardTitle,
                        color: ClaraDesign.continuity,
                        systemImage: "person.text.rectangle"
                    )
                }

                MemoryFilterBar(
                    kindFilter: $kindFilter,
                    sourceFilter: $sourceFilter,
                    onlyLinkedToLine: $onlyLinkedToLine,
                    availableSources: availableSources
                )

                if filteredRecent.isEmpty {
                    ClaraEmptyState(
                        title: recent.isEmpty ? "暂无记忆" : "没有匹配记忆",
                        message: recent.isEmpty ? "当前角色还没有稳定事实。提交整理结果后会出现在这里。" : "调整筛选条件后再查看。",
                        systemImage: "square.stack",
                        accent: ClaraDesign.memory
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredRecent) { memory in
                            MemoryCard(
                                memory: memory,
                                onEdit: { editingMemory = memory },
                                onDelete: { deleteMemory(memory) }
                            )
                        }
                    }

                    if hasMoreRecent || isLoadingRecent {
                        LoadMoreRow(
                            isLoading: isLoadingRecent,
                            title: hasMoreRecent ? "加载更多记忆" : "正在加载记忆..."
                        )
                        .onAppear {
                            loadMoreRecentIfNeeded()
                        }
                    }
                }

                ClaraSectionLabel(title: "检索")

                ClaraCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("搜索记忆", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { recall() }
                            .textFieldStyle(.roundedBorder)

                        Button {
                            recall()
                        } label: {
                            Label("搜索", systemImage: "magnifyingglass")
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(ClaraSecondaryButtonStyle())

                        ForEach(results) { memory in
                            if memory.matches(kindFilter: kindFilter, sourceFilter: sourceFilter, onlyLinkedToLine: onlyLinkedToLine) {
                                MemoryCard(
                                    memory: memory,
                                    onEdit: { editingMemory = memory },
                                    onDelete: { deleteMemory(memory) }
                                )
                            }
                        }
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
        .claraKeyboardDismissable()
        .task { loadRecent(reset: true) }
        .onAppear {
            loadRecent(reset: true)
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recall()
            }
        }
        .onChange(of: contextCardId) { _, _ in
            results = []
            loadRecent(reset: true)
        }
        .sheet(item: $editingMemory) { memory in
            NavigationStack {
                MemoryEditView(memory: memory) { content, tags, isPrivate in
                    updateMemory(id: memory.id, content: content, tags: tags, isPrivate: isPrivate)
                }
            }
        }
    }

    private var filteredRecent: [Memory] {
        recent.filter { $0.matches(kindFilter: kindFilter, sourceFilter: sourceFilter, onlyLinkedToLine: onlyLinkedToLine) }
    }

    private var availableSources: [String] {
        Array(Set((recent + results).compactMap(\.sourceAgent))).sorted()
    }

    private func recall() {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            results = try store.recall(query: trimmed, limit: pageSize, contextCardId: contextCardId)
            statusMessage = results.isEmpty ? "没有找到匹配记忆。" : "找到 \(results.count) 条记忆。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecent(reset: Bool) {
        guard !isLoadingRecent else { return }
        isLoadingRecent = true
        do {
            let offset = reset ? 0 : recent.count
            let page = try store.recent(limit: pageSize, offset: offset, contextCardId: contextCardId)
            if reset {
                recent = page
            } else {
                appendUniqueRecent(page)
            }
            hasMoreRecent = page.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingRecent = false
    }

    private func loadMoreRecentIfNeeded() {
        guard hasMoreRecent, !isLoadingRecent else { return }
        loadRecent(reset: false)
    }

    private func appendUniqueRecent(_ page: [Memory]) {
        let existingIDs = Set(recent.map(\.id))
        recent.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
    }

    private func updateMemory(id: String, content: String, tags: [String], isPrivate: Bool) {
        do {
            try store.update(id: id, content: content, tags: tags, isPrivate: isPrivate)
            editingMemory = nil
            statusMessage = "记忆已更新。"
            loadRecent(reset: true)
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recall()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMemory(_ memory: Memory) {
        do {
            try store.delete(id: memory.id)
            recent.removeAll { $0.id == memory.id }
            results.removeAll { $0.id == memory.id }
            statusMessage = "记忆已删除。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemoryCard: View {
    var memory: Memory
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ClaraCard(accent: ClaraDesign.memory) {
            VStack(alignment: .leading, spacing: 12) {
                Text(memory.content)
                    .font(.system(size: 16))
                    .foregroundStyle(ClaraDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)

                MemoryPillRow(items: memory.metaPills)

                if !memory.visibleTags.isEmpty {
                    MemoryPillRow(items: memory.visibleTags.prefix(6).map {
                        MemoryPillItem(title: $0, color: ClaraDesign.memory, systemImage: nil)
                    })
                }

                HStack(spacing: 10) {
                    Button {
                        onEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.memory))

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.danger))
                }
            }
        }
    }
}

private struct MemoryPillItem: Identifiable {
    var id: String { "\(title)-\(systemImage ?? "dot")" }
    var title: String
    var color: Color
    var systemImage: String?
}

private struct MemoryPillRow: View {
    var items: [MemoryPillItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    ClaraStatusPill(
                        title: item.title,
                        color: item.color,
                        systemImage: item.systemImage
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.trailing, 2)
        }
    }
}

private enum MemoryKindFilter: String, CaseIterable, Identifiable {
    case all
    case fact
    case preference
    case decision
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .fact:
            return "事实"
        case .preference:
            return "偏好"
        case .decision:
            return "决定"
        case .task:
            return "任务"
        }
    }
}

private enum MemorySourceFilter {
    static let all = "全部来源"
}

private struct MemoryFilterBar: View {
    @Binding var kindFilter: MemoryKindFilter
    @Binding var sourceFilter: String
    @Binding var onlyLinkedToLine: Bool
    var availableSources: [String]

    var body: some View {
        ClaraCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("类型", selection: $kindFilter) {
                    ForEach(MemoryKindFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Picker("来源", selection: $sourceFilter) {
                        Text(MemorySourceFilter.all).tag(MemorySourceFilter.all)
                        ForEach(availableSources, id: \.self) { source in
                            Text(source.displaySourceAgent).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 15, weight: .medium))

                    Spacer()

                    Button {
                        onlyLinkedToLine.toggle()
                    } label: {
                        Label("共同线", systemImage: onlyLinkedToLine ? "checkmark.circle.fill" : "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: onlyLinkedToLine ? ClaraDesign.continuity : ClaraDesign.inkMuted))
                }
            }
        }
    }
}

private extension Memory {
    var kindTitle: String {
        if tags.contains("preference") {
            return "偏好"
        }
        if tags.contains("decision") {
            return "决定"
        }
        if tags.contains("task") {
            return "任务"
        }
        return "事实"
    }

    var kindAccent: Color {
        if tags.contains("preference") {
            return ClaraDesign.continuity
        }
        if tags.contains("decision") {
            return ClaraDesign.review
        }
        if tags.contains("task") {
            return ClaraDesign.reflection
        }
        return ClaraDesign.memory
    }

    var visibleTags: [String] {
        tags.filter { !["fact", "preference", "decision", "task", "mobile"].contains($0) }
    }

    var metaPills: [MemoryPillItem] {
        var items = [
            MemoryPillItem(title: kindTitle, color: kindAccent, systemImage: nil)
        ]
        if let sourceAgent {
            items.append(MemoryPillItem(title: sourceAgent.displaySourceAgent, color: ClaraDesign.inkMuted, systemImage: "doc.text"))
        }
        items.append(MemoryPillItem(title: "可信 \(Int(memoryConfidencePercent))%", color: ClaraDesign.inkMuted, systemImage: "checkmark.seal"))
        if importance > 0 {
            items.append(MemoryPillItem(title: "重要 \(Int(memoryImportancePercent))%", color: ClaraDesign.review, systemImage: "star"))
        }
        if contextCardId != nil {
            items.append(MemoryPillItem(title: "角色", color: ClaraDesign.continuity, systemImage: "person.text.rectangle"))
        }
        if lineId != nil {
            items.append(MemoryPillItem(title: "共同线", color: ClaraDesign.continuity, systemImage: "point.topleft.down.curvedto.point.bottomright.up"))
        }
        return items
    }

    var memoryConfidencePercent: Double {
        min(max(confidence, 0), 1) * 100
    }

    var memoryImportancePercent: Double {
        min(max(importance, 0), 1) * 100
    }

    func matches(kindFilter: MemoryKindFilter, sourceFilter: String, onlyLinkedToLine: Bool) -> Bool {
        if kindFilter != .all, !tags.contains(kindFilter.rawValue) {
            return false
        }
        if sourceFilter != MemorySourceFilter.all, sourceAgent != sourceFilter {
            return false
        }
        if onlyLinkedToLine, lineId == nil {
            return false
        }
        return true
    }
}

private extension String {
    var displaySourceAgent: String {
        switch self {
        case "mobile-reflection":
            return "整理"
        case "mobile":
            return "本机"
        default:
            return self
        }
    }
}

private struct MemoryEditView: View {
    var memory: Memory
    var onSave: (String, [String], Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var tagsText: String
    @State private var isPrivate: Bool

    init(memory: Memory, onSave: @escaping (String, [String], Bool) -> Void) {
        self.memory = memory
        self.onSave = onSave
        _content = State(initialValue: memory.content)
        _tagsText = State(initialValue: memory.tags.joined(separator: ", "))
        _isPrivate = State(initialValue: memory.isPrivate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ClaraSectionLabel(title: "事实内容")
                ClaraCard(accent: ClaraDesign.memory) {
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(ClaraDesign.ink)
                        .padding(8)
                        .background(ClaraDesign.surfaceMuted.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))
                }

                ClaraSectionLabel(title: "标签")
                ClaraCard {
                    TextField("用逗号分隔", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                ClaraCard {
                    Toggle("私密记忆", isOn: $isPrivate)
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .claraKeyboardDismissable()
        .navigationTitle("编辑记忆")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(trimmedContent, parsedTags, isPrivate)
                }
                .disabled(trimmedContent.isEmpty)
            }
        }
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    MemoriaFeatureView(
        store: try! MemoriaStore(database: AppDatabase(path: ":memory:")),
        contextCardId: ContextCardStore.defaultCardID,
        contextCardTitle: "默认角色卡"
    )
}
