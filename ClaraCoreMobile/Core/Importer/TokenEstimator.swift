import Foundation

enum TokenEstimator {
    static func estimate(_ text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / 4.0)))
    }
}

