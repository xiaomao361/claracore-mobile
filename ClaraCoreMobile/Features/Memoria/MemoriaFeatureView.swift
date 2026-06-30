import SwiftUI

struct MemoriaFeatureView: View {
    let store: MemoriaStore

    @State private var query = ""
    @State private var results: [Memory] = []
    @State private var recent: [Memory] = []
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var editingMemory: Memory?
    @State private var kindFilter: MemoryKindFilter = .all
    @State private var sourceFilter: String = MemorySourceFilter.all
    @State private var onlyLinkedToLine = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClaraSectionLabel(title: "最近记忆")

                MemoryFilterBar(
                    kindFilter: $kindFilter,
                    sourceFilter: $sourceFilter,
                    onlyLinkedToLine: $onlyLinkedToLine,
                    availableSources: availableSources
                )

                if filteredRecent.isEmpty {
                    ClaraEmptyState(
                        title: recent.isEmpty ? "暂无记忆" : "没有匹配记忆",
                        message: recent.isEmpty ? "提交整理结果后，稳定事实会出现在这里。" : "调整筛选条件后再查看。",
                        systemImage: "square.stack",
                        accent: ClaraDesign.memory
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredRecent) { memory in
                            MemoryCard(
                                memory: memory,
                                onEdit: { editingMemory = memory },
                                onDelete: { deleteMemory(memory) }
                            )
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
        .task { loadRecent() }
        .onAppear {
            loadRecent()
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recall()
            }
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
            results = try store.recall(query: trimmed, limit: 20)
            statusMessage = results.isEmpty ? "没有找到匹配记忆。" : "找到 \(results.count) 条记忆。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecent() {
        do {
            recent = try store.recent(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateMemory(id: String, content: String, tags: [String], isPrivate: Bool) {
        do {
            try store.update(id: id, content: content, tags: tags, isPrivate: isPrivate)
            editingMemory = nil
            statusMessage = "记忆已更新。"
            loadRecent()
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
            VStack(alignment: .leading, spacing: 8) {
                Text(memory.content)
                    .font(.system(size: 16))
                    .foregroundStyle(ClaraDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ClaraStatusPill(title: memory.kindTitle, color: memory.kindAccent)

                    if let sourceAgent = memory.sourceAgent {
                        ClaraStatusPill(title: sourceAgent, color: ClaraDesign.inkMuted, systemImage: "doc.text")
                    }

                    if memory.contextCardId != nil {
                        ClaraStatusPill(title: "角色", color: ClaraDesign.continuity, systemImage: "person.text.rectangle")
                    }

                    if memory.lineId != nil {
                        ClaraStatusPill(title: "共同线", color: ClaraDesign.continuity, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }

                if !memory.visibleTags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(memory.visibleTags.prefix(5), id: \.self) { tag in
                            ClaraStatusPill(title: tag, color: ClaraDesign.memory)
                        }
                    }
                }

                HStack {
                    Button {
                        onEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.memory))

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.danger))
                }
            }
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
                            Text(source).tag(source)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Toggle("共同线", isOn: $onlyLinkedToLine)
                        .toggleStyle(.button)
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
    MemoriaFeatureView(store: try! MemoriaStore(database: AppDatabase(path: ":memory:")))
}
