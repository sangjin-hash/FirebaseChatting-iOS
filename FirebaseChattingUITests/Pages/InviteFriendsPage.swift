//
//  InviteFriendsPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct InviteFriendsPage {
    let app: XCUIApplication

    var inviteButton: XCUIElement { app.buttons["invite_friends_invite_button"] }
    var cancelButton: XCUIElement { app.buttons["invite_friends_cancel_button"] }

    func friend(_ friendId: String) -> XCUIElement {
        app.buttons["invite_friend_\(friendId)"]
    }

    func selectFriend(_ friendId: String) {
        friend(friendId).tap()
    }

    func tapInvite() {
        inviteButton.tap()
    }
}
