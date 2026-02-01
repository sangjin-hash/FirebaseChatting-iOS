//
//  MessageResponseDTO.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore

// MARK: - MessageResponseDTO

struct MessageResponseDTO {
    let id: String
    let index: Int
    let senderId: String
    let type: String
    let content: String?
    let mediaUrls: [String]
    let createdAt: Timestamp
    let leftUserId: String?
    let leftUserNickname: String?

    // MARK: - Parsing

    static func from(document: DocumentSnapshot) throws -> MessageResponseDTO {
        guard let data = document.data() else {
            throw NSError(
                domain: "MessageResponseDTO",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Document data is nil"]
            )
        }

        return MessageResponseDTO(
            id: document.documentID,
            index: data["index"] as? Int ?? 0,
            senderId: data["senderId"] as? String ?? "",
            type: data["type"] as? String ?? "text",
            content: data["content"] as? String,
            mediaUrls: data["mediaUrls"] as? [String] ?? [],
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(),
            leftUserId: data["leftUserId"] as? String,
            leftUserNickname: data["leftUserNickname"] as? String
        )
    }

    // MARK: - Conversion

    func toModel() -> Message {
        let messageType = MessageType(rawValue: type) ?? .text

        return Message(
            id: id,
            index: index,
            senderId: senderId,
            type: messageType,
            content: content,
            mediaUrls: mediaUrls,
            createdAt: createdAt.dateValue(),
            leftUserId: leftUserId,
            leftUserNickname: leftUserNickname
        )
    }
}
