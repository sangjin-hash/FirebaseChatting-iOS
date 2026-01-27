//
//  AuthRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

// MARK: - Errors

enum AuthRepositoryError: Error {
    case documentCreationTimeout
}

// MARK: - AuthRepository

@DependencyClient
struct AuthRepository: Sendable {
    var checkAuthenticationState: @Sendable () -> String? = { nil }
    var signInWithGoogle: @Sendable () async throws -> User
    var logout: @Sendable () async throws -> Void
}

// MARK: - Dependency Key

extension AuthRepository: DependencyKey {
    static let liveValue: AuthRepository = {
        @Dependency(\.authRemoteDataSource) var authDataSource
        @Dependency(\.keychainDataSource) var keychainDataSource

        return AuthRepository(
            checkAuthenticationState: {
                authDataSource.getCurrentUserId()
            },
            signInWithGoogle: {
                let user = try await authDataSource.signInWithGoogle()

                // Firestore 문서 생성 대기 (Firebase Auth Trigger가 비동기적으로 생성)
                try await waitForUserDocument(userId: user.profile.id, authDataSource: authDataSource)

                // 토큰 저장
                if let token = keychainDataSource.loadToken(), !token.isEmpty {
                    // 토큰이 이미 있으면 유지
                } else {
                    try? keychainDataSource.saveToken(user.profile.id)
                }

                return user
            },
            logout: {
                try authDataSource.signOut()
                try? keychainDataSource.deleteToken()
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    var authRepository: AuthRepository {
        get { self[AuthRepository.self] }
        set { self[AuthRepository.self] = newValue }
    }
}

// MARK: - Private Helpers

private func waitForUserDocument(userId: String, authDataSource: AuthRemoteDataSource) async throws {
    guard !userId.isEmpty else {
        throw AuthRepositoryError.documentCreationTimeout
    }

    let maxAttempts = 20 // 최대 10초 (0.5초 간격 * 20회)
    let interval: UInt64 = 500_000_000 // 0.5초

    for _ in 0..<maxAttempts {
        if await authDataSource.checkUserDocumentExists(userId) {
            return
        }
        try await Task.sleep(nanoseconds: interval)
    }

    throw AuthRepositoryError.documentCreationTimeout
}
