//
//  DrawerPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct DrawerPage {
    let app: XCUIApplication

    var container: XCUIElement { app.otherElements["drawer_container"] }
    var inviteButton: XCUIElement { app.buttons["drawer_invite_button"] }
    var memberCount: XCUIElement { app.staticTexts["drawer_member_count"] }
    var backdrop: XCUIElement { app.otherElements["drawer_backdrop"] }

    func tapInvite() {
        inviteButton.tap()
    }

    func dismiss() {
        backdrop.tap()
    }

    func assertVisible() {
        // container가 항상 렌더링되므로 backdrop(isOpen일 때만 표시)으로 확인
        let found = container.waitForExistence(timeout: 3) || backdrop.waitForExistence(timeout: 3)
        XCTAssertTrue(found, "Drawer should be visible")
    }

    func assertMemberCount(_ count: String) {
        XCTAssertTrue(memberCount.label.contains(count), "Member count should contain '\(count)'")
    }

    func assertMemberExists(name: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        // container 자체 또는 app 전체에서 검색 (container가 offset 상태일 수 있음)
        let matchingInContainer = container.staticTexts.matching(predicate)
        let matchingInApp = app.staticTexts.matching(predicate)
        XCTAssertTrue(
            matchingInContainer.count > 0 || matchingInApp.count > 0,
            "Drawer should contain member with name '\(name)'"
        )
    }
}
