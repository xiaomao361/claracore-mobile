import Foundation

struct InboxItem: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case pending
        case reviewed
        case committed
        case discarded
    }

    var id: String
    var source: RawCapture.Source
    var sourceApp: String?
    var sourceThreadId: String?
    var contextCardId: String? = nil
    var contentHash: String
    var rawContent: String
    var metadata: [String: String]
    var status: Status
    var createdAt: Date
    var updatedAt: Date
}
