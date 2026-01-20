//
//  MainTabType.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation

enum MainTabType: String, CaseIterable {
    case home
    case chat
    
    var title: String {
        switch self {
        case .home:
            return "홈"
        case .chat:
            return "채팅"
        }
    }
    
    func imageName(selected: Bool) -> String {
        selected ? "\(rawValue)_fill" : rawValue
    }
}
