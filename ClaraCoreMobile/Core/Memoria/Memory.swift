import Foundation

struct Memory: Identifiable, Equatable {
    var id: String
    var content: String
    var tags: [String]
    var isPrivate: Bool
    var isArchived: Bool
    var sourceAgent: String?
    var lineId: String?
    var createdAt: Date
    var updatedAt: Date
}
