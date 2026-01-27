//
//  User.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

struct User: Equatable, Sendable, Codable {
    var profile: Profile
    var friendIds: [String]
    var chatRooms: [String]

    init(
        profile: Profile,
        friendIds: [String] = [],
        chatRooms: [String] = []
    ) {
        self.profile = profile
        self.friendIds = friendIds
        self.chatRooms = chatRooms
    }

    /// 편의 생성자
    init(
        id: String,
        nickname: String? = nil,
        profilePhotoUrl: String? = nil,
        friendIds: [String] = [],
        chatRooms: [String] = []
    ) {
        self.profile = Profile(
            id: id,
            nickname: nickname,
            profilePhotoUrl: profilePhotoUrl
        )
        self.friendIds = friendIds
        self.chatRooms = chatRooms
    }
}
