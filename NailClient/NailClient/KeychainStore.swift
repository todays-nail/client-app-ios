//
//  KeychainStore.swift
//  NailClient
//

import Foundation
import Security

final class KeychainStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    var deviceId: String? {
        get { readString(key: "device_id") }
        set {
            if let newValue {
                writeString(newValue, key: "device_id")
            } else {
                delete(key: "device_id")
            }
        }
    }

    var refreshToken: String? {
        get { readString(key: "refresh_token") }
        set {
            if let newValue {
                writeString(newValue, key: "refresh_token")
            } else {
                delete(key: "refresh_token")
            }
        }
    }

    private func writeString(_ value: String, key: String) {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // 사용자가 기기 잠금 해제 후 접근 가능, 백업/이전 시 복구되지 않도록 제약
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func readString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}

