//
//  ChatRoomMediaSendUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatRoomMediaSendUITests: UITestBaseCase {

    /// 미디어 버튼 탭 → PHPicker 모달 표시 확인
    ///
    /// PHPicker 이후 플로우(미디어 선택 → 업로드 → 프리뷰)는 XCUITest로 검증 불가:
    /// - PHPicker는 개인정보 보호를 위해 별도 시스템 프로세스에서 동작 (out-of-process picker)
    /// - XCUI 자동화로 피커 UI를 탭할 수는 있지만, 선택 결과가 앱의 SwiftUI 바인딩
    ///   ($selectedPhotosItems)으로 전달되지 않아 onChange 핸들러가 호출되지 않음
    /// - 이는 Apple 플랫폼의 구조적 제약으로, 실제 사용자 물리적 인터랙션에서만 동작함
    func test_scenario5_mediaPickerPresentation() {
        launchApp(scenario: "chatRoomMediaSend")
        navigateToChatTab()
        let chatList = ChatListPage(app: app)
        let chatRoom = ChatRoomPage(app: app)

        // 1. 채팅방 진입
        waitForElement(chatList.room("D_current-user-123_friend-1"))
        chatList.tapRoom("D_current-user-123_friend-1")
        waitForElement(chatRoom.messageInput)

        // 2. 미디어 버튼 존재 확인
        XCTAssertTrue(chatRoom.mediaButton.isHittable, "미디어 버튼이 탭 가능해야 합니다")

        // 3. 미디어 버튼 탭 → PHPicker 모달 표시
        chatRoom.tapMedia()

        // 4. PHPicker 모달 확인
        //    피커가 열리면 채팅방 미디어 버튼이 hittable=false가 됨
        let predicate = NSPredicate(format: "isHittable == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: chatRoom.mediaButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 10)
        XCTAssertEqual(result, .completed, "PHPicker 모달이 표시되어야 합니다")

        // 5. 스와이프 다운으로 피커 닫기 → 채팅방 복귀
        let topCenter = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let bottomCenter = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        topCenter.press(forDuration: 0.1, thenDragTo: bottomCenter)
        sleep(1)
        XCTAssertTrue(
            chatRoom.messageInput.waitForExistence(timeout: 5),
            "PHPicker 닫힌 후 채팅방으로 복귀해야 합니다"
        )
    }
}
