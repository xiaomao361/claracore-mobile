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

    func testDecodeChineseDeepSeekShareFixtures() throws {
        for fixture in Self.chineseFixtures {
            let data = try XCTUnwrap(fixture.json.data(using: .utf8))
            let url = try XCTUnwrap(URL(string: "https://chat.deepseek.com/share/\(fixture.shareId)"))

            let conversation = try DeepSeekShareImporter().decodeConversation(
                data: data,
                sourceURL: url,
                shareId: fixture.shareId
            )
            let capture = conversation.rawCapture()

            XCTAssertEqual(conversation.title, fixture.title)
            XCTAssertEqual(conversation.turns.count, fixture.turnCount)
            XCTAssertEqual(capture.sourceApp, "DeepSeek")
            XCTAssertEqual(capture.sourceThreadId, fixture.shareId)
            XCTAssertTrue(capture.rawContent.contains(fixture.expectedContent), fixture.shareId)
        }
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

    private struct ChineseFixture {
        var shareId: String
        var title: String
        var turnCount: Int
        var expectedContent: String
        var json: String
    }

    private static let chineseFixtures: [ChineseFixture] = [
        ChineseFixture(
            shareId: "d5rysnhay81v4mh8xu",
            title: "历代帝王与朝代梳理",
            turnCount: 2,
            expectedContent: "上古至清朝",
            json: """
            {
              "code": 0,
              "msg": "",
              "data": {
                "biz_code": 0,
                "biz_msg": "",
                "biz_data": {
                  "title": "历代帝王与朝代梳理",
                  "messages": [
                    {
                      "message_id": 101,
                      "parent_id": null,
                      "role": "USER",
                      "content": "请分析上古至清朝的历代帝王与朝代、年份和年号。",
                      "inserted_at": 1782651876.419,
                      "search_enabled": false
                    },
                    {
                      "message_id": 102,
                      "parent_id": 101,
                      "role": "ASSISTANT",
                      "content": "可以按朝代顺序整理：夏、商、周、秦、汉，一直到明清，并单独标出年号变化。",
                      "inserted_at": 1782651878.416,
                      "thinking_content": "用户需要中文历史梳理，重点是年代和年号。",
                      "thinking_elapsed_secs": 1
                    }
                  ]
                }
              }
            }
            """
        ),
        ChineseFixture(
            shareId: "h3tkicxmtg40n3leaf",
            title: "Markdown 和 HTML 之争",
            turnCount: 2,
            expectedContent: "markdown和HTML之争",
            json: """
            {
              "code": 0,
              "msg": "",
              "data": {
                "biz_code": 0,
                "biz_msg": "",
                "biz_data": {
                  "title": "Markdown 和 HTML 之争",
                  "messages": [
                    {
                      "message_id": 201,
                      "role": "USER",
                      "content": "最近markdown和HTML之争到底怎么回事？",
                      "inserted_at": 1782652876.419,
                      "search_status": "FINISHED"
                    },
                    {
                      "message_id": 202,
                      "role": "ASSISTANT",
                      "content": "争议核心不是二选一，而是写作便利、结构表达、可移植性与安全边界之间的取舍。",
                      "inserted_at": 1782652878.416,
                      "search_results": [
                        {
                          "title": "相关讨论",
                          "url": "https://example.com/discussion",
                          "snippet": "中文社区围绕 Markdown 与 HTML 的边界展开讨论。"
                        }
                      ]
                    }
                  ]
                }
              }
            }
            """
        ),
        ChineseFixture(
            shareId: "uyp1quvijtvsxndi2z",
            title: "香港独留子女在家规定",
            turnCount: 2,
            expectedContent: "香港獨留子女在家規定年齡",
            json: """
            {
              "code": 0,
              "msg": "",
              "data": {
                "biz_code": 0,
                "biz_msg": "",
                "biz_data": {
                  "title": "香港独留子女在家规定",
                  "messages": [
                    {
                      "message_id": 301,
                      "role": "USER",
                      "content": "香港獨留子女在家規定年齡？",
                      "inserted_at": 1782653876.419,
                      "tips": ["法律信息需要核对最新官方来源"]
                    },
                    {
                      "message_id": 302,
                      "role": "ASSISTANT",
                      "content": "香港沒有一條簡單的固定年齡線，需要看照顧安排、時間長短、兒童成熟度和是否構成疏忽。",
                      "inserted_at": 1782653878.416,
                      "thinking_content": "用户用繁体中文提问，需要用审慎口吻回答。"
                    }
                  ]
                }
              }
            }
            """
        )
    ]
}
