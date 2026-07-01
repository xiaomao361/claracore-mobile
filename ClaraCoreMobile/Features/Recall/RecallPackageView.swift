import SwiftUI
import UIKit

struct RecallPackageView: View {
    let line: ContinuityLine
    let memoriaStore: MemoriaStore
    let contextCardStore: ContextCardStore

    @Environment(\.dismiss) private var dismiss
    @State private var contextCard: ContextCard?
    @State private var candidateMemories: [Memory] = []
    @State private var selectedMemoryIDs: Set<String> = []
    @State private var request = RecallContextBuilder.defaultRequest
    @State private var copiedMessage: String?
    @State private var errorMessage: String?

    private let builder = RecallContextBuilder()

    var body: some View {
        List {
            Section("共同线") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(line.title)
                        .font(.headline)
                    if !line.completedMilestoneSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.journeyProgressTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(line.completedMilestoneSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(index + 1).")
                                        .foregroundStyle(.secondary)
                                    Text(step)
                                }
                            }
                        }
                    }
                    if let current = line.currentMilestone {
                        Label(current, systemImage: "flag.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    if let nextStep = line.nextStep, !nextStep.isEmpty {
                        Label(nextStep, systemImage: "arrow.turn.down.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("角色卡") {
                if let contextCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(contextCard.title)
                            .font(.headline)
                        Text(contextCard.agentProfile)
                        Text(contextCard.userProfile)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("正在载入默认角色卡。")
                        .foregroundStyle(.secondary)
                }
            }

            Section("相关事实记忆") {
                if candidateMemories.isEmpty {
                    Text("没有检索到相关事实记忆。仍可复制共同线给外部对话应用。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidateMemories) { memory in
                        Button {
                            toggle(memory)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedMemoryIDs.contains(memory.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMemoryIDs.contains(memory.id) ? .accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(memory.content)
                                        .foregroundStyle(.primary)
                                    if !memory.tags.isEmpty {
                                        Text(memory.tags.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Section("接下来怎么继续") {
                TextEditor(text: $request)
                    .frame(minHeight: 96)
            }

            Section {
                Button {
                    copyPackage()
                } label: {
                    Label("复制给外部应用", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(contextCard == nil)

                if let copiedMessage {
                    Text(copiedMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("复制上下文")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .task {
            loadContext()
        }
        .alert("回召错误", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectedMemories: [Memory] {
        candidateMemories.filter { selectedMemoryIDs.contains($0.id) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func loadRelatedMemories() {
        do {
            let lineMemories = try memoriaStore.related(toLineId: line.id, limit: 12)
            if lineMemories.isEmpty {
                let query = builder.query(for: line)
                candidateMemories = try memoriaStore.recall(query: query, limit: 12, contextCardId: line.contextCardId)
            } else {
                candidateMemories = lineMemories
            }
            selectedMemoryIDs = Set(candidateMemories.map(\.id))
            errorMessage = nil
        } catch {
            candidateMemories = []
            selectedMemoryIDs = []
            errorMessage = error.localizedDescription
        }
    }

    private func loadContext() {
        do {
            if let contextCardId = line.contextCardId, let scopedCard = try contextCardStore.get(id: contextCardId) {
                contextCard = scopedCard
            } else {
                contextCard = try contextCardStore.defaultCard()
            }
            loadRelatedMemories()
        } catch {
            contextCard = nil
            candidateMemories = []
            selectedMemoryIDs = []
            errorMessage = error.localizedDescription
        }
    }

    private func toggle(_ memory: Memory) {
        if selectedMemoryIDs.contains(memory.id) {
            selectedMemoryIDs.remove(memory.id)
        } else {
            selectedMemoryIDs.insert(memory.id)
        }
    }

    private func copyPackage() {
        guard let contextCard else { return }
        let package = builder.build(
            contextCard: contextCard,
            line: line,
            memories: selectedMemories,
            request: request
        )
        UIPasteboard.general.string = package.formattedText
        copiedMessage = "已复制。现在可以粘贴到外部对话应用。"
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    let line = try! ContinuityStore(database: database).create(
        title: "ClaraCore Mobile",
        lastPosition: "正在打通导入和整理。",
        nextStep: "复制上下文给外部对话应用。"
    )
    return NavigationStack {
        RecallPackageView(
            line: line,
            memoriaStore: MemoriaStore(database: database),
            contextCardStore: ContextCardStore(database: database)
        )
    }
}
