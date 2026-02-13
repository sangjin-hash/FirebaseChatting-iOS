//
//  ChatRoomSendUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatRoomSendUITests: UITestBaseCase {

    // 메시지 전송 → 렌더링 + ChatList lastMessage 확인
    func test_scenario3_normalSend() {
        launchApp(scenario: "chatRoomSend")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)
        let chatRoom = ChatRoomPage(app: app)

        // 1. 채팅방 진입 → 기존 메시지 표시
        waitForElement(chatList.room("D_current-user-123_friend-1"))
        chatList.tapRoom("D_current-user-123_friend-1")
        waitForElement(chatRoom.messageInput)
        sleep(1)

        // 2. "안녕하세요" 입력 → 전송
        chatRoom.typeMessage("안녕하세요")
        chatRoom.tapSend()

        // 3. 입력 필드 클리어 확인
        sleep(1)
        chatRoom.assertInputCleared()

        // 4. 전송한 메시지가 채팅방에 렌더링되는지 확인
        chatRoom.assertMessageContains("안녕하세요")

        // 5. 뒤로가기 → ChatList로 이동
        chatRoom.goBack()
        waitForElement(chatList.room("D_current-user-123_friend-1"))

        // 6. 해당 채팅방의 lastMessage가 "안녕하세요"로 변경되었는지 확인
        sleep(1)
        chatList.assertLastMessage("D_current-user-123_friend-1", text: "안녕하세요")
    }
}
