import Foundation

struct ContextCard: Identifiable, Equatable {
    var id: String
    var title: String
    var agentProfile: String
    var userProfile: String
    var createdAt: Date
    var updatedAt: Date
}
