//
//  KeychainDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import Security
import ComposableArchitecture

// MARK: - Keychain Error

enum KeychainError: Error, Equatable {
    case saveFailed
    case deleteFailed
    case unexpectedData
}

// MARK: - KeychainDataSource

@DependencyClient
nonisolated struct KeychainDataSource: Sendable {
    var saveToken: @Sendable (_ token: String) throws -> Void
    var loadToken: @Sendable () -> String?
    var deleteToken: @Sendable () throws -> Void
}

// MARK: - DependencyKey

extension KeychainDataSource: DependencyKey {
    nonisolated static let liveValue = KeychainDataSource(
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

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var keychainDataSource: KeychainDataSource {
        get { self[KeychainDataSource.self] }
        set { self[KeychainDataSource.self] = newValue }
    }
}
