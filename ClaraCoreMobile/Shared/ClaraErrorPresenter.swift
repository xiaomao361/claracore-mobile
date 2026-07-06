import Foundation

enum ClaraErrorPresenter {
    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "网络不可用。请检查网络连接后重试。"
            case NSURLErrorTimedOut:
                return "请求超时。请稍后重试。"
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return "无法连接到服务。请检查网络或代理设置。"
            default:
                return "网络请求失败：\(nsError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }
}

enum UserVisibleErrorDetailSanitizer {
    static func providerResponseDetail(from body: String, maxCharacters: Int = 160) -> String? {
        let compacted = body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !compacted.isEmpty else {
            return nil
        }

        let redacted = [
            #"(Bearer\s+)[A-Za-z0-9._~+/=-]{8,}"#,
            #"(sk-)[A-Za-z0-9_-]{8,}"#,
            #"([Aa][Pp][Ii][_ -]?[Kk][Ee][Yy]["']?\s*[:=]\s*["']?)[A-Za-z0-9._~+/=-]{8,}"#
        ].reduce(compacted) { current, pattern in
            current.replacingOccurrences(
                of: pattern,
                with: "$1[redacted]",
                options: .regularExpression
            )
        }

        guard redacted.count > maxCharacters else {
            return redacted
        }
        return "\(redacted.prefix(maxCharacters))..."
    }
}
