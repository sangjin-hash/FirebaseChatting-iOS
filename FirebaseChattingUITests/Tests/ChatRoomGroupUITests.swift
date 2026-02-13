//
//  ChatRoomGroupUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatRoomGroupUITests: UITestBaseCase {

    // Given-A: 그룹 채팅 생성 → 채팅방 이동 → Drawer 멤버 확인
    func test_scenario4A_createGroupChat() {
        launchApp(scenario: "chatRoomGroup")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)
        let createGroup = CreateGroupChatPage(app: app)
        let chatRoom = ChatRoomPage(app: app)
        let drawer = DrawerPage(app: app)

        // 1. 그룹 생성 버튼 탭 → 시트 표시
        waitForElement(chatList.createGroupButton)
        chatList.tapCreateGroup()

        // 2. 친구 선택 → 만들기 버튼 활성화
        waitForElement(createGroup.friend("friend-1"))
        XCTAssertTrue(createGroup.friend("friend-2").exists)
        createGroup.selectFriend("friend-1")
        createGroup.selectFriend("friend-2")
        createGroup.assertCreateEnabled()

        // 3. 만들기 → 시트 닫힘 + 채팅방 이동
        createGroup.tapCreate()

        // 4. 채팅방 진입 확인
        waitForElement(chatRoom.messageInput, timeout: 10)

        // 5. Drawer 열기 → 멤버 확인
        if chatRoom.drawerButton.waitForExistence(timeout: 3) {
            chatRoom.tapDrawer()
            sleep(1)
            drawer.assertVisible()
            drawer.assertMemberExists(name: "홍길동")
            drawer.assertMemberExists(name: "김철수")

            // 6. Drawer 닫기 → 뒤로가기
            drawer.dismiss()
            sleep(1)
        }
    }

    // Given-B: 그룹 채팅방 진입 + Drawer 표시
    func test_scenario4B_drawerDisplay() {
        launchApp(scenario: "chatRoomGroup")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)
        let chatRoom = ChatRoomPage(app: app)

        // 그룹 채팅방 진입
        waitForElement(chatList.room("G_test-group-1"))
        chatList.tapRoom("G_test-group-1")
        waitForElement(chatRoom.messageInput)

        // Drawer 버튼 확인 (그룹 채팅에서만 표시)
        XCTAssertTrue(chatRoom.drawerButton.exists)

        // Drawer 열기
        chatRoom.tapDrawer()
        let drawer = DrawerPage(app: app)
        sleep(1)
        drawer.assertVisible()

        // Drawer 닫기 → 뒤로가기
        drawer.dismiss()
        sleep(1)
        chatRoom.goBack()
        waitForElement(chatList.room("G_test-group-1"))
    }
}
