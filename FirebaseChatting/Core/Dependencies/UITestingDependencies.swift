//
//  UITestingDependencies.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import ComposableArchitecture

enum UITestingDependencies {
    static func configure(_ dependencies: inout DependencyValues) {
        let scenario = UITestScenario.current

        // Auth — 전체 인스턴스 교체 (liveValue가 Firebase Auth를 참조하므로)
        dependencies.authRemoteDataSource = AuthRemoteDataSource(
            getCurrentUserId: { "current-user-123" },
            signInWithGoogle: {
                User(id: "current-user-123", nickname: "나", profilePhotoUrl: nil)
            },
            signOut: { },
            getIdToken: { "mock-id-token" },
            checkUserDocumentExists: { _ in true }
        )

        // Keychain — 전체 인스턴스 교체
        dependencies.keychainDataSource = KeychainDataSource(
            saveToken: { _ in },
            loadToken: { "mock-token" },
            deleteToken: { }
        )

        // Auth Repository — 전체 인스턴스 교체 (liveValue가 authDataSource를 캡처하므로)
        dependencies.authRepository = AuthRepository(
            checkAuthenticationState: { "current-user-123" },
            signInWithGoogle: {
                User(id: "current-user-123", nickname: "나", profilePhotoUrl: nil)
            },
            logout: { }
        )

        // ChatList Repository
        dependencies.chatListRepository = MockChatListRepository.make(scenario: scenario)

        // ChatRoom Repository
        dependencies.chatRoomRepository = MockChatRoomRepository.make(scenario: scenario)

        // Storage Client — 전체 인스턴스 교체 (liveValue가 Storage.storage()를 호출하므로)
        dependencies.storageClient = StorageClient(
            uploadMedia: { _, item in
                AsyncThrowingStream { continuation in
                    Task {
                        continuation.yield(UploadProgress(
                            itemId: item.id, progress: 0.3,
                            bytesTransferred: 300, totalBytes: 1000
                        ))
                        try? await Task.sleep(for: .seconds(1))
                        continuation.yield(UploadProgress(
                            itemId: item.id, progress: 1.0,
                            bytesTransferred: 1000, totalBytes: 1000
                        ))
                        continuation.finish()
                    }
                }
            },
            getDownloadURL: { _, _ in
                URL(string: "https://picsum.photos/id/50/400/300")!
            },
            generateVideoThumbnail: { _ in Data() },
            validateFileSize: { _, _ in true }
        )

        // User Repository — 전체 인스턴스 교체 (liveValue가 Firestore를 참조하므로)
        dependencies.userRepository = UserRepository(
            observeUserDocument: { _ in
                AsyncStream { continuation in
                    continuation.yield(User(
                        id: "current-user-123",
                        nickname: "나",
                        profilePhotoUrl: nil,
                        friendIds: ["friend-1", "friend-2", "friend-3", "invite-1", "invite-2"],
                        chatRooms: ["D_current-user-123_friend-1", "G_test-group-1"]
                    ))
                }
            },
            getFriends: { _ in MockDataFactory.allFriends },
            getUserBatch: { chatRoomIds in
                var result: [String: Profile] = [:]
                for id in chatRoomIds {
                    if id.contains("friend-1") {
                        result[id] = MockDataFactory.friend1
                    } else if id.contains("friend-2") {
                        result[id] = MockDataFactory.friend2
                    } else if id.contains("friend-3") {
                        result[id] = MockDataFactory.currentUser
                    } else if id.starts(with: "G_") {
                        result[id] = MockDataFactory.friend1
                    }
                }
                return result
            },
            searchUsers: { _ in [] },
            addFriend: { _ in }
        )

        // ChatLocalDataSource — 전체 인스턴스 교체 (liveValue가 SwiftData를 참조하므로)
        dependencies.chatLocalDataSource = ChatLocalDataSource(
            saveMessages: { _, _ in },
            fetchRecentMessages: { _, _ in [] },
            fetchOlderMessages: { _, _, _ in [] },
            getLastReadIndex: { _ in 0 },
            getLastCachedCreatedAt: { _ in nil },
            updateIndex: { _, _, _ in },
            deleteChatRoom: { _ in }
        )
    }
}
