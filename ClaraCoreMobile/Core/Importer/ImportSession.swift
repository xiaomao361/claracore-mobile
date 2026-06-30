import Foundation

struct ImportSession: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case importing
        case segmenting
        case reflecting
        case digested
        case committed
        case failed
    }

    var id: String
    var source: RawCapture.Source
    var sourceApp: String?
    var sourceThreadId: String?
    var contextCardId: String?
    var title: String
    var status: Status
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        source: RawCapture.Source,
        sourceApp: String? = nil,
        sourceThreadId: String? = nil,
        contextCardId: String? = nil,
        title: String,
        status: Status = .importing,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.sourceApp = sourceApp
        self.sourceThreadId = sourceThreadId
        self.contextCardId = contextCardId
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
