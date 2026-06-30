import XCTest
@testable import ClaraCoreMobile

final class DigestCommitterTests: XCTestCase {
    func testCommitStoresCandidateMemoryAndContinuityLine() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let memoriaStore = MemoriaStore(database: database)
        let continuityStore = ContinuityStore(database: database)
        let committer = DigestCommitter(
            memoriaStore: memoriaStore,
            continuityStore: continuityStore
        )

        let provenance = ReflectionProvenance(
            sessionId: "session-1",
            segmentId: "segment-1",
            characterRange: 0..<10
        )
        let digest = DigestResult(
            sessionId: "session-1",
            summary: "整理摘要",
            candidateMemories: [
                CandidateMemory(
                    kind: .fact,
                    content: "用户正在开发 ClaraCore Mobile。",
                    confidence: 0.92,
                    tags: ["ClaraCore"],
                    provenance: provenance
                )
            ],
            candidateSharedLineUpdates: [
                CandidateSharedLineUpdate(
                    title: "ClaraCore Mobile",
                    lastPosition: "导入内容已经可以整理。",
                    nextStep: "提交整理结果。",
                    stateSummary: "导入闭环已接近可测状态。",
                    currentInterpretation: "用户在确认 mobile 是否保留足够的共同线状态。",
                    interpretationStatus: "needs_review",
                    emotionalArc: ["从导入可用推进到状态完整性检查"],
                    affectiveTrace: [
                        AffectiveTraceNode(
                            tone: "审慎",
                            valence: "mixed",
                            intensity: "medium",
                            stability: "session",
                            signals: ["担心简化过度"],
                            note: "需要补回共同线参数"
                        )
                    ],
                    realityLine: "mobile 已能导入并写入记忆和共同线。",
                    boundaryNotes: "不要把 mobile 当作 agent runtime。",
                    misreadRisks: "不要只保留里程碑而丢掉情绪和位置弧线。",
                    confidence: 0.9,
                    provenance: provenance
                )
            ],
            conflicts: []
        )

        let result = try committer.commit(digest, contextCardId: "role-1")
        let memories = try memoriaStore.recall(query: "ClaraCore", limit: 10, contextCardId: "role-1")
        let lines = try continuityStore.active(contextCardId: "role-1")

        XCTAssertEqual(result.memories.count, 1)
        XCTAssertEqual(result.continuityLines.count, 1)
        XCTAssertEqual(memories.first?.content, "用户正在开发 ClaraCore Mobile。")
        XCTAssertEqual(memories.first?.lineId, result.continuityLines.first?.id)
        XCTAssertEqual(memories.first?.contextCardId, "role-1")
        XCTAssertEqual(lines.first?.title, "ClaraCore Mobile")
        XCTAssertEqual(lines.first?.contextCardId, "role-1")
        XCTAssertEqual(lines.first?.stateSummary, "导入闭环已接近可测状态。")
        XCTAssertEqual(lines.first?.currentInterpretation, "用户在确认 mobile 是否保留足够的共同线状态。")
        XCTAssertEqual(lines.first?.interpretationStatus, "needs_review")
        XCTAssertEqual(lines.first?.emotionalArc, ["从导入可用推进到状态完整性检查"])
        XCTAssertEqual(lines.first?.latestAffectiveTrace?.tone, "审慎")
        XCTAssertEqual(lines.first?.realityLine, "mobile 已能导入并写入记忆和共同线。")
        XCTAssertEqual(memories.first?.confidence, 0.92)
    }
}
