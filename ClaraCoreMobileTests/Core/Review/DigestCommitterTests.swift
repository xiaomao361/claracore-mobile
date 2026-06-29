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
                    confidence: 0.9,
                    provenance: provenance
                )
            ],
            conflicts: []
        )

        let result = try committer.commit(digest)
        let memories = try memoriaStore.recall(query: "ClaraCore", limit: 10)
        let lines = try continuityStore.active()

        XCTAssertEqual(result.memories.count, 1)
        XCTAssertEqual(result.continuityLines.count, 1)
        XCTAssertEqual(memories.first?.content, "用户正在开发 ClaraCore Mobile。")
        XCTAssertEqual(lines.first?.title, "ClaraCore Mobile")
    }
}
