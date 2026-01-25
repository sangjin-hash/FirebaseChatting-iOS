//
//  TestData.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
@testable import FirebaseChatting

// MARK: - Test User Data

enum TestData {

    // MARK: - Users

    static let currentUser = User(
        id: "current-user-123",
        nickname: "Current User",
        profilePhotoUrl: "https://example.com/current.jpg",
        friendIds: ["friend-1", "friend-2"],
        chatRooms: ["chatroom-1"]
    )

    static let currentUserWithNoFriends = User(
        id: "current-user-123",
        nickname: "Current User",
        profilePhotoUrl: "https://example.com/current.jpg",
        friendIds: [],
        chatRooms: []
    )

    static let friend1 = User(
        id: "friend-1",
        nickname: "Friend One",
        profilePhotoUrl: "https://example.com/friend1.jpg",
        friendIds: ["current-user-123"],
        chatRooms: []
    )

    static let friend2 = User(
        id: "friend-2",
        nickname: "Friend Two",
        profilePhotoUrl: "https://example.com/friend2.jpg",
        friendIds: ["current-user-123"],
        chatRooms: []
    )

    static let stranger = User(
        id: "stranger-1",
        nickname: "Stranger",
        profilePhotoUrl: "https://example.com/stranger.jpg",
        friendIds: [],
        chatRooms: []
    )

    static let searchResult1 = User(
        id: "search-1",
        nickname: "Search Result 1",
        profilePhotoUrl: nil,
        friendIds: [],
        chatRooms: []
    )

    static let searchResult2 = User(
        id: "search-2",
        nickname: "Search Result 2",
        profilePhotoUrl: "https://example.com/search2.jpg",
        friendIds: [],
        chatRooms: []
    )

    static let friends: [User] = [friend1, friend2]
    static let searchResults: [User] = [searchResult1, searchResult2]
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError, Equatable {
    case networkError
    case serverError
    case notFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .serverError:
            return "Server error occurred"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
