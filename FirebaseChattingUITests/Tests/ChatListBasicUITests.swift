//
//  ChatListBasicUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatListBasicUITests: UITestBaseCase {

    // MARK: - 시나리오 1: 기본 흐름 (로드/진입/복귀)

    func test_scenario1_chatList_basicFlow() {
        launchApp(scenario: "chatListBasic")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)

        // 1. 목록 2개 표시 확인
        waitForElement(chatList.room("D_current-user-123_friend-1"))
        chatList.assertRoomCount(2)

        // 2. 채팅방 진입
        chatList.tapRoom("D_current-user-123_friend-1")
        let chatRoom = ChatRoomPage(app: app)
        waitForElement(chatRoom.messageInput)

        // 3. 뒤로가기 → 복귀
        chatRoom.goBack()
        waitForElement(chatList.room("D_current-user-123_friend-1"))
        chatList.assertRoomCount(2)
    }
}
