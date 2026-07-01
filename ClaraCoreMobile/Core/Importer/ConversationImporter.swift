import Foundation

enum ConversationImportInput: Equatable {
    case text(String)
    case url(URL)
    case file(URL)

    init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            self = .url(url)
        } else {
            self = .text(trimmed)
        }
    }

    var displayValue: String {
        switch self {
        case let .text(value):
            value
        case let .url(url):
            url.absoluteString
        case let .file(url):
            url.path
        }
    }
}

struct ConversationImportPreview: Equatable {
    var title: String
    var detail: String
    var sourceApp: String?
    var confidence: Double
}

protocol ConversationImporter {
    var id: String { get }
    var displayName: String { get }

    func canHandle(_ input: ConversationImportInput) -> Bool
    func preview(for input: ConversationImportInput) -> ConversationImportPreview?
    func importCapture(from input: ConversationImportInput) async throws -> RawCapture
}

struct ConversationImporterMatch {
    var importer: any ConversationImporter
    var preview: ConversationImportPreview
}

final class ConversationImporterRegistry {
    enum RegistryError: LocalizedError, Equatable {
        case unsupportedURL(String)
        case emptyInput

        var errorDescription: String? {
            switch self {
            case let .unsupportedURL(host):
                "暂时还不能直接解析 \(host) 的分享链接。后续会进入通用链接和 LLM 兜底导入。"
            case .emptyInput:
                "导入内容为空。"
            }
        }
    }

    private let importers: [any ConversationImporter]

    init(importers: [any ConversationImporter]) {
        self.importers = importers
    }

    static func live(
        deepSeekImporter: DeepSeekShareImporter = DeepSeekShareImporter(),
        urlLoader: any URLDataLoading = URLSession.shared
    ) -> ConversationImporterRegistry {
        ConversationImporterRegistry(
            importers: [
                DeepSeekConversationImporter(deepSeekImporter: deepSeekImporter),
                ProviderURLConversationImporter(urlLoader: urlLoader),
                FileConversationImporter(),
                TextConversationImporter(),
                GenericURLConversationImporter(urlLoader: urlLoader)
            ]
        )
    }

    func match(for input: ConversationImportInput) -> ConversationImporterMatch? {
        for importer in importers where importer.canHandle(input) {
            if let preview = importer.preview(for: input) {
                return ConversationImporterMatch(importer: importer, preview: preview)
            }
        }
        return nil
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard !input.displayValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RegistryError.emptyInput
        }
        guard let match = match(for: input) else {
            throw RegistryError.emptyInput
        }
        return try await match.importer.importCapture(from: input)
    }
}

protocol URLDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLDataLoading {}

struct TextConversationImporter: ConversationImporter {
    let id = "text"
    let displayName = "手动文本"

    func canHandle(_ input: ConversationImportInput) -> Bool {
        if case let .text(value) = input {
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    func preview(for input: ConversationImportInput) -> ConversationImportPreview? {
        guard canHandle(input) else { return nil }
        return ConversationImportPreview(
            title: "手动文本",
            detail: "保存为一段待整理文本",
            sourceApp: nil,
            confidence: 1
        )
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard case let .text(value) = input else {
            throw ConversationImporterRegistry.RegistryError.emptyInput
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConversationImporterRegistry.RegistryError.emptyInput
        }
        return RawCapture(source: .manual, rawContent: trimmed)
    }
}

struct FileConversationImporter: ConversationImporter {
    enum ImportError: LocalizedError, Equatable {
        case unsupportedFile
        case unreadableFile
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                "暂时只支持导入 .txt 文本文件。"
            case .unreadableFile:
                "无法读取这个文本文件。"
            case .emptyContent:
                "这个文本文件没有可导入的内容。"
            }
        }
    }

    let id = "text-file"
    let displayName = "文本文件"

    func canHandle(_ input: ConversationImportInput) -> Bool {
        guard case let .file(url) = input else { return false }
        return url.pathExtension.lowercased() == "txt"
    }

    func preview(for input: ConversationImportInput) -> ConversationImportPreview? {
        guard case let .file(url) = input, canHandle(input) else { return nil }
        return ConversationImportPreview(
            title: "文本文件",
            detail: "导入 \(url.lastPathComponent)",
            sourceApp: "文件",
            confidence: 1
        )
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard case let .file(url) = input else {
            throw ConversationImporterRegistry.RegistryError.emptyInput
        }
        guard canHandle(input) else {
            throw ImportError.unsupportedFile
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw ImportError.unreadableFile
        }
        let rawText = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        let extracted = GenericURLTextExtractor.extract(from: rawText, contentType: "text/plain")
        guard !extracted.isEmpty else {
            throw ImportError.emptyContent
        }

        return RawCapture(
            source: .file,
            rawContent: extracted,
            sourceApp: "文件",
            sourceThreadId: url.lastPathComponent,
            metadata: [
                "filename": url.lastPathComponent,
                "pathExtension": url.pathExtension.lowercased()
            ]
        )
    }
}

struct DeepSeekConversationImporter: ConversationImporter {
    let id = "deepseek-share"
    let displayName = "DeepSeek 分享链接"
    let deepSeekImporter: DeepSeekShareImporter

    func canHandle(_ input: ConversationImportInput) -> Bool {
        guard case let .url(url) = input else { return false }
        return DeepSeekShareImporter.canImport(url: url)
    }

    func preview(for input: ConversationImportInput) -> ConversationImportPreview? {
        guard canHandle(input) else { return nil }
        return ConversationImportPreview(
            title: "DeepSeek 分享链接",
            detail: "可直接解析对话快照",
            sourceApp: "DeepSeek",
            confidence: 1
        )
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard case let .url(url) = input else {
            throw DeepSeekShareImporter.ImportError.unsupportedURL
        }
        let conversation = try await deepSeekImporter.importConversation(from: url)
        return conversation.rawCapture()
    }
}

struct ProviderURLProfile: Equatable {
    var id: String
    var displayName: String
    var hosts: Set<String>
    var confidence: Double = 0.65

    static let common: [ProviderURLProfile] = [
        ProviderURLProfile(
            id: "chatgpt",
            displayName: "ChatGPT",
            hosts: ["chatgpt.com", "chat.openai.com"]
        ),
        ProviderURLProfile(
            id: "claude",
            displayName: "Claude",
            hosts: ["claude.ai"]
        ),
        ProviderURLProfile(
            id: "gemini",
            displayName: "Gemini",
            hosts: ["gemini.google.com", "g.co"]
        ),
        ProviderURLProfile(
            id: "kimi",
            displayName: "Kimi",
            hosts: ["kimi.moonshot.cn"]
        ),
        ProviderURLProfile(
            id: "doubao",
            displayName: "豆包",
            hosts: ["doubao.com", "www.doubao.com"]
        ),
        ProviderURLProfile(
            id: "qwen",
            displayName: "通义千问",
            hosts: ["tongyi.aliyun.com", "qwen.ai", "chat.qwen.ai"]
        )
    ]

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains(host) || hosts.contains(host.removingWWWPrefix)
    }
}

struct ProviderURLConversationImporter: ConversationImporter {
    let id = "provider-url"
    let displayName = "对话分享链接"
    let profiles: [ProviderURLProfile]
    let urlLoader: any URLDataLoading

    init(
        profiles: [ProviderURLProfile] = ProviderURLProfile.common,
        urlLoader: any URLDataLoading = URLSession.shared
    ) {
        self.profiles = profiles
        self.urlLoader = urlLoader
    }

    func canHandle(_ input: ConversationImportInput) -> Bool {
        guard case let .url(url) = input else { return false }
        return profile(for: url) != nil
    }

    func preview(for input: ConversationImportInput) -> ConversationImportPreview? {
        guard case let .url(url) = input, let profile = profile(for: url) else { return nil }
        return ConversationImportPreview(
            title: "\(profile.displayName) 分享链接",
            detail: "识别为 \(profile.displayName)，先尝试抓取公开网页文字",
            sourceApp: profile.displayName,
            confidence: profile.confidence
        )
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard case let .url(url) = input, let profile = profile(for: url) else {
            throw ConversationImporterRegistry.RegistryError.emptyInput
        }

        return try await GenericURLCaptureBuilder.capture(
            from: url,
            urlLoader: urlLoader,
            sourceApp: profile.displayName,
            metadata: ["provider": profile.id]
        )
    }

    private func profile(for url: URL) -> ProviderURLProfile? {
        profiles.first { $0.matches(url) }
    }
}

struct GenericURLConversationImporter: ConversationImporter {
    enum ImportError: LocalizedError, Equatable {
        case invalidResponse
        case privateOrUnauthorized
        case notFound
        case unsupportedContent
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "通用链接请求失败。请检查链接是否可公开访问。"
            case .privateOrUnauthorized:
                "这个分享链接需要登录或未公开。请确认它是公开分享链接，或改用复制文本导入。"
            case .notFound:
                "这个分享链接已经失效或不可访问。请重新生成分享链接后再导入。"
            case .unsupportedContent:
                "这个链接暂时不是可直接整理的网页或文本。"
            case .emptyContent:
                "这个链接没有提取到可整理的文字内容。"
            }
        }
    }

    let id = "generic-url"
    let displayName = "通用链接"
    let urlLoader: any URLDataLoading

    init(urlLoader: any URLDataLoading = URLSession.shared) {
        self.urlLoader = urlLoader
    }

    func canHandle(_ input: ConversationImportInput) -> Bool {
        if case .url = input {
            return true
        }
        return false
    }

    func preview(for input: ConversationImportInput) -> ConversationImportPreview? {
        guard case let .url(url) = input else { return nil }
        return ConversationImportPreview(
            title: "通用链接",
            detail: "尝试抓取 \(url.host ?? "未知域名") 的网页文字",
            sourceApp: nil,
            confidence: 0.45
        )
    }

    func importCapture(from input: ConversationImportInput) async throws -> RawCapture {
        guard case let .url(url) = input else {
            throw ConversationImporterRegistry.RegistryError.emptyInput
        }
        return try await GenericURLCaptureBuilder.capture(
            from: url,
            urlLoader: urlLoader,
            sourceApp: url.host,
            metadata: [:]
        )
    }
}

enum GenericURLCaptureBuilder {
    static func capture(
        from url: URL,
        urlLoader: any URLDataLoading,
        sourceApp: String?,
        metadata: [String: String]
    ) async throws -> RawCapture {
        var request = URLRequest(url: url)
        request.setValue("text/html, text/plain, application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("ClaraCoreMobile/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlLoader.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenericURLConversationImporter.ImportError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GenericURLConversationImporter.ImportError.privateOrUnauthorized
            }
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 410 {
                throw GenericURLConversationImporter.ImportError.notFound
            }
            throw GenericURLConversationImporter.ImportError.invalidResponse
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.contains("text/html") ||
            contentType.contains("text/plain") ||
            contentType.contains("application/xhtml+xml") ||
            contentType.isEmpty else {
            throw GenericURLConversationImporter.ImportError.unsupportedContent
        }

        let rawText = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? ""
        let extracted = GenericURLTextExtractor.extract(from: rawText, contentType: contentType)
        guard !extracted.isEmpty else {
            throw GenericURLConversationImporter.ImportError.emptyContent
        }

        var captureMetadata = metadata
        captureMetadata["title"] = GenericURLTextExtractor.title(from: rawText) ?? url.host ?? url.absoluteString
        captureMetadata["url"] = url.absoluteString

        return RawCapture(
            source: .url,
            rawContent: extracted,
            sourceApp: sourceApp,
            sourceThreadId: url.absoluteString,
            metadata: captureMetadata
        )
    }
}

enum GenericURLTextExtractor {
    static func extract(from rawText: String, contentType: String) -> String {
        let lowercasedContentType = contentType.lowercased()
        let text: String
        if lowercasedContentType.contains("html") || rawText.localizedCaseInsensitiveContains("<html") {
            text = htmlToText(rawText)
        } else {
            text = rawText
        }

        return normalizeWhitespace(decodeEntities(text))
    }

    static func title(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<title[^>]*>(.*?)</title>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let title = normalizeWhitespace(decodeEntities(String(html[titleRange])))
        return title.isEmpty ? nil : title
    }

    private static func htmlToText(_ html: String) -> String {
        var text = html
        text = replace(pattern: #"(?is)<script[^>]*>.*?</script>"#, in: text, with: " ")
        text = replace(pattern: #"(?is)<style[^>]*>.*?</style>"#, in: text, with: " ")
        text = replace(pattern: #"(?is)<noscript[^>]*>.*?</noscript>"#, in: text, with: " ")
        text = replace(pattern: #"(?i)<br\s*/?>"#, in: text, with: "\n")
        text = replace(pattern: #"(?i)</(p|div|section|article|li|h[1-6])>"#, in: text, with: "\n")
        text = replace(pattern: #"(?is)<[^>]+>"#, in: text, with: " ")
        return text
    }

    private static func replace(pattern: String, in value: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func normalizeWhitespace(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var removingWWWPrefix: String {
        hasPrefix("www.") ? String(dropFirst(4)) : self
    }
}
