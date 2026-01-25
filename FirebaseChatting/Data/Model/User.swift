//
//  User.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

struct User: Equatable, Sendable, Codable {
    var id: String
    var nickname: String?
    var profilePhotoUrl: String?
    var friendIds: [String]
    var chatRooms: [String]

    init(
        id: String,
        nickname: String? = nil,
        profilePhotoUrl: String? = nil,
        friendIds: [String] = [],
        chatRooms: [String] = []
    ) {
        self.id = id
        self.nickname = nickname
        self.profilePhotoUrl = profilePhotoUrl
        self.friendIds = friendIds
        self.chatRooms = chatRooms
    }
}
