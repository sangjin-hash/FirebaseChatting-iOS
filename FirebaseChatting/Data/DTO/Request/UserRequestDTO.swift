//
//  UserRequestDTO.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - Get Friends Request

struct GetFriendsRequest: Encodable, Sendable {
    let data: Data
    struct Data: Encodable, Sendable {
        let friendIds: [String]
    }

    init(friendIds: [String]) {
        self.data = Data(friendIds: friendIds)
    }
}

// MARK: - Get User Batch Request

struct GetUserBatchRequest: Encodable, Sendable {
    let data: Data
    struct Data: Encodable, Sendable {
        let chatRooms: [String]
    }

    init(chatRooms: [String]) {
        self.data = Data(chatRooms: chatRooms)
    }
}

// MARK: - Search Users Request

struct SearchUsersRequest: Encodable, Sendable {
    let data: Data
    struct Data: Encodable, Sendable {
        let query: String
    }

    init(query: String) {
        self.data = Data(query: query)
    }
}

// MARK: - Add Friend Request

struct AddFriendRequest: Encodable, Sendable {
    let data: Data
    struct Data: Encodable, Sendable {
        let friendId: String
    }

    init(friendId: String) {
        self.data = Data(friendId: friendId)
    }
}
