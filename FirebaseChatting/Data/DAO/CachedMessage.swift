//
//  CachedMessage.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import SwiftData

// MARK: - CachedMessage

@Model
final class CachedMessage {
    #Unique<CachedMessage>([\.messageId])
    #Index<CachedMessage>([\.chatRoomId, \.createdAt])

    var messageId: String
    var chatRoomId: String
    var index: Int?
    var senderId: String
    var type: String               // "text", "image", "video", "system"
    var content: String?
    var mediaUrls: [String]
    var createdAt: Date
    var leftUserId: String?
    var leftUserNickname: String?

    init(
        messageId: String,
        chatRoomId: String,
        index: Int?,
        senderId: String,
        type: String,
        content: String?,
        mediaUrls: [String],
        createdAt: Date,
        leftUserId: String?,
        leftUserNickname: String?
    ) {
        self.messageId = messageId
        self.chatRoomId = chatRoomId
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

// MARK: - Conversion

extension CachedMessage {
    convenience init(from message: Message, chatRoomId: String) {
        self.init(
            messageId: message.id,
            chatRoomId: chatRoomId,
            index: message.index,
            senderId: message.senderId,
            type: message.type.rawValue,
            content: message.content,
            mediaUrls: message.mediaUrls,
            createdAt: message.createdAt,
            leftUserId: message.leftUserId,
            leftUserNickname: message.leftUserNickname
        )
    }

    func toMessage() -> Message {
        Message(
            id: messageId,
            index: index,
            senderId: senderId,
            type: MessageType(rawValue: type) ?? .text,
            content: content,
            mediaUrls: mediaUrls,
            createdAt: createdAt,
            leftUserId: leftUserId,
            leftUserNickname: leftUserNickname
        )
    }
}
