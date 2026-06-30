import XCTest
@testable import ClaraCoreMobile

final class ReflectionRunnerTests: XCTestCase {
    func testRunReflectsSegmentsAndBuildsDigest() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let sessionStore = ImportSessionStore(database: database)
        let preparer = ImportSessionPreparer(
            inboxStore: inboxStore,
            sessionStore: sessionStore,
            segmenter: FixedSizeCaptureSegmenter(maxCharacters: 24, overlapCharacters: 4)
        )
        let runner = ReflectionRunner(
            sessionStore: sessionStore,
            reflectionService: RuleBasedReflectionService()
        )

        let item = try inboxStore.enqueue(
            RawCapture(
                source: .manual,
                rawContent: "第一段内容。\n第二段内容，继续处理。",
                metadata: ["title": "测试导入"]
            )
        )
        let prepared = try preparer.prepare(item: item)

        let result = try await runner.run(prepared: prepared)

        XCTAssertEqual(result.session.id, prepared.session.id)
        XCTAssertEqual(result.drafts.count, prepared.segments.count)
        XCTAssertEqual(result.digest.sessionId, prepared.session.id)
        XCTAssertTrue(result.digest.summary.contains("第一段内容"))
    }
}

final class OpenAICompatibleReflectionServiceTests: XCTestCase {
    override func tearDown() {
        CapturingURLProtocol.requestHandler = nil
        CapturingURLProtocol.lastRequest = nil
        CapturingURLProtocol.lastBody = nil
        super.tearDown()
    }

    func testValidateConnectionUsesOpenAICompatibleChatCompletionsRequest() async throws {
        CapturingURLProtocol.requestHandler = { request in
            let body = try XCTUnwrap(CapturingURLProtocol.lastBody)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertEqual(json?["model"] as? String, "gpt-test")
            XCTAssertNotNil(json?["messages"])
            XCTAssertNotNil(json?["response_format"])
            XCTAssertNil(json?["thinking"])

            let responseBody = #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(responseBody.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = OpenAICompatibleReflectionService(
            apiKey: "test-key",
            model: "gpt-test",
            baseURL: try XCTUnwrap(URL(string: "https://llm.example/v1")),
            urlSession: session
        )

        try await service.validateConnection()
    }
}

private final class CapturingURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.flatMap { stream in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: bufferSize)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            return data
        }

        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
