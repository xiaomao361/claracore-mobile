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
