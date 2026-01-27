//
//  UserResponseDTO.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - Get Friends Response

struct GetFriendsResponse: Decodable, Sendable {
    let result: Result

    struct Result: Decodable, Sendable {
        let profiles: [Profile]
    }
}

// MARK: - Get User Batch Response

struct GetUserBatchResponse: Decodable, Sendable {
    let result: Result

    struct Result: Decodable, Sendable {
        let profiles: [String: Profile]
    }
}

// MARK: - Search Users Response

struct SearchUsersResponse: Decodable, Sendable {
    let result: Result

    struct Result: Decodable, Sendable {
        let users: [Profile]
    }
}
