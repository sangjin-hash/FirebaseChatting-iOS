//
//  Profile.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

struct Profile: Equatable, Sendable, Codable, Identifiable {
    var id: String
    var nickname: String?
    var profilePhotoUrl: String?

    init(
        id: String,
        nickname: String? = nil,
        profilePhotoUrl: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.profilePhotoUrl = profilePhotoUrl
    }
}
