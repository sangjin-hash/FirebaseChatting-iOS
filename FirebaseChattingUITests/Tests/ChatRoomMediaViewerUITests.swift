//
//  ChatRoomMediaViewerUITests.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

final class ChatRoomMediaViewerUITests: UITestBaseCase {

    /// 미디어 메시지 렌더링 + 이미지/비디오 뷰어 인터랙션 검증
    func test_scenario6_mediaViewerInteraction() {
        launchApp(scenario: "chatRoomMediaViewer")
        sleep(5)
        navigateToChatTab()
        sleep(3)

        let chatList = ChatListPage(app: app)
        let chatRoom = ChatRoomPage(app: app)

        // 1. 채팅방 진입
        waitForElement(chatList.room("D_current-user-123_friend-1"), timeout: 10)
        chatList.tapRoom("D_current-user-123_friend-1")
        waitForElement(chatRoom.messageInput, timeout: 10)
        sleep(2)

        // 2. 이미지 미디어 그리드 셀 존재 확인 (3장 이미지 메시지)
        let mediaCell0 = app.descendants(matching: .any)["media_grid_cell_0"].firstMatch
        XCTAssertTrue(mediaCell0.waitForExistence(timeout: 5), "미디어 그리드 첫 번째 셀이 존재해야 합니다")

        // 3. 이미지 셀 탭 → FullScreenImageViewer 확인
        mediaCell0.tap()
        sleep(2)

        // 이미지 뷰어 표시 확인 (descendants로 검색)
        XCTAssertTrue(chatRoom.imageViewer.waitForExistence(timeout: 5), "이미지 뷰어가 표시되어야 합니다")
        chatRoom.dismissViewer()
        sleep(2)

        // 4. 비디오 썸네일 버튼 존재 확인
        let videoButton = app.descendants(matching: .any)["video_thumbnail_button"].firstMatch
        XCTAssertTrue(videoButton.waitForExistence(timeout: 5), "비디오 썸네일 버튼이 존재해야 합니다")

        // 5. 비디오 버튼 탭 → VideoPlayer 확인
        videoButton.tap()
        sleep(2)

        XCTAssertTrue(chatRoom.videoPlayer.waitForExistence(timeout: 5), "비디오 플레이어가 표시되어야 합니다")
        chatRoom.dismissViewer()
        sleep(2)

        // 6. 채팅방 UI 정상 확인
        XCTAssertTrue(chatRoom.messageInput.waitForExistence(timeout: 5), "메시지 입력 필드가 존재해야 합니다")
    }
}
