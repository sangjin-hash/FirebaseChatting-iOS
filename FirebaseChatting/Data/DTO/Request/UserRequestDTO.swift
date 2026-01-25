//
//  UserRequestDTO.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - Empty Request

struct EmptyDataRequest: Encodable, Sendable {
    let data: EmptyData
    struct EmptyData: Encodable, Sendable {}

    init() {
        self.data = EmptyData()
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
