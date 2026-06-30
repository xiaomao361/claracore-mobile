import XCTest
@testable import ClaraCoreMobile

final class ConversationImporterRegistryTests: XCTestCase {
    func testTextImporterBuildsManualCapture() async throws {
        let registry = ConversationImporterRegistry(importers: [TextConversationImporter()])
        let capture = try await registry.importCapture(from: .text("  useful transcript  "))

        XCTAssertEqual(capture.source, .manual)
        XCTAssertEqual(capture.rawContent, "useful transcript")
        XCTAssertNil(capture.sourceApp)
    }

    func testTextFileImporterBuildsFileCapture() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        try XCTUnwrap("  User: 继续 ClaraCore。\n\nAssistant: 先补文件导入。  ".data(using: .utf8))
            .write(to: fileURL)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let registry = ConversationImporterRegistry(importers: [FileConversationImporter()])
        let match = try XCTUnwrap(registry.match(for: .file(fileURL)))
        let capture = try await registry.importCapture(from: .file(fileURL))

        XCTAssertEqual(match.preview.title, "文本文件")
        XCTAssertEqual(capture.source, .file)
        XCTAssertEqual(capture.sourceApp, "文件")
        XCTAssertEqual(capture.sourceThreadId, fileURL.lastPathComponent)
        XCTAssertEqual(capture.metadata["filename"], fileURL.lastPathComponent)
        XCTAssertEqual(capture.rawContent, "User: 继续 ClaraCore。 Assistant: 先补文件导入。")
    }

    func testTextFileImporterRejectsNonTextExtension() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let importer = FileConversationImporter()

        XCTAssertFalse(importer.canHandle(.file(fileURL)))
        XCTAssertNil(importer.preview(for: .file(fileURL)))
    }

    func testRegistryMatchesDeepSeekShareURL() throws {
        let registry = ConversationImporterRegistry.live()
        let url = try XCTUnwrap(URL(string: "https://chat.deepseek.com/share/suy08uspxl9wzja7uc"))
        let match = try XCTUnwrap(registry.match(for: .url(url)))

        XCTAssertEqual(match.preview.sourceApp, "DeepSeek")
        XCTAssertEqual(match.preview.title, "DeepSeek 分享链接")
    }

    func testRegistryRoutesUnknownURLToGenericFallback() async throws {
        let html = """
        <html>
          <head><title>Shared AI Chat</title><style>.hidden{}</style></head>
          <body>
            <script>ignore()</script>
            <article>
              <h1>Useful conversation</h1>
              <p>User: 请继续这个项目。</p>
              <p>Assistant: 我们先整理导入流程。</p>
            </article>
          </body>
        </html>
        """
        let registry = ConversationImporterRegistry(
            importers: [
                GenericURLConversationImporter(
                    urlLoader: StubURLLoader(
                        data: Data(html.utf8),
                        contentType: "text/html; charset=utf-8"
                    )
                )
            ]
        )
        let url = try XCTUnwrap(URL(string: "https://example.com/share/abc"))
        let match = try XCTUnwrap(registry.match(for: .url(url)))

        XCTAssertEqual(match.preview.title, "通用链接")
        let capture = try await registry.importCapture(from: .url(url))

        XCTAssertEqual(capture.source, .url)
        XCTAssertEqual(capture.sourceApp, "example.com")
        XCTAssertEqual(capture.sourceThreadId, url.absoluteString)
        XCTAssertEqual(capture.metadata["title"], "Shared AI Chat")
        XCTAssertTrue(capture.rawContent.contains("Useful conversation"))
        XCTAssertTrue(capture.rawContent.contains("User: 请继续这个项目。"))
        XCTAssertFalse(capture.rawContent.contains("ignore()"))
    }

    func testRegistryMatchesKnownProviderURLBeforeGenericFallback() async throws {
        let html = """
        <html>
          <head><title>ChatGPT Shared Conversation</title></head>
          <body>
            <main>
              <p>User: 帮我整理这段对话。</p>
              <p>Assistant: 可以，先抽取上下文。</p>
            </main>
          </body>
        </html>
        """
        let registry = ConversationImporterRegistry.live(
            urlLoader: StubURLLoader(
                data: Data(html.utf8),
                contentType: "text/html; charset=utf-8"
            )
        )
        let url = try XCTUnwrap(URL(string: "https://chatgpt.com/share/abc"))
        let match = try XCTUnwrap(registry.match(for: .url(url)))

        XCTAssertEqual(match.preview.title, "ChatGPT 分享链接")
        XCTAssertEqual(match.preview.sourceApp, "ChatGPT")
        XCTAssertGreaterThan(match.preview.confidence, 0.5)

        let capture = try await registry.importCapture(from: .url(url))

        XCTAssertEqual(capture.source, .url)
        XCTAssertEqual(capture.sourceApp, "ChatGPT")
        XCTAssertEqual(capture.sourceThreadId, url.absoluteString)
        XCTAssertEqual(capture.metadata["provider"], "chatgpt")
        XCTAssertEqual(capture.metadata["title"], "ChatGPT Shared Conversation")
        XCTAssertEqual(capture.metadata["url"], url.absoluteString)
        XCTAssertTrue(capture.rawContent.contains("User: 帮我整理这段对话。"))
    }

    func testProviderProfileMatchesWWWHostVariant() throws {
        let url = try XCTUnwrap(URL(string: "https://www.qwen.ai/share/abc"))
        let importer = ProviderURLConversationImporter(
            profiles: [
                ProviderURLProfile(
                    id: "qwen",
                    displayName: "通义千问",
                    hosts: ["qwen.ai"]
                )
            ],
            urlLoader: StubURLLoader(data: Data(), contentType: "text/html")
        )
        let match = try XCTUnwrap(importer.preview(for: .url(url)))

        XCTAssertEqual(match.title, "通义千问 分享链接")
        XCTAssertEqual(match.sourceApp, "通义千问")
    }

    func testGenericURLTextExtractorHandlesPlainText() {
        let extracted = GenericURLTextExtractor.extract(
            from: "  Line one\n\nLine two &amp; more  ",
            contentType: "text/plain"
        )

        XCTAssertEqual(extracted, "Line one Line two & more")
    }

    func testInboxStoreFindsExistingByContentHash() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try InboxStore(database: AppDatabase(path: databaseURL.path))
        let capture = RawCapture(source: .manual, rawContent: "same transcript")
        let item = try store.enqueue(capture)

        let existing = try store.existing(
            contentHash: RawCapture.hash(" same transcript\n"),
            sourceApp: nil,
            sourceThreadId: nil
        )

        XCTAssertEqual(existing?.id, item.id)
    }
}

private struct StubURLLoader: URLDataLoading {
    var data: Data
    var statusCode = 200
    var contentType: String

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        )!
        return (data, response)
    }
}
