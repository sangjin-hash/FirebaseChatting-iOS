//
//  MockDataFactory.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

enum MockDataFactory {

    // MARK: - Users

    static let currentUser = Profile(
        id: "current-user-123",
        nickname: "나",
        profilePhotoUrl: nil
    )

    static let friend1 = Profile(id: "friend-1", nickname: "홍길동", profilePhotoUrl: "https://example.com/hong.jpg")
    static let friend2 = Profile(id: "friend-2", nickname: "김철수", profilePhotoUrl: "https://example.com/kim.jpg")
    static let friend3 = Profile(id: "friend-3", nickname: "이영희", profilePhotoUrl: nil)
    static let invitableFriend1 = Profile(id: "invite-1", nickname: "박민수", profilePhotoUrl: nil)
    static let invitableFriend2 = Profile(id: "invite-2", nickname: "정수진", profilePhotoUrl: nil)

    static let allFriends: [Profile] = [friend1, friend2, friend3, invitableFriend1, invitableFriend2]

    // MARK: - Chat Rooms

    static let directRoom = ChatRoom(
        id: "D_current-user-123_friend-1",
        type: .direct,
        lastMessage: "안녕하세요!",
        lastMessageAt: Date(),
        index: 60,
        userHistory: ["current-user-123", "friend-1"],
        activeUsers: ["current-user-123": Date.distantPast, "friend-1": Date.distantPast]
    )

    static let groupRoom = ChatRoom(
        id: "G_test-group-1",
        type: .group,
        lastMessage: "다들 모이세요!",
        lastMessageAt: Date(),
        index: 10,
        userHistory: ["current-user-123", "friend-1", "friend-2"],
        activeUsers: [
            "current-user-123": Date.distantPast,
            "friend-1": Date.distantPast,
            "friend-2": Date.distantPast
        ]
    )

    static let noParticipantRoom = ChatRoom(
        id: "D_current-user-123_friend-3",
        type: .direct,
        lastMessage: "...",
        lastMessageAt: Date().addingTimeInterval(-86400),
        index: 5,
        userHistory: ["current-user-123", "friend-3"],
        activeUsers: ["current-user-123": Date.distantPast]
    )

    // MARK: - Messages

    static func makeMessages(count: Int, chatRoomId: String, startIndex: Int = 1) -> [Message] {
        let now = Date()
        return (0..<count).map { i in
            let index = startIndex + i
            let isMe = i % 3 == 0
            let createdAt = now.addingTimeInterval(-Double(count - i) * 120)
            return Message(
                id: "\(chatRoomId)_msg_\(index)",
                index: index,
                senderId: isMe ? "current-user-123" : "friend-1",
                type: .text,
                content: "메시지 #\(index)",
                createdAt: createdAt
            )
        }
    }

    static func makeYesterdayMessages(count: Int, chatRoomId: String) -> [Message] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return (0..<count).map { i in
            Message(
                id: "\(chatRoomId)_yesterday_\(i)",
                index: i + 1,
                senderId: i % 2 == 0 ? "current-user-123" : "friend-1",
                type: .text,
                content: "어제 메시지 #\(i + 1)",
                createdAt: yesterday.addingTimeInterval(Double(i) * 60)
            )
        }
    }

    static func makeNewerMessages(count: Int, chatRoomId: String, startIndex: Int) -> [Message] {
        let now = Date()
        return (0..<count).map { i in
            let index = startIndex + i
            let isMe = i % 3 == 0
            let createdAt = now.addingTimeInterval(Double(index) * 60)
            return Message(
                id: "\(chatRoomId)_newer_\(index)",
                index: index,
                senderId: isMe ? "current-user-123" : "friend-1",
                type: .text,
                content: "새 메시지 #\(index)",
                createdAt: createdAt
            )
        }
    }

    static let imageMessage = Message(
        id: "media_img_1",
        index: 100,
        senderId: "friend-1",
        type: .image,
        content: nil,
        mediaUrls: [
            "https://picsum.photos/id/10/400/300",
            "https://picsum.photos/id/20/400/300",
            "https://picsum.photos/id/30/400/300"
        ],
        createdAt: Date()
    )

    static let videoMessage = Message(
        id: "media_vid_1",
        index: 101,
        senderId: "friend-1",
        type: .video,
        content: nil,
        mediaUrls: ["https://example.com/video.mp4"],
        createdAt: Date()
    )

    static func joinSystemMessage(nickname: String) -> Message {
        Message(
            id: "system_join_\(UUID().uuidString)",
            senderId: "system",
            type: .system,
            content: "\(nickname)님이 참여했습니다",
            createdAt: Date()
        )
    }

    static func leaveSystemMessage(userId: String, nickname: String) -> Message {
        Message(
            id: "system_leave_\(UUID().uuidString)",
            senderId: "system",
            type: .system,
            content: "\(nickname)님이 나갔습니다",
            createdAt: Date(),
            leftUserId: userId,
            leftUserNickname: nickname
        )
    }
}
