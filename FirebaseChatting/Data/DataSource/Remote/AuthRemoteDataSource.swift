//
//  AuthRemoteDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import ComposableArchitecture

// MARK: - Auth Error

enum AuthError: Error, Equatable {
    case clientIDError
    case tokenError
    case invalidError
    case firebaseError(String)
}

// MARK: - AuthRemoteDataSource

@DependencyClient
nonisolated struct AuthRemoteDataSource: Sendable {
    var getCurrentUserId: @Sendable () -> String?
    var signInWithGoogle: @Sendable () async throws -> User
    var signOut: @Sendable () throws -> Void
    var getIdToken: @Sendable () async throws -> String
    var checkUserDocumentExists: @Sendable (_ userId: String) async -> Bool = { _ in false }
}

// MARK: - DependencyKey

extension AuthRemoteDataSource: DependencyKey {
    nonisolated static let liveValue = AuthRemoteDataSource(
        getCurrentUserId: {
            Auth.auth().currentUser?.uid
        },
        signInWithGoogle: {
            try await withCheckedThrowingContinuation { continuation in
                signInWithGoogleInternal { result in
                    continuation.resume(with: result)
                }
            }
        },
        signOut: {
            try Auth.auth().signOut()
        },
        getIdToken: {
            guard let currentUser = Auth.auth().currentUser else {
                throw AuthError.invalidError
            }

            return try await withCheckedThrowingContinuation { continuation in
                currentUser.getIDToken { token, error in
                    if let error {
                        continuation.resume(throwing: AuthError.firebaseError(error.localizedDescription))
                    } else if let token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AuthError.tokenError)
                    }
                }
            }
        },
        checkUserDocumentExists: { userId in
            guard !userId.isEmpty else { return false }
            do {
                let db = Firestore.firestore()
                let document = try await db.collection("users").document(userId).getDocument()
                return document.exists
            } catch {
                return false
            }
        }
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var authRemoteDataSource: AuthRemoteDataSource {
        get { self[AuthRemoteDataSource.self] }
        set { self[AuthRemoteDataSource.self] = newValue }
    }
}

// MARK: - Private Helpers

private func signInWithGoogleInternal(completion: @escaping (Result<User, Error>) -> Void) {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        completion(.failure(AuthError.clientIDError))
        return
    }

    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    Task { @MainActor in
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            completion(.failure(AuthError.invalidError))
            return
        }

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

            authenticateWithFirebase(credential: credential, completion: completion)
        }
    }
}

private func authenticateWithFirebase(
    credential: AuthCredential,
    completion: @escaping (Result<User, Error>) -> Void
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
        let user = User(
            id: firebaseUser.uid,
            nickname: firebaseUser.displayName,
            profilePhotoUrl: firebaseUser.photoURL?.absoluteString
        )

        completion(.success(user))
    }
}
