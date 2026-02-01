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

    static let currentUserWithNewFriend = User(
        id: "current-user-123",
        nickname: "Current User",
        profilePhotoUrl: "https://example.com/current.jpg",
        friendIds: ["friend-1", "friend-2", "search-1"],
        chatRooms: ["chatroom-1"]
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

    // MARK: - Profiles (API 응답용)

    static let friend1Profile = Profile(
        id: "friend-1",
        nickname: "Friend One",
        profilePhotoUrl: "https://example.com/friend1.jpg"
    )

    static let friend2Profile = Profile(
        id: "friend-2",
        nickname: "Friend Two",
        profilePhotoUrl: "https://example.com/friend2.jpg"
    )

    static let searchResult1Profile = Profile(
        id: "search-1",
        nickname: "Search Result 1",
        profilePhotoUrl: nil
    )

    static let searchResult2Profile = Profile(
        id: "search-2",
        nickname: "Search Result 2",
        profilePhotoUrl: "https://example.com/search2.jpg"
    )

    static let strangerProfile = Profile(
        id: "stranger-1",
        nickname: "Stranger",
        profilePhotoUrl: "https://example.com/stranger.jpg"
    )

    static let friendProfiles: [Profile] = [friend1Profile, friend2Profile]
    static let searchResultProfiles: [Profile] = [searchResult1Profile, searchResult2Profile]

    // MARK: - ChatRooms

    static let chatRoom1 = ChatRoom(
        id: "chatroom-1",
        type: .direct,
        lastMessage: "안녕하세요!",
        lastMessageAt: Date(),
        index: 5,
        userHistory: ["current-user-123", "friend-1"],
        activeUsers: ["current-user-123": Date(), "friend-1": Date()]
    )

    static let chatRoom2 = ChatRoom(
        id: "chatroom-2",
        type: .direct,
        lastMessage: "오늘 시간 되세요?",
        lastMessageAt: Date().addingTimeInterval(-3600),
        index: 10,
        userHistory: ["current-user-123", "friend-2"],
        activeUsers: ["current-user-123": Date(), "friend-2": Date()]
    )

    // MARK: - Group ChatRooms

    /// 3명 이상의 그룹 채팅방 (닉네임 외 N명 표시)
    static let groupChatRoom1 = ChatRoom(
        id: "G_group123",
        type: .group,
        lastMessage: "모임 시간 정해주세요~",
        lastMessageAt: Date(),
        index: 25,
        userHistory: ["current-user-123", "friend-1", "friend-2"],
        activeUsers: [
            "current-user-123": Date(),
            "friend-1": Date(),
            "friend-2": Date()
        ]
    )

    /// 2명의 그룹 채팅방 (닉네임만 표시)
    static let groupChatRoom2TwoUsers = ChatRoom(
        id: "G_group456",
        type: .group,
        lastMessage: "확인했습니다",
        lastMessageAt: Date().addingTimeInterval(-1800),
        index: 30,
        userHistory: ["current-user-123", "friend-1"],
        activeUsers: [
            "current-user-123": Date(),
            "friend-1": Date()
        ]
    )

    static let chatRooms: [ChatRoom] = [chatRoom1, chatRoom2]
    static let chatRoomsWithGroup: [ChatRoom] = [chatRoom1, chatRoom2, groupChatRoom1, groupChatRoom2TwoUsers]

    // MARK: - Additional Friends for Group Chat Testing

    static let friend3Profile = Profile(
        id: "friend-3",
        nickname: "Friend Three",
        profilePhotoUrl: "https://example.com/friend3.jpg"
    )

    static let friend4Profile = Profile(
        id: "friend-4",
        nickname: "Friend Four",
        profilePhotoUrl: nil
    )

    static let allFriends: [Profile] = [friend1Profile, friend2Profile, friend3Profile, friend4Profile]

    /// 초대 가능한 친구 (그룹 채팅방에 없는 친구)
    static let invitableFriends: [Profile] = [friend3Profile, friend4Profile]

    // MARK: - ChatRoom Profiles (chatRoomId → Profile)

    static let chatRoomProfiles: [String: Profile] = [
        "chatroom-1": friend1Profile,
        "chatroom-2": friend2Profile,
        "G_group123": friend1Profile,
        "G_group456": friend1Profile
    ]

    // MARK: - Messages

    static let message1 = Message(
        id: "msg-1",
        index: 1,
        senderId: "current-user-123",
        type: .text,
        content: "안녕하세요!",
        createdAt: Date().addingTimeInterval(-3600)
    )

    static let message2 = Message(
        id: "msg-2",
        index: 2,
        senderId: "friend-1",
        type: .text,
        content: "반갑습니다!",
        createdAt: Date().addingTimeInterval(-1800)
    )

    static let message3 = Message(
        id: "msg-3",
        index: 3,
        senderId: "current-user-123",
        type: .text,
        content: "오늘 날씨가 좋네요",
        createdAt: Date()
    )

    static let systemMessage = Message(
        id: "msg-system-1",
        index: 10,
        senderId: "system",
        type: .system,
        content: "Friend One님이 나가셨습니다",
        createdAt: Date()
    )

    /// 나간 사용자 정보를 포함한 시스템 메시지
    static let systemMessageWithLeftUser = Message(
        id: "msg-system-2",
        index: 11,
        senderId: "system",
        type: .system,
        content: "Friend Two님이 나갔습니다",
        createdAt: Date(),
        leftUserId: "friend-2",
        leftUserNickname: "Friend Two"
    )

    static let messages: [Message] = [message1, message2, message3]

    static let olderMessages: [Message] = [
        Message(
            id: "msg-old-1",
            index: -2,
            senderId: "friend-1",
            type: .text,
            content: "이전 메시지 1",
            createdAt: Date().addingTimeInterval(-7200)
        ),
        Message(
            id: "msg-old-2",
            index: -1,
            senderId: "current-user-123",
            type: .text,
            content: "이전 메시지 2",
            createdAt: Date().addingTimeInterval(-5400)
        )
    ]

    static let newerMessages: [Message] = [
        Message(
            id: "msg-new-1",
            index: 4,
            senderId: "friend-1",
            type: .text,
            content: "최신 메시지 1",
            createdAt: Date().addingTimeInterval(1800)
        ),
        Message(
            id: "msg-new-2",
            index: 5,
            senderId: "current-user-123",
            type: .text,
            content: "최신 메시지 2",
            createdAt: Date().addingTimeInterval(3600)
        )
    ]

    // MARK: - User with multiple chatRooms

    static let currentUserWithMultipleChatRooms = User(
        id: "current-user-123",
        nickname: "Current User",
        profilePhotoUrl: "https://example.com/current.jpg",
        friendIds: ["friend-1", "friend-2"],
        chatRooms: ["chatroom-1", "chatroom-2"]
    )
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
