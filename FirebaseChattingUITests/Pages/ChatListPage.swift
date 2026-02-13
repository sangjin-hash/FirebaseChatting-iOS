//
//  ChatListPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct ChatListPage {
    let app: XCUIApplication

    // MARK: - Elements

    var roomList: XCUIElement { app.otherElements["chatlist_rooms"] }
    var createGroupButton: XCUIElement { app.buttons["chatlist_create_group_button"] }
    var emptyState: XCUIElement { app.otherElements["chatlist_empty_state"] }
    var titleElement: XCUIElement { app.staticTexts["chatlist_title"] }

    func room(_ chatRoomId: String) -> XCUIElement {
        app.buttons["chatlist_room_\(chatRoomId)"]
    }

    func unreadBadge(_ chatRoomId: String) -> XCUIElement {
        app.staticTexts["chatlist_unread_\(chatRoomId)"]
    }

    func leaveButton() -> XCUIElement {
        app.buttons["chatlist_leave_button"]
    }

    // MARK: - Actions

    func tapRoom(_ chatRoomId: String) {
        room(chatRoomId).tap()
    }

    func swipeToLeave(_ chatRoomId: String) {
        room(chatRoomId).swipeLeft()
    }

    func tapCreateGroup() {
        createGroupButton.tap()
    }

    func triggerRealtimeEvent() {
        titleElement.tap()
        titleElement.tap()
        titleElement.tap()
    }

    // MARK: - Assertions

    func assertRoomCount(_ count: Int) {
        let rooms = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'chatlist_room_'")
        )
        XCTAssertEqual(rooms.count, count, "Expected \(count) rooms but found \(rooms.count)")
    }

    func assertUnread(_ chatRoomId: String, count: String) {
        let badge = unreadBadge(chatRoomId)
        XCTAssertTrue(badge.exists, "Unread badge not found for \(chatRoomId)")
        XCTAssertEqual(badge.label, count, "Expected unread count '\(count)' but got '\(badge.label)'")
    }

    func assertNoUnread(_ chatRoomId: String) {
        let badge = unreadBadge(chatRoomId)
        XCTAssertFalse(badge.exists, "Unread badge should not exist for \(chatRoomId)")
    }

    func assertEmptyState() {
        XCTAssertTrue(emptyState.exists, "Empty state should be visible")
    }

    func assertDisplayName(_ chatRoomId: String, contains text: String) {
        let roomElement = room(chatRoomId)
        let staticTexts = roomElement.staticTexts
        var found = false
        for i in 0..<staticTexts.count {
            if staticTexts.element(boundBy: i).label.contains(text) {
                found = true
                break
            }
        }
        XCTAssertTrue(found || roomElement.label.contains(text), "Room should display '\(text)'")
    }

    func assertLastMessage(_ chatRoomId: String, text: String) {
        let roomElement = room(chatRoomId)
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let matchingTexts = roomElement.staticTexts.matching(predicate)
        XCTAssertTrue(
            matchingTexts.count > 0 || roomElement.label.contains(text),
            "Room \(chatRoomId) should show last message '\(text)'"
        )
    }
}
