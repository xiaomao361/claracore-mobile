import XCTest
@testable import ClaraCoreMobile

final class DraftDigestReconcilerTests: XCTestCase {
    func testDigestDeduplicatesMemoriesAndKeepsHighestConfidence() {
        let session = ImportSession(source: .manual, title: "长对话")
        let first = provenance(sessionId: session.id, segmentId: "segment-1")
        let second = provenance(sessionId: session.id, segmentId: "segment-2")

        let digest = DraftDigestReconciler().digest(
            session: session,
            drafts: [
                SegmentReflectionDraft(
                    segmentId: "segment-1",
                    summary: "第一段摘要",
                    candidateMemories: [
                        CandidateMemory(
                            kind: .fact,
                            content: "用户正在开发 ClaraCore Mobile",
                            confidence: 0.6,
                            tags: ["mobile"],
                            provenance: first
                        )
                    ],
                    candidateSharedLineUpdates: [],
                    uncertainItems: []
                ),
                SegmentReflectionDraft(
                    segmentId: "segment-2",
                    summary: "第二段摘要",
                    candidateMemories: [
                        CandidateMemory(
                            kind: .fact,
                            content: "用户正在开发 ClaraCore Mobile",
                            confidence: 0.9,
                            tags: ["claracore"],
                            provenance: second
                        )
                    ],
                    candidateSharedLineUpdates: [],
                    uncertainItems: ["needs_review"]
                )
            ]
        )

        XCTAssertEqual(digest.summary, "第一段摘要\n第二段摘要")
        XCTAssertEqual(digest.candidateMemories.count, 1)
        XCTAssertEqual(digest.candidateMemories.first?.confidence, 0.9)
        XCTAssertEqual(digest.candidateMemories.first?.provenance.segmentId, "segment-2")
        XCTAssertEqual(digest.conflicts, ["needs_review"])
    }

    func testDigestLimitsCandidateCounts() {
        let session = ImportSession(source: .manual, title: "长对话")
        let draft = SegmentReflectionDraft(
            segmentId: "segment-1",
            summary: "摘要",
            candidateMemories: (0..<100).map { index in
                CandidateMemory(
                    kind: .fact,
                    content: "我们完成了第 \(index) 个可验证项目节点。",
                    confidence: Double(index) / 100,
                    tags: [],
                    provenance: provenance(sessionId: session.id, segmentId: "segment-1")
                )
            },
            candidateSharedLineUpdates: (0..<50).map { index in
                CandidateSharedLineUpdate(
                    title: "线 \(index)",
                    lastPosition: "位置 \(index)",
                    nextStep: nil,
                    confidence: Double(index) / 50,
                    provenance: provenance(sessionId: session.id, segmentId: "segment-1")
                )
            },
            uncertainItems: []
        )

        let digest = DraftDigestReconciler(memoryLimit: 10, sharedLineLimit: 6).digest(session: session, drafts: [draft])

        XCTAssertEqual(digest.candidateMemories.count, 10)
        XCTAssertEqual(digest.candidateSharedLineUpdates.count, 6)
        XCTAssertEqual(digest.candidateMemories.first?.content, "我们完成了第 99 个可验证项目节点。")
        XCTAssertEqual(digest.candidateSharedLineUpdates.first?.title, "线 49")
    }

    func testDigestKeepsMemoriesConservativeByDefault() {
        let session = ImportSession(source: .manual, title: "长对话")
        let provenance = provenance(sessionId: session.id, segmentId: "segment-1")
        let draft = SegmentReflectionDraft(
            segmentId: "segment-1",
            summary: "摘要",
            candidateMemories: [
                CandidateMemory(
                    kind: .fact,
                    content: "我们完成了 DeepSeek 分享链接导入到回召包复制的闭环。",
                    confidence: 0.93,
                    tags: ["milestone"],
                    provenance: provenance
                ),
                CandidateMemory(
                    kind: .preference,
                    content: "分享链接方案比截图 OCR 好。",
                    confidence: 0.95,
                    tags: ["note"],
                    provenance: provenance
                ),
                CandidateMemory(
                    kind: .fact,
                    content: "低置信度事实不应默认入库。",
                    confidence: 0.6,
                    tags: ["weak"],
                    provenance: provenance
                )
            ],
            candidateSharedLineUpdates: [],
            uncertainItems: []
        )

        let digest = DraftDigestReconciler().digest(session: session, drafts: [draft])

        XCTAssertEqual(
            Set(digest.candidateMemories.map(\.content)),
            Set([
                "我们完成了 DeepSeek 分享链接导入到回召包复制的闭环。",
                "分享链接方案比截图 OCR 好。"
            ])
        )
    }

    func testDigestFormatsSharedLineMilestones() {
        let session = ImportSession(source: .manual, title: "长对话")
        let provenance = provenance(sessionId: session.id, segmentId: "segment-1")
        let draft = SegmentReflectionDraft(
            segmentId: "segment-1",
            summary: "摘要",
            candidateMemories: [],
            candidateSharedLineUpdates: [
                CandidateSharedLineUpdate(
                    title: "DeepSeek记忆持久化探索",
                    lastPosition: "1. 已确认导入方式 2. 已完成解析 3. 正在验证回召",
                    nextStep: "继续实机测试",
                    confidence: 0.9,
                    provenance: provenance
                )
            ],
            uncertainItems: []
        )

        let digest = DraftDigestReconciler().digest(session: session, drafts: [draft])

        XCTAssertEqual(
            digest.candidateSharedLineUpdates.first?.lastPosition,
            "1. 已确认导入方式\n2. 已完成解析\n3. 正在验证回召"
        )
    }

    private func provenance(sessionId: String, segmentId: String) -> ReflectionProvenance {
        ReflectionProvenance(sessionId: sessionId, segmentId: segmentId, characterRange: 0..<10)
    }
}
