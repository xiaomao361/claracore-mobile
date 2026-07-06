import XCTest
@testable import ClaraCoreMobile

final class RuleBasedReflectionServiceTests: XCTestCase {
    func testReflectReturnsLocalMemoryAndSharedLineCandidates() async throws {
        let service = RuleBasedReflectionService()
        let segment = CaptureSegment(
            sessionId: "session-1",
            sequence: 0,
            content: "\n用户希望保留本机整理逻辑。\n我们决定外部模型作为可选配置。",
            characterRange: 0..<37
        )

        let draft = try await service.reflect(segment: segment)

        XCTAssertEqual(draft.segmentId, segment.id)
        XCTAssertEqual(draft.summary, "用户希望保留本机整理逻辑。")
        XCTAssertEqual(draft.candidateMemories.first?.kind, .preference)
        XCTAssertEqual(draft.candidateMemories.first?.tags, ["local", "conversation"])
        XCTAssertEqual(draft.candidateSharedLineUpdates.first?.interpretationStatus, "needs_review")
        XCTAssertEqual(draft.candidateSharedLineUpdates.first?.boundaryNotes, "本机规则只做保守摘录，不推断未明确出现的信息。")
    }

    func testLocalRulebookDefinesUserVisibleLocalProcessingBoundary() {
        let rulebook = LocalOrganizationRulebook.current

        XCTAssertEqual(rulebook.displayName, "本机规则 local-v1")
        XCTAssertTrue(rulebook.settingsSummary.contains("事实、偏好、决定和待办"))
        XCTAssertTrue(rulebook.settingsSummary.contains("最多保留 4 条候选记忆"))
        XCTAssertTrue(rulebook.privacySummary.contains("不会把导入内容发送给模型提供方"))
    }

    func testLocalReflectionCanCommitWithoutRemoteModel() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let sessionStore = ImportSessionStore(database: database)
        let memoriaStore = MemoriaStore(database: database)
        let continuityStore = ContinuityStore(database: database)
        let preparer = ImportSessionPreparer(
            inboxStore: inboxStore,
            sessionStore: sessionStore,
            segmenter: FixedSizeCaptureSegmenter(maxCharacters: 120, overlapCharacters: 0)
        )
        let runner = ReflectionRunner(
            sessionStore: sessionStore,
            reflectionService: RuleBasedReflectionService()
        )
        let committer = DigestCommitter(memoriaStore: memoriaStore, continuityStore: continuityStore)
        let item = try inboxStore.enqueue(
            RawCapture(
                source: .manual,
                rawContent: "用户希望本机也能整理。\n我们决定外部模型只是可选增强。",
                contextCardId: "role-local"
            )
        )

        let prepared = try preparer.prepare(item: item)
        let result = try await runner.run(prepared: prepared)
        let committed = try committer.commit(result.digest, contextCardId: result.session.contextCardId)

        XCTAssertFalse(committed.memories.isEmpty)
        XCTAssertFalse(committed.continuityLines.isEmpty)
        XCTAssertEqual(committed.memories.first?.contextCardId, "role-local")
        XCTAssertEqual(committed.continuityLines.first?.contextCardId, "role-local")
    }
}
