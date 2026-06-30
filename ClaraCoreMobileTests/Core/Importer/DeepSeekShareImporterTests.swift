import XCTest
@testable import ClaraCoreMobile

final class DeepSeekShareImporterTests: XCTestCase {
    func testExtractsShareIdFromDeepSeekShareURL() throws {
        let url = try XCTUnwrap(URL(string: "https://chat.deepseek.com/share/suy08uspxl9wzja7uc"))

        XCTAssertEqual(try DeepSeekShareImporter.shareId(from: url), "suy08uspxl9wzja7uc")
        XCTAssertTrue(DeepSeekShareImporter.canImport(url: url))
    }

    func testDecodeConversationBuildsTranscriptCapture() throws {
        let data = try XCTUnwrap(Self.fixture.data(using: .utf8))
        let url = try XCTUnwrap(URL(string: "https://chat.deepseek.com/share/suy08uspxl9wzja7uc"))

        let conversation = try DeepSeekShareImporter().decodeConversation(
            data: data,
            sourceURL: url,
            shareId: "suy08uspxl9wzja7uc"
        )
        let capture = conversation.rawCapture()

        XCTAssertEqual(conversation.title, "Shared Conversation")
        XCTAssertEqual(conversation.turns.count, 2)
        XCTAssertEqual(conversation.turns.first?.role, .user)
        XCTAssertEqual(conversation.turns.last?.role, .assistant)
        XCTAssertEqual(capture.sourceApp, "DeepSeek")
        XCTAssertEqual(capture.sourceThreadId, "suy08uspxl9wzja7uc")
        XCTAssertTrue(capture.rawContent.contains("## USER"))
        XCTAssertTrue(capture.rawContent.contains("## ASSISTANT"))
        XCTAssertTrue(capture.rawContent.contains("上下文窗口是1M tokens"))
    }

    func testDecodeConversationReportsUnavailableBusinessResponse() throws {
        let data = try XCTUnwrap(Self.unavailableFixture.data(using: .utf8))

        XCTAssertThrowsError(
            try DeepSeekShareImporter().decodeConversation(
                data: data,
                sourceURL: nil,
                shareId: "expired"
            )
        ) { error in
            XCTAssertEqual(
                error as? DeepSeekShareImporter.ImportError,
                .unavailable("分享已失效")
            )
        }
    }

    private static let fixture = """
    {
      "code": 0,
      "msg": "",
      "data": {
        "biz_code": 0,
        "biz_msg": "",
        "biz_data": {
          "title": "Shared Conversation",
          "messages": [
            {
              "message_id": 1,
              "role": "USER",
              "content": "正常聊天大概能聊多少轮？",
              "inserted_at": 1782651876.419
            },
            {
              "message_id": 2,
              "role": "ASSISTANT",
              "content": "上下文窗口是1M tokens，正常日常聊天几百轮轻松跑。",
              "inserted_at": 1782651876.416
            }
          ]
        }
      }
    }
    """

    private static let unavailableFixture = """
    {
      "code": 0,
      "msg": "",
      "data": {
        "biz_code": 40001,
        "biz_msg": "分享已失效"
      }
    }
    """
}
