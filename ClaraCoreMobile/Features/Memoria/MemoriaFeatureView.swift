import SwiftUI

struct MemoriaFeatureView: View {
    let store: MemoriaStore

    @State private var content = ""
    @State private var query = ""
    @State private var results: [Memory] = []
    @State private var recent: [Memory] = []
    @State private var errorMessage: String?
    @State private var editingMemory: Memory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClaraSectionLabel(title: "最近记忆")

                if recent.isEmpty {
                    ClaraEmptyState(
                        title: "暂无记忆",
                        message: "提交整理结果或手动保存后，稳定事实会出现在这里。",
                        systemImage: "square.stack",
                        accent: ClaraDesign.memory
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(recent) { memory in
                            MemoryCard(
                                memory: memory,
                                onEdit: { editingMemory = memory },
                                onDelete: { deleteMemory(memory) }
                            )
                        }
                    }
                }

                ClaraSectionLabel(title: "写入")

                ClaraCard(accent: ClaraDesign.memory) {
                    VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)

                Button {
                    storeMemory()
                } label: {
                    Label("保存记忆", systemImage: "checkmark")
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    MemoryCard(
                        memory: memory,
                        onEdit: { editingMemory = memory },
                        onDelete: { deleteMemory(memory) }
                    )
                }
            }
                }

            if let errorMessage {
                    ClaraCard(accent: ClaraDesign.danger) {
                        Text(errorMessage)
                            .foregroundStyle(ClaraDesign.danger)
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .task { loadRecent() }
        .sheet(item: $editingMemory) { memory in
            NavigationStack {
                MemoryEditView(memory: memory) { content, tags, isPrivate in
                    updateMemory(id: memory.id, content: content, tags: tags, isPrivate: isPrivate)
                }
            }
        }
    }

    private func storeMemory() {
        do {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try store.store(content: trimmed, tags: ["mobile"], isPrivate: false)
            content = ""
            query = "mobile"
            loadRecent()
            recall()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recall() {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            results = try store.recall(query: trimmed, limit: 20)
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
                    if let sourceAgent = memory.sourceAgent {
                        ClaraStatusPill(title: sourceAgent, color: ClaraDesign.inkMuted, systemImage: "doc.text")
                    }

                    ForEach(memory.tags.prefix(3), id: \.self) { tag in
                        ClaraStatusPill(title: tag, color: ClaraDesign.memory)
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
