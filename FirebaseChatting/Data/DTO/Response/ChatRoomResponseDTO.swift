//
//  ChatRoomResponseDTO.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import FirebaseFirestore

// MARK: - ChatRoomResponseDTO

struct ChatRoomResponseDTO {
    let id: String
    let type: String
    let lastMessage: String?
    let lastMessageAt: Timestamp?
    let index: Int
    let userHistory: [String]
    let activeUsers: [String: Timestamp]

    // MARK: - Parsing

    static func from(document: DocumentSnapshot) throws -> ChatRoomResponseDTO {
        guard let data = document.data() else {
            throw NSError(domain: "ChatRoomResponseDTO", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document data is nil"])
        }

        return ChatRoomResponseDTO(
            id: document.documentID,
            type: data["type"] as? String ?? "direct",
            lastMessage: data["lastMessage"] as? String,
            lastMessageAt: data["lastMessageAt"] as? Timestamp,
            index: data["index"] as? Int ?? 0,
            userHistory: data["userHistory"] as? [String] ?? [],
            activeUsers: data["activeUsers"] as? [String: Timestamp] ?? [:]
        )
    }

    // MARK: - Conversion

    func toModel() -> ChatRoom {
        let chatRoomType = ChatRoomType(rawValue: type) ?? .direct

        var activeUsersDates: [String: Date] = [:]
        for (userId, timestamp) in activeUsers {
            activeUsersDates[userId] = timestamp.dateValue()
        }

        return ChatRoom(
            id: id,
            type: chatRoomType,
            lastMessage: lastMessage,
            lastMessageAt: lastMessageAt?.dateValue(),
            index: index,
            userHistory: userHistory,
            activeUsers: activeUsersDates
        )
    }
}
