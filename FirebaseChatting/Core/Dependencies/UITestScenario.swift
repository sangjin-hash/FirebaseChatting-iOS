//
//  UITestScenario.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

enum UITestScenario: String {
    // ChatList
    case chatListBasic
    case chatListDisplay
    case chatListRealtime

    // ChatRoom
    case chatRoomPagination
    case chatRoomSend
    case chatRoomGroup
    case chatRoomMediaSend
    case chatRoomMediaViewer
    case chatRoomUnreadDivider

    static var current: UITestScenario {
        let args = ProcessInfo.processInfo.arguments
        for arg in args {
            if arg.hasPrefix("-Scenario_"),
               let scenario = UITestScenario(rawValue: String(arg.dropFirst(10))) {
                return scenario
            }
        }
        return .chatListBasic
    }
}
