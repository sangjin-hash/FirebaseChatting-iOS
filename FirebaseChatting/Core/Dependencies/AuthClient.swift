//
//  AuthClient.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// MARK: - Auth Error

enum AuthError: Error, Equatable {
    case clientIDError
    case tokenError
    case invalidError
    case firebaseError(String)
}

// MARK: - AuthClient

@DependencyClient
struct AuthClient: Sendable {
    var checkAuthenticationState: @Sendable () -> String?
    var signInWithGoogle: @Sendable () async throws -> FirebaseChatting.User
    var logout: @Sendable () async throws -> Void
}

// MARK: - Dependency Key

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        checkAuthenticationState: {
            Auth.auth().currentUser?.uid
        },
        signInWithGoogle: {
            try await withCheckedThrowingContinuation { continuation in
                signInWithGoogleInternal { result in
                    continuation.resume(with: result)
                }
            }
        },
        logout: {
            try Auth.auth().signOut()
        }
    )
}

// MARK: - Dependency Values

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

// MARK: - Mock Helper

extension AuthClient {
    static func mock(
        checkAuthenticationState: @escaping @Sendable () -> String? = { nil },
        signInWithGoogle: @escaping @Sendable () async throws -> FirebaseChatting.User = {
            FirebaseChatting.User(id: "mock", name: "Mock User", profileURL: nil)
        },
        logout: @escaping @Sendable () async throws -> Void = { }
    ) -> Self {
        AuthClient(
            checkAuthenticationState: checkAuthenticationState,
            signInWithGoogle: signInWithGoogle,
            logout: logout
        )
    }
}

// MARK: - Private Helpers

private func signInWithGoogleInternal(completion: @escaping (Result<FirebaseChatting.User, Error>) -> Void) {
    // 1. Firebase ClientID 가져오기
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        completion(.failure(AuthError.clientIDError))
        return
    }

    // 2. Google Sign-In 설정
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    // 3. RootViewController 가져오기 (메인 스레드에서 실행)
    Task { @MainActor in
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            completion(.failure(AuthError.invalidError))
            return
        }

        // 4. Google Sign-In 실행
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(.failure(AuthError.tokenError))
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            // 5. Firebase 인증
            authenticateWithFirebase(credential: credential, completion: completion)
        }
    }
}

private func authenticateWithFirebase(
    credential: AuthCredential,
    completion: @escaping (Result<FirebaseChatting.User, Error>) -> Void
) {
    Auth.auth().signIn(with: credential) { result, error in
        if let error {
            completion(.failure(AuthError.firebaseError(error.localizedDescription)))
            return
        }

        guard let result else {
            completion(.failure(AuthError.invalidError))
            return
        }

        let firebaseUser = result.user
        let user = FirebaseChatting.User(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "Default",
            profileURL: firebaseUser.photoURL?.absoluteString
        )

        completion(.success(user))
    }
}
