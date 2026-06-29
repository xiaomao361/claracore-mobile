import Foundation

struct ContinuityLine: Identifiable, Equatable {
    enum Status: String, CaseIterable {
        case active
        case archived
    }

    var id: String
    var title: String
    var lastPosition: String
    var nextStep: String?
    var status: Status
    var createdAt: Date
    var updatedAt: Date
}
