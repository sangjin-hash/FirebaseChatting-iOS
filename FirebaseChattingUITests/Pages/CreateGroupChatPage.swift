//
//  CreateGroupChatPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct CreateGroupChatPage {
    let app: XCUIApplication

    var createButton: XCUIElement { app.buttons["create_group_create_button"] }
    var cancelButton: XCUIElement { app.buttons["create_group_cancel_button"] }
    var selectionCount: XCUIElement { app.staticTexts["create_group_selection_count"] }

    func friend(_ friendId: String) -> XCUIElement {
        app.buttons["create_group_friend_\(friendId)"]
    }

    func selectFriend(_ friendId: String) {
        friend(friendId).tap()
    }

    func tapCreate() {
        createButton.tap()
    }

    func tapCancel() {
        cancelButton.tap()
    }

    func assertCreateEnabled() {
        XCTAssertTrue(createButton.isEnabled, "Create button should be enabled")
    }

    func assertCreateDisabled() {
        XCTAssertFalse(createButton.isEnabled, "Create button should be disabled")
    }
}
