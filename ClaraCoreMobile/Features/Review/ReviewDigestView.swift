import SwiftUI

struct ReviewDigestView: View {
    let result: ReflectionRunResult
    let committer: DigestCommitter
    var onCommit: ((DigestCommitResult) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var commitMessage: String?
    @State private var errorMessage: String?
    @State private var didCommit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                reviewActionCard
                summaryCard
                statusCard
                memoryPreviewSection
                continuityPreviewSection
                conflictSection
            }
            .padding(20)
        }
        .claraScreenBackground()
        .navigationTitle("整理结果")
        .alert("提交失败", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var reviewActionCard: some View {
        ClaraCard(accent: ClaraDesign.review) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ClaraDesign.review)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("轻量复核")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ClaraDesign.ink)

                        Text("长对话不适合逐条人工审核。这里先看整理摘要和候选数量，确认方向没问题后整体入库；发现错误再到记忆或共同线里删除、编辑。")
                            .font(.system(size: 14))
                            .foregroundStyle(ClaraDesign.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    commit()
                } label: {
                    Label("全部入库", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))
                .disabled(didCommit || hasNoCandidates)

                if let commitMessage {
                    Text(commitMessage)
                        .font(.caption)
                        .foregroundStyle(ClaraDesign.inkMuted)
                } else if hasNoCandidates {
                    Text("没有可提交的候选项。通常是当前仍处于本地占位整理模式；请到设置里配置默认整理模型后重新整理。")
                        .font(.caption)
                        .foregroundStyle(ClaraDesign.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClaraSectionLabel(title: "摘要")
            ClaraCard {
                if result.digest.summary.isEmpty {
                    Text("暂无摘要")
                        .foregroundStyle(ClaraDesign.inkMuted)
                } else {
                    Text(result.digest.summary)
                        .foregroundStyle(ClaraDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClaraSectionLabel(title: "整理状态")
            ClaraCard {
                VStack(spacing: 12) {
                    ReviewMetricRow(title: "标题", value: result.session.title)
                    ReviewMetricRow(title: "分段", value: "\(result.drafts.count)")
                    ReviewMetricRow(title: "候选记忆", value: "\(result.digest.candidateMemories.count)")
                    ReviewMetricRow(title: "共同线候选", value: "\(result.digest.candidateSharedLineUpdates.count)")
                }
            }
        }
    }

    private var memoryPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClaraSectionLabel(title: "候选记忆")
            if result.digest.candidateMemories.isEmpty {
                ClaraEmptyState(title: "暂无候选记忆", message: "当前整理没有可提交的事实记忆。", systemImage: "square.stack", accent: ClaraDesign.memory)
            } else {
                VStack(spacing: 12) {
                    ForEach(memoryGroups, id: \.kind) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            ClaraSectionLabel(title: group.title)
                            ForEach(group.memories.prefix(6)) { memory in
                                ClaraCard(accent: memoryAccent(for: memory.kind)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(memory.content)
                                            .foregroundStyle(ClaraDesign.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        HStack {
                                            ClaraStatusPill(title: memoryKindTitle(memory.kind), color: memoryAccent(for: memory.kind))
                                            ClaraStatusPill(title: confidence(memory.confidence), color: ClaraDesign.inkMuted)
                                            ForEach(memory.tags.prefix(2), id: \.self) { tag in
                                                ClaraStatusPill(title: tag, color: ClaraDesign.inkMuted)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if result.digest.candidateMemories.count > 8 {
                        Text("另有 \(result.digest.candidateMemories.count - 8) 条候选记忆，将随本次整理一起入库。")
                            .font(.system(size: 13))
                            .foregroundStyle(ClaraDesign.inkMuted)
                    }
                }
            }
        }
    }

    private var continuityPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClaraSectionLabel(title: "共同线候选")
            if result.digest.candidateSharedLineUpdates.isEmpty {
                ClaraEmptyState(title: "暂无共同线候选", message: "当前整理没有形成新的可恢复共同线。", systemImage: "point.topleft.down.curvedto.point.bottomright.up", accent: ClaraDesign.continuity)
            } else {
                VStack(spacing: 12) {
                    ForEach(result.digest.candidateSharedLineUpdates.prefix(5)) { update in
                        ClaraCard(accent: ClaraDesign.continuity) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(update.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ClaraDesign.ink)
                                Text(update.lastPosition)
                                    .foregroundStyle(ClaraDesign.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let nextStep = update.nextStep {
                                    Text(nextStep)
                                        .foregroundStyle(ClaraDesign.inkMuted)
                                }
                            }
                        }
                    }
                    if result.digest.candidateSharedLineUpdates.count > 5 {
                        Text("另有 \(result.digest.candidateSharedLineUpdates.count - 5) 条共同线候选，将随本次整理一起入库。")
                            .font(.system(size: 13))
                            .foregroundStyle(ClaraDesign.inkMuted)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var conflictSection: some View {
        if !result.digest.conflicts.isEmpty {
            ClaraSectionLabel(title: "冲突")
            VStack(spacing: 12) {
                ForEach(result.digest.conflicts, id: \.self) { conflict in
                    ClaraCard(accent: ClaraDesign.danger) {
                        Text(conflict)
                            .foregroundStyle(ClaraDesign.ink)
                    }
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var hasNoCandidates: Bool {
        result.digest.candidateMemories.isEmpty && result.digest.candidateSharedLineUpdates.isEmpty
    }

    private var memoryGroups: [(kind: CandidateMemory.Kind, title: String, memories: [CandidateMemory])] {
        CandidateMemory.Kind.reviewOrder.compactMap { kind in
            let memories = result.digest.candidateMemories.filter { $0.kind == kind }
            guard !memories.isEmpty else { return nil }
            return (kind, memoryKindTitle(kind), memories)
        }
    }

    private func confidence(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func memoryKindTitle(_ kind: CandidateMemory.Kind) -> String {
        switch kind {
        case .fact:
            "事实"
        case .preference:
            "偏好"
        case .decision:
            "决定"
        case .task:
            "任务"
        }
    }

    private func memoryAccent(for kind: CandidateMemory.Kind) -> Color {
        switch kind {
        case .fact:
            ClaraDesign.memory
        case .preference:
            ClaraDesign.continuity
        case .decision:
            ClaraDesign.review
        case .task:
            ClaraDesign.reflection
        }
    }

    private func commit() {
        do {
            let committed = try committer.commit(result.digest, contextCardId: result.session.contextCardId)
            didCommit = true
            commitMessage = "已提交 \(committed.memories.count) 条记忆，\(committed.continuityLines.count) 条共同线"
            onCommit?(committed)
            dismiss()
        } catch {
            errorMessage = ClaraErrorPresenter.message(for: error)
        }
    }
}

private struct ReviewMetricRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(ClaraDesign.inkMuted)
            Spacer()
            Text(value)
                .foregroundStyle(ClaraDesign.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 15))
    }
}

#Preview {
    let database = try! AppDatabase(path: ":memory:")
    let session = ImportSession(source: .manual, title: "测试导入")
    let digest = DigestResult(
        sessionId: session.id,
        summary: "这里展示整理后的摘要。",
        candidateMemories: [],
        candidateSharedLineUpdates: [],
        conflicts: []
    )
    return NavigationStack {
        ReviewDigestView(
            result: ReflectionRunResult(session: session, drafts: [], digest: digest),
            committer: DigestCommitter(
                memoriaStore: MemoriaStore(database: database),
                continuityStore: ContinuityStore(database: database)
            )
        )
    }
}
