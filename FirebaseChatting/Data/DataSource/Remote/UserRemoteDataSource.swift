//
//  UserRemoteDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import FirebaseFirestore
import ComposableArchitecture

// MARK: - API Endpoints

enum UserAPIEndpoint {
    static let getFriends = "/getFriends"
    static let getUserBatch = "/getUserBatch"
    static let searchUsers = "/searchUsers"
    static let addFriend = "/addFriend"
}

// MARK: - UserRemoteDataSource

@DependencyClient
nonisolated struct UserRemoteDataSource: Sendable {
    var observeUserDocument: @Sendable (_ userId: String) -> AsyncStream<User> = { _ in
        AsyncStream { $0.finish() }
    }
    var getFriends: @Sendable (_ friendIds: [String]) async throws -> [Profile]
    var getUserBatch: @Sendable (_ chatRoomIds: [String]) async throws -> [String: Profile]
    var searchUsers: @Sendable (_ query: String) async throws -> [Profile]
    var addFriend: @Sendable (_ friendId: String) async throws -> Void
}

// MARK: - DependencyKey

extension UserRemoteDataSource: DependencyKey {
    nonisolated static let liveValue: UserRemoteDataSource = {
        @Dependency(\.apiClient) var apiClient
        let db = Firestore.firestore()

        return UserRemoteDataSource(
            observeUserDocument: { userId in
                AsyncStream { continuation in
                    let listener = db.collection("users").document(userId)
                        .addSnapshotListener { snapshot, error in
                            if let error {
                                print("UserRemoteDataSource observeUserDocument error: \(error.localizedDescription)")
                                return
                            }

                            guard let snapshot, snapshot.exists,
                                  let data = snapshot.data() else {
                                return
                            }

                            let profile = Profile(
                                id: data["id"] as? String ?? userId,
                                nickname: data["nickname"] as? String,
                                profilePhotoUrl: data["profilePhotoUrl"] as? String
                            )
                            let user = User(
                                profile: profile,
                                friendIds: data["friendIds"] as? [String] ?? [],
                                chatRooms: data["chatRooms"] as? [String] ?? []
                            )

                            continuation.yield(user)
                        }

                    continuation.onTermination = { _ in
                        listener.remove()
                    }
                }
            },
            getFriends: { (friendIds: [String]) -> [Profile] in
                let request = GetFriendsRequest(friendIds: friendIds)
                let bodyData = try JSONEncoder().encode(request)
                let responseData = try await apiClient.post(UserAPIEndpoint.getFriends, bodyData)

                let response = try JSONDecoder().decode(GetFriendsResponse.self, from: responseData)
                return response.result.profiles
            },
            getUserBatch: { (chatRoomIds: [String]) -> [String: Profile] in
                let request = GetUserBatchRequest(chatRooms: chatRoomIds)
                let bodyData = try JSONEncoder().encode(request)
                let responseData = try await apiClient.post(UserAPIEndpoint.getUserBatch, bodyData)

                let response = try JSONDecoder().decode(GetUserBatchResponse.self, from: responseData)
                return response.result.profiles
            },
            searchUsers: { (query: String) -> [Profile] in
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
    }()
}

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var userRemoteDataSource: UserRemoteDataSource {
        get { self[UserRemoteDataSource.self] }
        set { self[UserRemoteDataSource.self] = newValue }
    }
}
