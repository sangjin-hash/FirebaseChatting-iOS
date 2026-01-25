//
//  UserRemoteDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - API Endpoints

enum UserAPIEndpoint {
    static let getUserWithFriends = "/getUserWithFriends"
    static let searchUsers: String = "/searchUsers"
    static let addFriend: String = "/addFriend"
}

// MARK: - UserRemoteDataSource

struct UserRemoteDataSource: Sendable {
    var getUserWithFriends: @Sendable () async throws -> (user: User, friends: [User])
    var searchUsers: @Sendable (_ query: String) async throws -> [User]
    var addFriend: @Sendable (_ friendId: String) async throws -> Void

    static func live(apiClient: APIClient) -> UserRemoteDataSource {
        UserRemoteDataSource(
            getUserWithFriends: {
                let request = EmptyDataRequest()
                let bodyData = try JSONEncoder().encode(request)
                let responseData = try await apiClient.post(UserAPIEndpoint.getUserWithFriends, bodyData)

                let response = try JSONDecoder().decode(GetUserWithFriendsResponse.self, from: responseData)
                return (user: response.result.user, friends: response.result.friends)
            },
            searchUsers: { (query: String) -> [User] in
                let request = SearchUsersRequest(query: query)
                let bodyData = try JSONEncoder().encode(request)
                let responseData = try await apiClient.post(UserAPIEndpoint.searchUsers, bodyData)

                let response = try JSONDecoder().decode(SearchUsersResponse.self, from: responseData)
                return response.result.users
            },
            addFriend: { (friendId: String) -> Void in
                let request = AddFriendRequest(friendId: friendId)
                let bodyData = try JSONEncoder().encode(request)
                _ = try await apiClient.post(UserAPIEndpoint.addFriend, bodyData)
            }
        )
    }
}

// MARK: - Mock Helper

extension UserRemoteDataSource {
    static func mock(
        getUserWithFriends: @escaping @Sendable () async throws -> (user: User, friends: [User]) = {
            (user: User(id: "mock", nickname: "Mock User"), friends: [])
        },
        searchUsers: @escaping @Sendable (_ query: String) async throws -> [User] = { _ in [] },
        addFriend: @escaping @Sendable (_ friendId: String) async throws -> Void = { _ in }
    ) -> Self {
        UserRemoteDataSource(
            getUserWithFriends: getUserWithFriends,
            searchUsers: searchUsers,
            addFriend: addFriend
        )
    }
}
