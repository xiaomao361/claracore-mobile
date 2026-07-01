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
    var modelProvider: ModelProviderConfiguration?
}
