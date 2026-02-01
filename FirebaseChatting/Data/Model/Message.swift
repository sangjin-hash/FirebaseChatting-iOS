//
//  Message.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

// MARK: - Message

struct Message: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var index: Int
    var senderId: String
    var type: MessageType
    var content: String?              // 텍스트 또는 시스템 메시지 내용
    var mediaUrls: [String]           // 미디어 URL 목록
    var createdAt: Date

    // 시스템 메시지용 메타데이터 (나간 사용자 정보)
    var leftUserId: String?           // 나간 사용자 ID (재초대용)
    var leftUserNickname: String?     // 나간 사용자 닉네임

    init(
        id: String,
        index: Int,
        senderId: String,
        type: MessageType,
        content: String? = nil,
        mediaUrls: [String] = [],
        createdAt: Date = Date(),
        leftUserId: String? = nil,
        leftUserNickname: String? = nil
    ) {
        self.id = id
        self.index = index
        self.senderId = senderId
        self.type = type
        self.content = content
        self.mediaUrls = mediaUrls
        self.createdAt = createdAt
        self.leftUserId = leftUserId
        self.leftUserNickname = leftUserNickname
    }
}

// MARK: - MessageType

enum MessageType: String, Codable, Sendable {
    case text
    case image
    case video
    case system
}

// MARK: - Business Logic

extension Message {
    /// 내 메시지인지 확인
    func isMine(myUserId: String) -> Bool {
        senderId == myUserId
    }

    /// 시스템 메시지인지 확인
    var isSystemMessage: Bool {
        type == .system
    }

    /// 미디어 메시지인지 확인
    var isMediaMessage: Bool {
        type == .image || type == .video
    }
}
