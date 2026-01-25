//
//  UserResponseDTO.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

// MARK: - Get User With Friends Response

struct GetUserWithFriendsResponse: Decodable, Sendable {
    let result: Result

    struct Result: Decodable, Sendable {
        let user: User
        let friends: [User]
    }
}

// MARK: - Search Users Response

struct SearchUsersResponse: Decodable, Sendable {
    let result: Result

    struct Result: Decodable, Sendable {
        let users: [User]
    }
}
