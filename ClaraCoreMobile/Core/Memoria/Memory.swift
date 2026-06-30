import Foundation

struct Memory: Identifiable, Equatable {
    var id: String
    var content: String
    var tags: [String]
    var isPrivate: Bool
    var isArchived: Bool
    var sourceAgent: String?
    var lineId: String?
    var contextCardId: String? = nil
    var confidence: Double = 1.0
    var importance: Double = 0.0
    var createdAt: Date
    var updatedAt: Date
}
