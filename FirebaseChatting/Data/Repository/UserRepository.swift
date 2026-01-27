//
//  UserRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

// MARK: - UserRepository

@DependencyClient
nonisolated struct UserRepository: Sendable {
    var observeUserDocument: @Sendable (_ userId: String) -> AsyncStream<User> = { _ in
        AsyncStream { $0.finish() }
    }
    var getFriends: @Sendable (_ friendIds: [String]) async throws -> [Profile]
    var getUserBatch: @Sendable (_ chatRoomIds: [String]) async throws -> [String: Profile]
    var searchUsers: @Sendable (_ query: String) async throws -> [Profile]
    var addFriend: @Sendable (_ friendId: String) async throws -> Void
}

// MARK: - Dependency Key

extension UserRepository: DependencyKey {
    nonisolated static let liveValue: UserRepository = {
        @Dependency(\.userRemoteDataSource) var userDataSource

        return UserRepository(
            observeUserDocument: { userId in
                userDataSource.observeUserDocument(userId)
            },
            getFriends: { friendIds in
                try await userDataSource.getFriends(friendIds)
            },
            getUserBatch: { chatRoomIds in
                try await userDataSource.getUserBatch(chatRoomIds)
            },
            searchUsers: { query in
                try await userDataSource.searchUsers(query)
            },
            addFriend: { friendId in
                try await userDataSource.addFriend(friendId)
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    nonisolated var userRepository: UserRepository {
        get { self[UserRepository.self] }
        set { self[UserRepository.self] = newValue }
    }
}
