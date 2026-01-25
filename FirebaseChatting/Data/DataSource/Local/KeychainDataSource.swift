//
//  KeychainDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import Security

// MARK: - Keychain Error

enum KeychainError: Error, Equatable {
    case saveFailed
    case deleteFailed
    case unexpectedData
}

// MARK: - KeychainDataSource

struct KeychainDataSource: Sendable {
    var saveToken: @Sendable (_ token: String) throws -> Void
    var loadToken: @Sendable () -> String?
    var deleteToken: @Sendable () throws -> Void

    static let live = KeychainDataSource(
        saveToken: { token in
            let data = token.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "userToken",
                kSecValueData as String: data
            ]

            // 기존 항목 삭제
            SecItemDelete(query as CFDictionary)

            // 새 항목 추가
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed
            }
        },
        loadToken: {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "userToken",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var dataTypeRef: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

            guard status == errSecSuccess,
                  let data = dataTypeRef as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                return nil
            }

            return token
        },
        deleteToken: {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "userToken"
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed
            }
        }
    )
}

// MARK: - Mock Helper

extension KeychainDataSource {
    static func mock(
        saveToken: @escaping @Sendable (_ token: String) throws -> Void = { _ in },
        loadToken: @escaping @Sendable () -> String? = { nil },
        deleteToken: @escaping @Sendable () throws -> Void = { }
    ) -> Self {
        KeychainDataSource(
            saveToken: saveToken,
            loadToken: loadToken,
            deleteToken: deleteToken
        )
    }
}
