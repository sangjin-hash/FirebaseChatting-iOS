//
//  ChatRoomMessageUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatRoomMessageUITests: UITestBaseCase {

    // UnreadDivider + 스크롤 + 페이지네이션 통합 시나리오
    // 채팅방 진입 → 캐시된 메시지 + Divider 하단 위치 → 아래 스크롤 → 새 메시지
    func test_scenario2_unreadDivider() {
        launchApp(scenario: "chatRoomUnreadDivider")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)
        let chatRoom = ChatRoomPage(app: app)

        // ChatList에서 채팅방 진입
        waitForElement(chatList.room("D_current-user-123_friend-1"))
        chatList.tapRoom("D_current-user-123_friend-1")

        // 1. 메시지 입력 필드 확인 (채팅방 진입 완료)
        waitForElement(chatRoom.messageInput)

        // 2. 메시지 로드 대기 (캐시 10개 + 1차 fetchNewerMessages 30개 → divider로 스크롤)
        sleep(5)

        // 3. UnreadDivider 확인 (Divider가 화면 하단에 위치해야 함)
        chatRoom.assertUnreadDividerExists()

        // 4. 위로 스크롤 → 캐시된 과거 메시지 확인 (divider 위에 위치)
        chatRoom.scrollToTop()
        sleep(1)
        chatRoom.assertMessageContains("메시지 #1")

        // 5. 아래로 스크롤 → 새 메시지 영역으로 이동 (divider 지나침)
        chatRoom.scrollToBottom()
        sleep(1)

        // 6. 계속 아래로 스크롤 → 페이지네이션 트리거 (loadNewerMessages: 2차 fetch 20개)
        chatRoom.scrollToBottom()
        sleep(2)

        // 7. 최종 새 메시지 "새 메시지 #60" 확인 (2차 fetch: index 41~60)
        chatRoom.scrollToBottom()
        sleep(1)
        chatRoom.assertMessageContains("새 메시지 #60")
    }
}
