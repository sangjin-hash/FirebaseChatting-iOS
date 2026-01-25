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
    var getUserWithFriends: @Sendable () async throws -> (user: User, friends: [User])
    var searchUsers: @Sendable (_ query: String) async throws -> [User]
    var addFriend: @Sendable (_ friendId: String) async throws -> Void
}

// MARK: - Dependency Key

extension UserRepository: DependencyKey {
    nonisolated static let liveValue: UserRepository = {
        @Dependency(\.apiClient) var apiClient
        let userDataSource = UserRemoteDataSource.live(apiClient: apiClient)

        return UserRepository(
            getUserWithFriends: {
                try await userDataSource.getUserWithFriends()
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

// MARK: - Mock Helper

extension UserRepository {
    static func mock(
        getUserWithFriends: @escaping @Sendable () async throws -> (user: User, friends: [User]) = {
            (user: User(id: "mock", nickname: "Mock User"), friends: [])
        },
        searchUsers: @escaping @Sendable (String) async throws -> [User] = { _ in [] },
        addFriend: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> Self {
        UserRepository(
            getUserWithFriends: getUserWithFriends,
            searchUsers: searchUsers,
            addFriend: addFriend
        )
    }
}
