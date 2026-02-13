//
//  MediaViewerPage.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

struct MediaViewerPage {
    let app: XCUIApplication

    var imageViewer: XCUIElement { app.otherElements["image_viewer"] }
    var imageIndex: XCUIElement { app.staticTexts["image_viewer_index"] }
    var videoPlayer: XCUIElement { app.otherElements["video_player"] }

    func swipeLeft() {
        imageViewer.swipeLeft()
    }

    func swipeRight() {
        imageViewer.swipeRight()
    }

    func dismissByDrag() {
        let start = imageViewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = imageViewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func assertImageViewerVisible() {
        XCTAssertTrue(imageViewer.waitForExistence(timeout: 3), "Image viewer should be visible")
    }

    func assertVideoPlayerVisible() {
        XCTAssertTrue(videoPlayer.waitForExistence(timeout: 3), "Video player should be visible")
    }

    func assertIndex(_ expected: String) {
        XCTAssertEqual(imageIndex.label, expected, "Image index should be '\(expected)'")
    }
}
