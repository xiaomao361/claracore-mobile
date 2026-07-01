import Foundation

typealias DeepSeekReflectionService = OpenAICompatibleReflectionService

final class OpenAICompatibleReflectionService: ReflectionService {
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

    static func fromEnvironment() throws -> OpenAICompatibleReflectionService {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        return OpenAICompatibleReflectionService(apiKey: apiKey)
    }

    func validateConnection() async throws {
        let _: OpenAICompatibleConnectionResponse = try await completeJSON(
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

        let response: OpenAICompatibleSegmentResponse = try await completeJSON(
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

        let response: OpenAICompatibleDigestResponse = try await completeJSON(
            system: "You summarize extracted draft memory. Output valid json only and do not invent facts.",
            user: prompt,
            maxTokens: 4_000
        )

        return response.digest(session: session, drafts: drafts, fallback: localDigest)
    }

    private func completeJSON<T: Decodable>(system: String, user: String, maxTokens: Int) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OpenAICompatibleChatRequest(
                model: model,
                messages: [
                    .init(role: "system", content: system),
                    .init(role: "user", content: user)
                ],
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

        let envelope: OpenAICompatibleChatResponse
        do {
            envelope = try decoder.decode(OpenAICompatibleChatResponse.self, from: data)
        } catch {
            throw ServiceError.invalidJSON(error.localizedDescription)
        }
        guard let content = envelope.choices.first?.message.content, !content.isEmpty else {
            throw ServiceError.emptyResponse
        }

        let normalizedContent = Self.extractJSONObject(from: content)
        guard let jsonData = normalizedContent.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }

        do {
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            throw ServiceError.invalidJSON(error.localizedDescription)
        }
    }

    private static func extractJSONObject(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let fenced = fencedJSONBody(in: trimmed) {
            return fenced
        }

        guard
            let start = trimmed.firstIndex(of: "{"),
            let end = matchingJSONObjectEnd(in: trimmed, from: start)
        else {
            return trimmed
        }
        return String(trimmed[start...end])
    }

    private static func fencedJSONBody(in content: String) -> String? {
        guard let opening = content.range(of: "```") else {
            return nil
        }
        let afterOpening = content[opening.upperBound...]
        guard let closing = afterOpening.range(of: "```") else {
            return nil
        }
        var body = String(afterOpening[..<closing.lowerBound])
        if let newline = body.firstIndex(of: "\n") {
            let label = body[..<newline].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if label == "json" || label.isEmpty {
                body = String(body[body.index(after: newline)...])
            }
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func matchingJSONObjectEnd(in content: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        var index = start
        while index < content.endIndex {
            let character = content[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else {
                if character == "\"" {
                    isInsideString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index = content.index(after: index)
        }
        return nil
    }
}

private struct OpenAICompatibleConnectionResponse: Decodable {
    var ok: Bool?
}

private struct OpenAICompatibleChatRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    struct ResponseFormat: Encodable {
        var type: String
    }

    var model: String
    var messages: [Message]
    var responseFormat: ResponseFormat
    var maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }
}

private struct OpenAICompatibleChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message
    }

    var choices: [Choice]
}

private struct OpenAICompatibleSegmentResponse: Decodable {
    struct Memory: Decodable {
        var kind: String
        var content: String
        var confidence: Double
        var tags: [String]
        var rangeStart: Int
        var rangeEnd: Int

        enum CodingKeys: String, CodingKey {
            case kind
            case content
            case confidence
            case tags
            case rangeStart
            case rangeEnd
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = container.decodeStringIfPresent(forKey: .kind) ?? "fact"
            content = container.decodeStringIfPresent(forKey: .content) ?? ""
            confidence = container.decodeDoubleIfPresent(forKey: .confidence) ?? 0.5
            tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
            rangeStart = container.decodeIntIfPresent(forKey: .rangeStart) ?? 0
            rangeEnd = container.decodeIntIfPresent(forKey: .rangeEnd) ?? rangeStart
        }
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

        enum CodingKeys: String, CodingKey {
            case title
            case lastPosition
            case nextStep
            case stateSummary
            case currentInterpretation
            case interpretationStatus
            case emotionalArc
            case affectiveTrace
            case realityLine
            case boundaryNotes
            case misreadRisks
            case confidence
            case rangeStart
            case rangeEnd
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = container.decodeStringIfPresent(forKey: .title) ?? "导入整理"
            lastPosition = container.decodeStringIfPresent(forKey: .lastPosition) ?? ""
            nextStep = container.decodeStringIfPresent(forKey: .nextStep)
            stateSummary = container.decodeStringIfPresent(forKey: .stateSummary)
            currentInterpretation = container.decodeStringIfPresent(forKey: .currentInterpretation)
            interpretationStatus = container.decodeStringIfPresent(forKey: .interpretationStatus)
            emotionalArc = (try? container.decodeIfPresent([String].self, forKey: .emotionalArc)) ?? []
            affectiveTrace = (try? container.decodeIfPresent([TraceNode].self, forKey: .affectiveTrace)) ?? []
            realityLine = container.decodeStringIfPresent(forKey: .realityLine)
            boundaryNotes = container.decodeStringIfPresent(forKey: .boundaryNotes)
            misreadRisks = container.decodeStringIfPresent(forKey: .misreadRisks)
            confidence = container.decodeDoubleIfPresent(forKey: .confidence) ?? 0.5
            rangeStart = container.decodeIntIfPresent(forKey: .rangeStart) ?? 0
            rangeEnd = container.decodeIntIfPresent(forKey: .rangeEnd) ?? rangeStart
        }
    }

    var segmentId: String
    var summary: String
    var candidateMemories: [Memory]
    var candidateSharedLineUpdates: [LineUpdate]
    var uncertainItems: [String]

    enum CodingKeys: String, CodingKey {
        case segmentId
        case summary
        case candidateMemories
        case candidateSharedLineUpdates
        case uncertainItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        segmentId = container.decodeStringIfPresent(forKey: .segmentId) ?? ""
        summary = container.decodeStringIfPresent(forKey: .summary) ?? ""
        candidateMemories = (try? container.decodeIfPresent([Memory].self, forKey: .candidateMemories)) ?? []
        candidateSharedLineUpdates = (try? container.decodeIfPresent([LineUpdate].self, forKey: .candidateSharedLineUpdates)) ?? []
        uncertainItems = (try? container.decodeIfPresent([String].self, forKey: .uncertainItems)) ?? []
    }

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

private struct OpenAICompatibleDigestResponse: Decodable {
    struct Memory: Decodable {
        var kind: String
        var content: String
        var confidence: Double
        var tags: [String]

        enum CodingKeys: String, CodingKey {
            case kind
            case content
            case confidence
            case tags
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = container.decodeStringIfPresent(forKey: .kind) ?? "fact"
            content = container.decodeStringIfPresent(forKey: .content) ?? ""
            confidence = container.decodeDoubleIfPresent(forKey: .confidence) ?? 0.5
            tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        }
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

        enum CodingKeys: String, CodingKey {
            case title
            case lastPosition
            case nextStep
            case stateSummary
            case currentInterpretation
            case interpretationStatus
            case emotionalArc
            case affectiveTrace
            case realityLine
            case boundaryNotes
            case misreadRisks
            case confidence
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = container.decodeStringIfPresent(forKey: .title) ?? "导入整理"
            lastPosition = container.decodeStringIfPresent(forKey: .lastPosition) ?? ""
            nextStep = container.decodeStringIfPresent(forKey: .nextStep)
            stateSummary = container.decodeStringIfPresent(forKey: .stateSummary)
            currentInterpretation = container.decodeStringIfPresent(forKey: .currentInterpretation)
            interpretationStatus = container.decodeStringIfPresent(forKey: .interpretationStatus)
            emotionalArc = (try? container.decodeIfPresent([String].self, forKey: .emotionalArc)) ?? []
            affectiveTrace = (try? container.decodeIfPresent([TraceNode].self, forKey: .affectiveTrace)) ?? []
            realityLine = container.decodeStringIfPresent(forKey: .realityLine)
            boundaryNotes = container.decodeStringIfPresent(forKey: .boundaryNotes)
            misreadRisks = container.decodeStringIfPresent(forKey: .misreadRisks)
            confidence = container.decodeDoubleIfPresent(forKey: .confidence) ?? 0.5
        }
    }

    var summary: String
    var candidateMemories: [Memory]?
    var candidateSharedLineUpdates: [LineUpdate]?
    var conflicts: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case candidateMemories
        case candidateSharedLineUpdates
        case conflicts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = container.decodeStringIfPresent(forKey: .summary) ?? ""
        candidateMemories = try? container.decodeIfPresent([Memory].self, forKey: .candidateMemories)
        candidateSharedLineUpdates = try? container.decodeIfPresent([LineUpdate].self, forKey: .candidateSharedLineUpdates)
        conflicts = (try? container.decodeIfPresent([String].self, forKey: .conflicts)) ?? []
    }

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

private extension KeyedDecodingContainer {
    func decodeStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    func decodeIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value) ?? Double(value).map(Int.init)
        }
        return nil
    }
}
