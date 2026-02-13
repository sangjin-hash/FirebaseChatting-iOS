//
//  ChatRoomPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct ChatRoomPage {
    let app: XCUIApplication

    // MARK: - Elements

    var messageInput: XCUIElement { app.textFields["chatroom_message_input"] }
    var sendButton: XCUIElement { app.buttons["chatroom_send_button"] }
    var mediaButton: XCUIElement { app.buttons["chatroom_media_button"] }
    var drawerButton: XCUIElement { app.buttons["chatroom_drawer_button"] }
    var loadingMore: XCUIElement { app.activityIndicators["chatroom_loading_more"] }
    var loadingNewer: XCUIElement { app.activityIndicators["chatroom_loading_newer"] }
    var dateSeparator: XCUIElement { app.staticTexts["chatroom_date_separator"] }
    var unreadDivider: XCUIElement { app.staticTexts["chatroom_unread_divider"] }
    var mediaPreview: XCUIElement { app.otherElements["chatroom_media_preview"] }
    var uploadingGrid: XCUIElement { app.descendants(matching: .any)["chatroom_uploading_grid"].firstMatch }

    func message(_ messageId: String) -> XCUIElement {
        let identifier = "chatroom_message_\(messageId)"
        return app.descendants(matching: .any)[identifier].firstMatch
    }

    func mediaThumb(_ index: Int) -> XCUIElement {
        app.images["chatroom_media_thumb_\(index)"]
    }

    func mediaRemoveButton(_ index: Int) -> XCUIElement {
        app.buttons["chatroom_media_remove_\(index)"]
    }

    // MARK: - Actions

    func typeMessage(_ text: String) {
        messageInput.tap()
        messageInput.typeText(text)
    }

    func tapSend() {
        sendButton.tap()
    }

    func sendMessage(_ text: String) {
        typeMessage(text)
        tapSend()
    }

    func tapMedia() {
        mediaButton.tap()
    }

    func tapDrawer() {
        drawerButton.tap()
    }

    func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func scrollToTop() {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeDown()
        scrollView.swipeDown()
    }

    func scrollToBottom() {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        scrollView.swipeUp()
    }

    // MARK: - Media Viewer

    var imageViewer: XCUIElement { app.descendants(matching: .any)["image_viewer"].firstMatch }
    var videoPlayer: XCUIElement { app.descendants(matching: .any)["video_player"].firstMatch }

    func dismissViewer() {
        let viewer = imageViewer.exists ? imageViewer : videoPlayer
        let start = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func assertImageViewerVisible() {
        XCTAssertTrue(imageViewer.waitForExistence(timeout: 3), "Image viewer should be visible")
    }

    func assertVideoPlayerVisible() {
        XCTAssertTrue(videoPlayer.waitForExistence(timeout: 3), "Video player should be visible")
    }

    // MARK: - Assertions

    func assertMessageExists(_ messageId: String) {
        XCTAssertTrue(
            message(messageId).waitForExistence(timeout: 5),
            "Message \(messageId) should exist"
        )
    }

    func assertMessageContains(_ text: String) {
        XCTAssertTrue(
            app.staticTexts[text].exists || app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", text)
            ).count > 0,
            "Message containing '\(text)' should exist"
        )
    }

    func assertDateSeparatorExists() {
        // identifier가 Text에 적용되어 있으므로 staticTexts에서 검색
        let separator = app.staticTexts["chatroom_date_separator"]
        XCTAssertTrue(
            separator.waitForExistence(timeout: 5),
            "At least one date separator should exist"
        )
    }

    func assertUnreadDividerExists() {
        // staticTexts로 못 찾을 경우 descendants로 재시도
        let found = unreadDivider.waitForExistence(timeout: 5)
            || app.descendants(matching: .any)["chatroom_unread_divider"].firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(found, "Unread divider should exist")
    }

    func assertInputCleared() {
        let value = messageInput.value as? String ?? ""
        // SwiftUI TextField은 비어있을 때 placeholder를 value로 반환
        let isCleared = value.isEmpty || value == "메시지를 입력하세요"
        XCTAssertTrue(isCleared, "Input should be cleared after send, got: '\(value)'")
    }
}
