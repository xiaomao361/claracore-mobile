import XCTest
@testable import ClaraCoreMobile

final class ContextCardStoreTests: XCTestCase {
    func testDefaultCardIsCreatedOnce() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContextCardStore(database: AppDatabase(path: databaseURL.path))

        let first = try store.defaultCard()
        let second = try store.defaultCard()

        XCTAssertEqual(first.id, ContextCardStore.defaultCardID)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.agentProfile, ContextCardStore.defaultAgentProfile)
        XCTAssertEqual(second.userProfile, ContextCardStore.defaultUserProfile)
    }

    func testUpdateDefaultCardPersistsProfiles() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContextCardStore(database: AppDatabase(path: databaseURL.path))
        let card = try store.defaultCard()

        try store.update(
            id: card.id,
            title: "工作角色卡",
            agentProfile: "Agent profile",
            userProfile: "User profile"
        )

        let updated = try XCTUnwrap(store.get(id: card.id))
        XCTAssertEqual(updated.title, "工作角色卡")
        XCTAssertEqual(updated.agentProfile, "Agent profile")
        XCTAssertEqual(updated.userProfile, "User profile")
    }

    func testCreateAndListMultipleCards() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContextCardStore(database: AppDatabase(path: databaseURL.path))

        let defaultCard = try store.defaultCard()
        let second = try store.create(
            title: "项目角色卡",
            agentProfile: "Project agent",
            userProfile: "Project user"
        )
        let cards = try store.list()

        XCTAssertEqual(Set(cards.map(\.id)), Set([defaultCard.id, second.id]))
        XCTAssertEqual(try store.get(id: second.id)?.title, "项目角色卡")
    }
}
