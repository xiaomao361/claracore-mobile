import Foundation
import Security

protocol APIKeyStore {
    func read(service: APIKeyService) throws -> String?
    func save(_ value: String, service: APIKeyService) throws
    func delete(service: APIKeyService) throws
}

enum APIKeyService: String {
    case deepSeek = "deepseek"
    case modelProvider = "model-provider"

    var account: String {
        rawValue
    }
}

struct ModelProviderConfiguration: Codable, Equatable {
    var providerName: String
    var baseURLString: String
    var model: String

    static let userDefaultsKey = "modelProviderConfiguration"

    static let deepSeekDefault = ModelProviderConfiguration(
        providerName: "DeepSeek",
        baseURLString: "https://api.deepseek.com",
        model: "deepseek-v4-pro"
    )

    var baseURL: URL? {
        URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var trimmedProviderName: String {
        providerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalized: ModelProviderConfiguration {
        ModelProviderConfiguration(
            providerName: trimmedProviderName.isEmpty ? "OpenAI-compatible" : trimmedProviderName,
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            model: trimmedModel
        )
    }
}

enum ModelProviderConfigurationStore {
    static func load(userDefaults: UserDefaults = .standard) -> ModelProviderConfiguration {
        guard let data = userDefaults.data(forKey: ModelProviderConfiguration.userDefaultsKey),
              let configuration = try? JSONDecoder().decode(ModelProviderConfiguration.self, from: data) else {
            return .deepSeekDefault
        }
        return configuration.normalized
    }

    static func save(_ configuration: ModelProviderConfiguration, userDefaults: UserDefaults = .standard) throws {
        let data = try JSONEncoder().encode(configuration.normalized)
        userDefaults.set(data, forKey: ModelProviderConfiguration.userDefaultsKey)
    }
}

enum OrganizationEngineMode: String, Codable, CaseIterable, Identifiable {
    case localRules
    case externalModel

    static let userDefaultsKey = "organizationEngineMode"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .localRules:
            "本机规则"
        case .externalModel:
            "外部模型"
        }
    }

    var detail: String {
        switch self {
        case .localRules:
            "默认方式。导入内容保留在本机，用保守规则摘取记忆和共同线。"
        case .externalModel:
            "可选增强。主动整理时把必要内容发送到你配置的模型提供方。"
        }
    }
}

enum OrganizationEngineModeStore {
    static func load(userDefaults: UserDefaults = .standard) -> OrganizationEngineMode {
        guard let value = userDefaults.string(forKey: OrganizationEngineMode.userDefaultsKey),
              let mode = OrganizationEngineMode(rawValue: value) else {
            return .localRules
        }
        return mode
    }

    static func save(_ mode: OrganizationEngineMode, userDefaults: UserDefaults = .standard) {
        userDefaults.set(mode.rawValue, forKey: OrganizationEngineMode.userDefaultsKey)
    }
}

enum ExternalModelProcessingConsentStore {
    static let userDefaultsKey = "thirdPartyAIProcessingConsentAccepted"

    static func isAccepted(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: userDefaultsKey)
    }
}

struct OrganizationEngineStatus: Equatable {
    struct Requirement: Identifiable, Equatable {
        var id: String
        var title: String
        var isMet: Bool
    }

    var preferredMode: OrganizationEngineMode
    var effectiveMode: ReflectionConfiguration.Mode
    var hasSavedModelKey: Bool
    var hasAcceptedExternalProcessing: Bool
    var modelProvider: ModelProviderConfiguration

    var isModelConfigurationComplete: Bool {
        modelProvider.baseURL != nil && !modelProvider.trimmedModel.isEmpty
    }

    var isExternalModelEnabled: Bool {
        preferredMode == .externalModel &&
            effectiveMode == .remoteModel &&
            hasSavedModelKey &&
            isModelConfigurationComplete &&
            hasAcceptedExternalProcessing
    }

    var metRequirementCount: Int {
        requirements.filter(\.isMet).count
    }

    var unmetRequirementTitles: [String] {
        requirements.filter { !$0.isMet }.map(\.title)
    }

    var statusPillTitle: String {
        isExternalModelEnabled ? "已启用外部模型" : "正在使用本机规则"
    }

    var statusPillIcon: String {
        isExternalModelEnabled ? "checkmark.seal" : "checkmark.shield"
    }

    var selectedTitle: String {
        "已选择：\(preferredMode.title)"
    }

    var effectiveTitle: String {
        "当前生效：\(isExternalModelEnabled ? "外部模型" : "本机规则")"
    }

    var activationProgressTitle: String {
        "启用条件：\(metRequirementCount)/\(requirements.count) 已完成"
    }

    var activationRuleSummary: String {
        if isExternalModelEnabled {
            return "外部模型已满足全部条件。只有你主动点击导入并整理时，必要内容才会发送到已配置的模型提供方。"
        }
        if preferredMode == .externalModel {
            let missing = unmetRequirementTitles.joined(separator: "、")
            return "你只是选择了外部模型；还差 \(missing)。未全部完成前，本次整理仍走本机规则。"
        }
        return "本机规则已生效。导入内容不会发送给模型提供方。"
    }

    var importSummary: String {
        if isExternalModelEnabled {
            return "本次导入会使用 \(modelProvider.trimmedProviderName) 的 \(modelProvider.trimmedModel) 整理。"
        }
        if preferredMode == .externalModel {
            return "外部模型还没有启用，本次导入仍会使用本机规则。"
        }
        return "本次导入会使用本机规则，内容不会发送给模型提供方。"
    }

    var detail: String {
        if isExternalModelEnabled {
            return "外部模型已启用。只有你主动点击导入并整理时，必要内容才会发送到已配置的模型提供方。"
        }
        if preferredMode == .externalModel {
            return "外部模型需要同时满足：选择外部模型、保存可用 Base URL 和模型、保存 API Key、确认外部模型处理说明。未满足前会自动使用本机规则。"
        }
        return "下一次导入会直接使用本机规则。导入内容不会发送给模型提供方。"
    }

    var requirements: [Requirement] {
        [
            Requirement(id: "selected", title: "已选择外部模型", isMet: preferredMode == .externalModel),
            Requirement(id: "configuration", title: "Base URL 和模型可用", isMet: isModelConfigurationComplete),
            Requirement(id: "key", title: "API Key 已保存", isMet: hasSavedModelKey),
            Requirement(id: "consent", title: "已确认外部处理说明", isMet: hasAcceptedExternalProcessing)
        ]
    }
}

struct ModelProviderClient {
    enum ClientError: LocalizedError, Equatable {
        case invalidBaseURL
        case emptyModels
        case invalidResponse
        case httpStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "模型 Base URL 无效。"
            case .emptyModels:
                return "这个地址没有返回可用模型。请检查 Base URL 或 Key。"
            case .invalidResponse:
                return "模型列表返回格式异常。"
            case let .httpStatus(statusCode, body):
                if statusCode == 401 || statusCode == 403 {
                    return "模型 Key 无效或没有权限读取模型列表。"
                }
                let detail = body.trimmingCharacters(in: .whitespacesAndNewlines)
                return detail.isEmpty ? "模型列表请求失败：HTTP \(statusCode)。" : "模型列表请求失败：HTTP \(statusCode)，\(detail)"
            }
        }
    }

    struct Model: Decodable, Identifiable, Equatable {
        var id: String
    }

    private struct ModelsResponse: Decodable {
        var data: [Model]
    }

    var baseURL: URL
    var apiKey: String
    var urlSession: URLSession = .shared

    func listModels() async throws -> [Model] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded: ModelsResponse
        do {
            decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        let models = decoded.data
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
        guard !models.isEmpty else {
            throw ClientError.emptyModels
        }
        return models
    }
}

final class KeychainAPIKeyStore: APIKeyStore {
    enum StoreError: Error {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    private let serviceName: String

    init(serviceName: String = "com.claracore.mobile.api-keys") {
        self.serviceName = serviceName
    }

    func read(service: APIKeyService) throws -> String? {
        var query = baseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw StoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidData
        }
        return value
    }

    func save(_ value: String, service: APIKeyService) throws {
        let data = Data(value.utf8)
        var query = baseQuery(service: service)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw StoreError.unexpectedStatus(addStatus)
        }
    }

    func delete(service: APIKeyService) throws {
        let status = SecItemDelete(baseQuery(service: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(service: APIKeyService) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: service.account
        ]
    }
}

struct ReflectionConfiguration: Equatable {
    enum Mode: String {
        case localPlaceholder
        case remoteModel

        var title: String {
            switch self {
            case .localPlaceholder:
                "本机整理"
            case .remoteModel:
                "外部模型"
            }
        }
    }

    var mode: Mode
    var preferredEngineMode: OrganizationEngineMode = .localRules
    var modelProvider: ModelProviderConfiguration?
}
