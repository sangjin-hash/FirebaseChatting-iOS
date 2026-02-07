//
//  CachedChatRoomIndex.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import SwiftData

// MARK: - CachedChatRoomIndex

@Model
final class CachedChatRoomIndex {
    #Unique<CachedChatRoomIndex>([\.chatRoomId])

    var chatRoomId: String
    var lastReadIndex: Int
    var lastCachedCreatedAt: Date?

    init(
        chatRoomId: String,
        lastReadIndex: Int = 0,
        lastCachedCreatedAt: Date? = nil
    ) {
        self.chatRoomId = chatRoomId
        self.lastReadIndex = lastReadIndex
        self.lastCachedCreatedAt = lastCachedCreatedAt
    }
}
