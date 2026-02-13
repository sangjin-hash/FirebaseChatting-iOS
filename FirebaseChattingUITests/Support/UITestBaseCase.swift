//
//  UITestBaseCase.swift
//  FirebaseChattingUITests
//
//  Created by Claude Code
//

import XCTest

class UITestBaseCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func launchApp(scenario: String) {
        app.launchArguments = ["-UITesting", "-Scenario_\(scenario)"]
        app.launch()
    }

    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> XCUIElement {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element '\(element.identifier)' not found within \(timeout)s"
        )
        return element
    }

    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Element '\(element.identifier)' still exists after \(timeout)s")
    }

    /// Chat 탭으로 이동 (MainTab에서)
    func navigateToChatTab() {
        let chatTab = app.tabBars.buttons.element(boundBy: 1)
        waitForElement(chatTab)
        chatTab.tap()
    }
}
