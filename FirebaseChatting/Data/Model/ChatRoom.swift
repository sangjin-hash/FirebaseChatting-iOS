//
//  ChatRoom.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - ChatRoom

struct ChatRoom: Equatable, Sendable, Codable, Identifiable {
    var id: String                      // "D_{uid1}_{uid2}" or "G_{randomId}"
    var type: ChatRoomType
    var lastMessage: String?
    var lastMessageAt: Date?
    var index: Int                      // 전체 메시지 인덱스
    var userHistory: [String]           // 참여했던 유저 기록
    var activeUsers: [String: Date]     // 현재 참여 중인 유저 (userId: joinedAt)

    init(
        id: String,
        type: ChatRoomType,
        lastMessage: String? = nil,
        lastMessageAt: Date? = nil,
        index: Int = 0,
        userHistory: [String] = [],
        activeUsers: [String: Date] = [:]
    ) {
        self.id = id
        self.type = type
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.index = index
        self.userHistory = userHistory
        self.activeUsers = activeUsers
    }
}

// MARK: - ChatRoomType

enum ChatRoomType: String, Codable, Sendable {
    case direct
    case group
}

// MARK: - Business Logic

extension ChatRoom {
    /// 1:1 채팅방 ID 생성 (정렬된 uid로 고유성 보장)
    static func directChatRoomId(uid1: String, uid2: String) -> String {
        let sorted = [uid1, uid2].sorted()
        return "D_\(sorted[0])_\(sorted[1])"
    }

    /// 그룹 채팅방 ID 생성 (UUID 기반)ㅊ
    static func groupChatRoomId() -> String {
        "G_\(UUID().uuidString)"
    }

    /// 상대방 userId 반환 (1:1 채팅용)
    func otherUserId(myUserId: String) -> String? {
        guard type == .direct else { return nil }
        return activeUsers.keys.first { $0 != myUserId }
    }
}
