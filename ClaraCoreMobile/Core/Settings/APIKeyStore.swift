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
                "本地占位"
            case .remoteModel:
                "远程模型"
            }
        }
    }

    var mode: Mode
    var modelProvider: ModelProviderConfiguration?
}
