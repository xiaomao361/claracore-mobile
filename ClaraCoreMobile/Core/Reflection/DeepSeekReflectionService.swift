import Foundation

final class DeepSeekReflectionService: ReflectionService {
    enum ServiceError: LocalizedError, Equatable {
        case missingAPIKey
        case emptyResponse
        case invalidResponse
        case httpStatus(Int, String)
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "默认整理模型 API Key 未配置。请先在设置里保存 Key。"
            case .emptyResponse:
                return "默认整理模型返回了空内容。请稍后重试。"
            case .invalidResponse:
                return "默认整理模型返回格式异常。请稍后重试。"
            case let .httpStatus(statusCode, body):
                if statusCode == 401 || statusCode == 403 {
                    return "默认整理模型 Key 无效或没有权限。请检查 Key 后重试。"
                }
                if statusCode == 429 {
                    return "默认整理模型请求过于频繁或额度受限。请稍后重试。"
                }
                if (500..<600).contains(statusCode) {
                    return "默认整理模型服务暂时不可用。请稍后重试。"
                }
                let detail = body.trimmingCharacters(in: .whitespacesAndNewlines)
                return detail.isEmpty ? "默认整理模型请求失败：HTTP \(statusCode)。" : "默认整理模型请求失败：HTTP \(statusCode)，\(detail)"
            case let .invalidJSON(detail):
                return "默认整理模型返回的 JSON 无法解析。\(detail)"
            }
        }
    }

    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(
        apiKey: String,
        model: String = "deepseek-v4-pro",
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    static func fromEnvironment() throws -> DeepSeekReflectionService {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        return DeepSeekReflectionService(apiKey: apiKey)
    }

    func validateConnection() async throws {
        let _: DeepSeekConnectionResponse = try await completeJSON(
            system: "Return valid json only.",
            user: "Return {\"ok\":true}.",
            maxTokens: 64
        )
    }

    func reflect(segment: CaptureSegment) async throws -> SegmentReflectionDraft {
        let prompt = """
        Return strict json for this capture segment.
        Extract only what should survive outside this chat.
        Candidate memories are rare durable facts, preferences, decisions, active blockers, or diagnostic outcomes, not notes, summaries, explanations, or generic knowledge.
        Good memories: "我们完成了 ClaraCore Mobile 的 AI 对话导入闭环。", "用户决定 v1 先面向国内用户。", "用户偏好直接实现并验证。"
        Good active-blocker memories: "用户当前卡在 API Key 不可用的问题。", "配置校验失败点是 gateway.bind 只能为 loopback 或 all。"
        Bad memories: broad troubleshooting checklists, how a third-party feature works, every comparison point, temporary implementation chatter.
        Shared Line updates should preserve process progress as milestones. Use lastPosition as a compact numbered milestone trail.
        Shared Line updates should also capture mobile continuity state: stateSummary, currentInterpretation, interpretationStatus, emotionalArc, affectiveTrace, realityLine, boundaryNotes, and misreadRisks when present.
        Keep this segment conservative: at most 2 memories and at most 3 shared line updates.
        Schema:
        {
          "segmentId": "\(segment.id)",
          "summary": "short summary",
          "candidateMemories": [
            {"kind":"fact|preference|decision|task","content":"...", "confidence":0.0, "tags":["..."], "rangeStart":0, "rangeEnd":10}
          ],
          "candidateSharedLineUpdates": [
            {
              "title":"...",
              "lastPosition":"...",
              "nextStep":"...",
              "stateSummary":"compact recoverable state",
              "currentInterpretation":"what the situation currently means",
              "interpretationStatus":"active|needs_review|stale|closed",
              "emotionalArc":["1. position shift", "2. pressure eased"],
              "affectiveTrace":[{"tone":"focused","valence":"positive|negative|mixed|unclear","intensity":"low|medium|high","stability":"session|stable|volatile","signals":["..."],"note":"..."}],
              "realityLine":"confirmed ground",
              "boundaryNotes":"limits or boundaries",
              "misreadRisks":"what not to overread",
              "confidence":0.0,
              "rangeStart":0,
              "rangeEnd":10
            }
          ],
          "uncertainItems": ["..."]
        }

        Segment:
        \(segment.content)
        """

        let response: DeepSeekSegmentResponse = try await completeJSON(
            system: "You extract durable personal memory and Shared Line updates. Output valid json only.",
            user: prompt,
            maxTokens: 8_000
        )

        return response.draft(segment: segment)
    }

    func reconcile(session: ImportSession, drafts: [SegmentReflectionDraft]) async throws -> DigestResult {
        let localDigest = DraftDigestReconciler().digest(session: session, drafts: drafts)
        let payload = try String(data: JSONEncoder().encode(CompactDigestInput(drafts: drafts, digest: localDigest)), encoding: .utf8) ?? "{}"
        let prompt = """
        Return strict json that creates the final review digest for one import session from compact extraction data.
        You must transform noisy segment candidates into a small human-useful set.

        Rules:
        - candidateMemories: 0 to 3 items. Store only durable facts, stable preferences, project decisions, completed outcomes, active blockers, or diagnostic outcomes.
        - If candidateSharedLineUpdates is non-empty and the session contains any durable decision, preference, completed outcome, active blocker, or diagnostic conclusion, candidateMemories should include at least 1 item.
        - Do not store broad troubleshooting checklists, product explanations, comparison details, or every technical point as memory.
        - A good memory sounds like: "我们完成了 X", "用户决定 Y", "项目 v1 采用 Z", "用户偏好 W", "用户当前卡在 X", "X 的诊断结论是 Y".
        - candidateSharedLineUpdates: 1 to 5 items when the conversation has an ongoing process.
        - Shared lines are process tracks. lastPosition should look like milestones, for example "1. 已确认问题\n2. 已完成导入\n3. 正在验证回召".
        - nextStep should be the next concrete step, not a summary.
        - For each Shared Line, include recoverable continuity state:
          - stateSummary: compact current state.
          - currentInterpretation: current read of the situation.
          - interpretationStatus: active, needs_review, stale, or closed.
          - emotionalArc: position/emotional arc as short ordered Chinese phrases.
          - affectiveTrace: one or two emotional nodes with tone, valence, intensity, stability, signals, note.
          - realityLine: confirmed ground only.
          - boundaryNotes: explicit limits or user boundaries.
          - misreadRisks: what the next AI should not over-assume.
        - It is OK for shared lines to outnumber memories.

        Schema:
        {
          "summary": "session level summary",
          "candidateMemories": [
            {"kind":"fact|preference|decision","content":"...", "confidence":0.0, "tags":["..."]}
          ],
          "candidateSharedLineUpdates": [
            {
              "title":"...",
              "lastPosition":"1. ...\\n2. ...",
              "nextStep":"...",
              "stateSummary":"...",
              "currentInterpretation":"...",
              "interpretationStatus":"active|needs_review|stale|closed",
              "emotionalArc":["..."],
              "affectiveTrace":[{"tone":"...","valence":"positive|negative|mixed|unclear","intensity":"low|medium|high","stability":"session|stable|volatile","signals":["..."],"note":"..."}],
              "realityLine":"...",
              "boundaryNotes":"...",
              "misreadRisks":"...",
              "confidence":0.0
            }
          ],
          "conflicts": []
        }

        Session: \(session.title)
        Drafts json:
        \(payload)
        """

        let response: DeepSeekDigestResponse = try await completeJSON(
            system: "You summarize extracted draft memory. Output valid json only and do not invent facts.",
            user: prompt,
            maxTokens: 4_000
        )

        return response.digest(session: session, drafts: drafts, fallback: localDigest)
    }

    private func completeJSON<T: Decodable>(system: String, user: String, maxTokens: Int) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            DeepSeekChatRequest(
                model: model,
                messages: [
                    .init(role: "system", content: system),
                    .init(role: "user", content: user)
                ],
                thinking: .init(type: "disabled"),
                responseFormat: .init(type: "json_object"),
                maxTokens: maxTokens
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpStatus(httpResponse.statusCode, body)
        }

        let envelope: DeepSeekChatResponse
        do {
            envelope = try decoder.decode(DeepSeekChatResponse.self, from: data)
        } catch {
            throw ServiceError.invalidJSON(error.localizedDescription)
        }
        guard let content = envelope.choices.first?.message.content, !content.isEmpty else {
            throw ServiceError.emptyResponse
        }

        guard let jsonData = content.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }

        do {
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            throw ServiceError.invalidJSON(error.localizedDescription)
        }
    }
}

private struct DeepSeekConnectionResponse: Decodable {
    var ok: Bool?
}

private struct DeepSeekChatRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    struct ResponseFormat: Encodable {
        var type: String
    }

    struct Thinking: Encodable {
        var type: String
    }

    var model: String
    var messages: [Message]
    var thinking: Thinking
    var responseFormat: ResponseFormat
    var maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case thinking
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }
}

private struct DeepSeekChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message
    }

    var choices: [Choice]
}

private struct DeepSeekSegmentResponse: Decodable {
    struct Memory: Decodable {
        var kind: String
        var content: String
        var confidence: Double
        var tags: [String]
        var rangeStart: Int
        var rangeEnd: Int
    }

    struct LineUpdate: Decodable {
        struct TraceNode: Decodable {
            var tone: String?
            var valence: String?
            var intensity: String?
            var stability: String?
            var signals: [String]?
            var note: String?
        }

        var title: String
        var lastPosition: String
        var nextStep: String?
        var stateSummary: String?
        var currentInterpretation: String?
        var interpretationStatus: String?
        var emotionalArc: [String]?
        var affectiveTrace: [TraceNode]?
        var realityLine: String?
        var boundaryNotes: String?
        var misreadRisks: String?
        var confidence: Double
        var rangeStart: Int
        var rangeEnd: Int
    }

    var segmentId: String
    var summary: String
    var candidateMemories: [Memory]
    var candidateSharedLineUpdates: [LineUpdate]
    var uncertainItems: [String]

    func draft(segment: CaptureSegment) -> SegmentReflectionDraft {
        SegmentReflectionDraft(
            segmentId: segment.id,
            summary: summary,
            candidateMemories: candidateMemories.map { memory in
                let range = Self.safeRange(
                    start: memory.rangeStart,
                    end: memory.rangeEnd,
                    contentLength: segment.content.count
                )
                return CandidateMemory(
                    kind: CandidateMemory.Kind(rawValue: memory.kind) ?? .fact,
                    content: memory.content,
                    confidence: memory.confidence,
                    tags: memory.tags,
                    provenance: .init(
                        sessionId: segment.sessionId,
                        segmentId: segment.id,
                        characterRange: range
                    )
                )
            },
            candidateSharedLineUpdates: candidateSharedLineUpdates.map { update in
                let range = Self.safeRange(
                    start: update.rangeStart,
                    end: update.rangeEnd,
                    contentLength: segment.content.count
                )
                return CandidateSharedLineUpdate(
                    title: update.title,
                    lastPosition: update.lastPosition,
                    nextStep: update.nextStep,
                    stateSummary: update.stateSummary ?? "",
                    currentInterpretation: update.currentInterpretation ?? "",
                    interpretationStatus: update.interpretationStatus ?? "active",
                    emotionalArc: update.emotionalArc ?? [],
                    affectiveTrace: update.affectiveTrace?.map { node in
                        AffectiveTraceNode(
                            tone: node.tone ?? "",
                            valence: node.valence ?? "unclear",
                            intensity: node.intensity ?? "medium",
                            stability: node.stability ?? "session",
                            signals: node.signals ?? [],
                            note: node.note ?? ""
                        )
                    } ?? [],
                    realityLine: update.realityLine ?? "",
                    boundaryNotes: update.boundaryNotes ?? "",
                    misreadRisks: update.misreadRisks ?? "",
                    confidence: update.confidence,
                    provenance: .init(
                        sessionId: segment.sessionId,
                        segmentId: segment.id,
                        characterRange: range
                    )
                )
            },
            uncertainItems: uncertainItems
        )
    }

    private static func safeRange(start: Int, end: Int, contentLength: Int) -> Range<Int> {
        guard start >= 0, end >= start else {
            return 0..<0
        }
        let boundedStart = min(start, contentLength)
        let boundedEnd = min(end, contentLength)
        guard boundedEnd >= boundedStart else {
            return 0..<0
        }
        return boundedStart..<boundedEnd
    }
}

private struct DeepSeekDigestResponse: Decodable {
    struct Memory: Decodable {
        var kind: String
        var content: String
        var confidence: Double
        var tags: [String]
    }

    struct LineUpdate: Decodable {
        struct TraceNode: Decodable {
            var tone: String?
            var valence: String?
            var intensity: String?
            var stability: String?
            var signals: [String]?
            var note: String?
        }

        var title: String
        var lastPosition: String
        var nextStep: String?
        var stateSummary: String?
        var currentInterpretation: String?
        var interpretationStatus: String?
        var emotionalArc: [String]?
        var affectiveTrace: [TraceNode]?
        var realityLine: String?
        var boundaryNotes: String?
        var misreadRisks: String?
        var confidence: Double
    }

    var summary: String
    var candidateMemories: [Memory]?
    var candidateSharedLineUpdates: [LineUpdate]?
    var conflicts: [String]

    func digest(session: ImportSession, drafts: [SegmentReflectionDraft], fallback: DigestResult) -> DigestResult {
        let provenance = ReflectionProvenance(
            sessionId: session.id,
            segmentId: drafts.first?.segmentId ?? session.id,
            characterRange: 0..<0
        )

        let memories = candidateMemories?.map { memory in
            CandidateMemory(
                kind: CandidateMemory.Kind(rawValue: memory.kind) ?? .fact,
                content: memory.content,
                confidence: memory.confidence,
                tags: memory.tags,
                provenance: provenance
            )
        } ?? fallback.candidateMemories

        let lines = candidateSharedLineUpdates?.map { update in
            CandidateSharedLineUpdate(
                title: update.title,
                lastPosition: update.lastPosition,
                nextStep: update.nextStep,
                stateSummary: update.stateSummary ?? "",
                currentInterpretation: update.currentInterpretation ?? "",
                interpretationStatus: update.interpretationStatus ?? "active",
                emotionalArc: update.emotionalArc ?? [],
                affectiveTrace: update.affectiveTrace?.map { node in
                    AffectiveTraceNode(
                        tone: node.tone ?? "",
                        valence: node.valence ?? "unclear",
                        intensity: node.intensity ?? "medium",
                        stability: node.stability ?? "session",
                        signals: node.signals ?? [],
                        note: node.note ?? ""
                    )
                } ?? [],
                realityLine: update.realityLine ?? "",
                boundaryNotes: update.boundaryNotes ?? "",
                misreadRisks: update.misreadRisks ?? "",
                confidence: update.confidence,
                provenance: provenance
            )
        } ?? fallback.candidateSharedLineUpdates

        return DraftDigestReconciler().digest(
            session: session,
            drafts: [
                SegmentReflectionDraft(
                    segmentId: provenance.segmentId,
                    summary: summary,
                    candidateMemories: memories,
                    candidateSharedLineUpdates: lines,
                    uncertainItems: []
                )
            ],
            summaryOverride: summary,
            conflicts: conflicts
        )
    }
}

private struct CompactDigestInput: Encodable {
    struct Draft: Encodable {
        var sequence: Int
        var segmentId: String
        var summary: String
        var memoryCount: Int
        var sharedLineCount: Int
        var uncertainItems: [String]
    }

    struct Candidate: Encodable {
        var id: String
        var text: String
        var confidence: Double
    }

    var draftSummaries: [Draft]
    var topMemories: [Candidate]
    var topSharedLines: [Candidate]
    var conflicts: [String]

    init(drafts: [SegmentReflectionDraft], digest: DigestResult) {
        draftSummaries = drafts.enumerated().map { index, draft in
            Draft(
                sequence: index,
                segmentId: draft.segmentId,
                summary: draft.summary,
                memoryCount: draft.candidateMemories.count,
                sharedLineCount: draft.candidateSharedLineUpdates.count,
                uncertainItems: draft.uncertainItems
            )
        }
        topMemories = digest.candidateMemories.prefix(30).map {
            Candidate(id: $0.id, text: $0.content, confidence: $0.confidence)
        }
        topSharedLines = digest.candidateSharedLineUpdates.prefix(15).map {
            Candidate(id: $0.id, text: "\($0.title): \($0.lastPosition)", confidence: $0.confidence)
        }
        conflicts = digest.conflicts
    }
}
