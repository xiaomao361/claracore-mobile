import SwiftUI

struct ContinuityFeatureView: View {
    let store: ContinuityStore
    let memoriaStore: MemoriaStore
    let contextCardStore: ContextCardStore

    @State private var lines: [ContinuityLine] = []
    @State private var contextCards: [String: ContextCard] = [:]
    @State private var selectedLine: ContinuityLine?
    @State private var editingLine: ContinuityLine?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    ClaraSectionLabel(title: "当前共同线")
                    Spacer()
                    Button {
                        reload()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.continuity))
                }

                if lines.isEmpty {
                    ClaraEmptyState(
                        title: "暂无共同线",
                        message: "整理导入内容后，可恢复的项目线索会出现在这里。",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        accent: ClaraDesign.continuity
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(lines) { line in
                            ClaraCard(accent: ClaraDesign.continuity) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(line.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(ClaraDesign.ink)
                                    ClaraStatusPill(
                                        title: roleTitle(for: line),
                                        color: ClaraDesign.continuity,
                                        systemImage: "person.text.rectangle"
                                    )
                                    HStack {
                                        Text(line.milestoneProgressTitle)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(ClaraDesign.inkMuted)
                                        Spacer()
                                        ClaraStatusPill(
                                            title: "第 \(line.milestoneSteps.count) 站",
                                            color: ClaraDesign.continuity,
                                            systemImage: "flag"
                                        )
                                    }
                                    MilestoneStepsView(steps: line.milestoneSteps, limit: 4)
                                    if let nextStep = line.nextStep, !nextStep.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("下一步")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(ClaraDesign.inkMuted)
                                            Label(nextStep, systemImage: "arrow.turn.down.right")
                                                .font(.system(size: 14))
                                                .foregroundStyle(ClaraDesign.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(ClaraDesign.surfaceMuted.opacity(0.55))
                                        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))
                                    }

                                    HStack {
                                        Button {
                                            selectedLine = line
                                        } label: {
                                            Label("复制回召包", systemImage: "doc.on.doc")
                                        }
                                        .buttonStyle(ClaraSecondaryButtonStyle())

                                        Button {
                                            editingLine = line
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        .buttonStyle(ClaraCompactButtonStyle(color: ClaraDesign.continuity))

                                        Button(role: .destructive) {
                                            delete(line)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedLine = line
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .task {
            reload()
        }
        .sheet(item: $selectedLine) { line in
            NavigationStack {
                RecallPackageView(
                    line: line,
                    memoriaStore: memoriaStore,
                    contextCardStore: contextCardStore
                )
            }
        }
        .sheet(item: $editingLine) { line in
            NavigationStack {
                ContinuityEditView(line: line) { title, lastPosition, nextStep in
                    update(line: line, title: title, lastPosition: lastPosition, nextStep: nextStep)
                }
            }
        }
        .alert("共同线错误", isPresented: errorBinding) {
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
            lines = try store.active()
            contextCards = Dictionary(uniqueKeysWithValues: try contextCardStore.list().map { ($0.id, $0) })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func roleTitle(for line: ContinuityLine) -> String {
        guard let contextCardId = line.contextCardId else {
            return "未绑定角色"
        }
        return contextCards[contextCardId]?.title ?? "未知角色"
    }

    private func delete(_ line: ContinuityLine) {
        do {
            try store.delete(id: line.id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(line: ContinuityLine, title: String, lastPosition: String, nextStep: String?) {
        do {
            try store.update(id: line.id, title: title, lastPosition: lastPosition, nextStep: nextStep)
            editingLine = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MilestoneStepsView: View {
    var steps: [String]
    var limit: Int?

    var visibleSteps: [String] {
        if let limit {
            return Array(steps.prefix(limit))
        }
        return steps
    }

    var hiddenStepCount: Int {
        max(steps.count - visibleSteps.count, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(index == visibleSteps.count - 1 ? ClaraDesign.continuity : ClaraDesign.inkMuted))
                        if index < visibleSteps.count - 1 {
                            Rectangle()
                                .fill(ClaraDesign.hairline)
                                .frame(width: 2, height: 22)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(index == visibleSteps.count - 1 ? "现在到这里" : "已经过")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(index == visibleSteps.count - 1 ? ClaraDesign.continuity : ClaraDesign.inkMuted)
                        Text(step)
                            .font(.system(size: 15))
                            .foregroundStyle(ClaraDesign.ink)
                            .lineLimit(2)
                    }
                    .padding(.bottom, index < visibleSteps.count - 1 ? 8 : 0)
                }
            }

            if hiddenStepCount > 0 {
                Text("还有 \(hiddenStepCount) 个里程")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ClaraDesign.inkMuted)
                    .padding(.leading, 32)
                    .padding(.top, 6)
            }
        }
    }
}

private struct ContinuityEditView: View {
    var line: ContinuityLine
    var onSave: (String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var lastPosition: String
    @State private var nextStep: String

    init(line: ContinuityLine, onSave: @escaping (String, String, String?) -> Void) {
        self.line = line
        self.onSave = onSave
        _title = State(initialValue: line.title)
        _lastPosition = State(initialValue: line.lastPosition)
        _nextStep = State(initialValue: line.nextStep ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ClaraSectionLabel(title: "标题")
                ClaraCard(accent: ClaraDesign.continuity) {
                    TextField("共同线标题", text: $title)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                ClaraSectionLabel(title: "当前位置")
                ClaraCard {
                    TextEditor(text: $lastPosition)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                }

                ClaraSectionLabel(title: "下一步")
                ClaraCard {
                    TextEditor(text: $nextStep)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .navigationTitle("编辑共同线")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(trimmedTitle, trimmedLastPosition, trimmedNextStep)
                }
                .disabled(trimmedTitle.isEmpty || trimmedLastPosition.isEmpty)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastPosition: String {
        lastPosition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNextStep: String? {
        let trimmed = nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    return ContinuityFeatureView(
        store: ContinuityStore(database: database),
        memoriaStore: MemoriaStore(database: database),
        contextCardStore: ContextCardStore(database: database)
    )
}
