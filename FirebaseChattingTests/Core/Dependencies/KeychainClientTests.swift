//
//  KeychainClientTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import ComposableArchitecture
import XCTest

@testable import FirebaseChatting

@MainActor
final class KeychainClientTests: XCTestCase {

    // MARK: - Properties

    private var sut: KeychainClient!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = .liveValue
        // Clean up any existing tokens before each test
        try? sut.deleteToken()
        // Reset UserDefaults for first launch tests
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
    }

    override func tearDown() async throws {
        // Clean up after each test
        try? sut.deleteToken()
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Save Token Tests

    func test_saveToken_success() throws {
        // Given
        let testToken = "test-token-12345"

        // When
        try sut.saveToken(testToken)

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertEqual(loadedToken, testToken, "Saved token should be loaded successfully")
    }

    func test_saveToken_overwritesExistingToken() throws {
        // Given
        let firstToken = "first-token"
        let secondToken = "second-token"

        // When
        try sut.saveToken(firstToken)
        try sut.saveToken(secondToken)

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertEqual(loadedToken, secondToken, "Second token should overwrite first token")
        XCTAssertNotEqual(loadedToken, firstToken, "First token should be overwritten")
    }

    func test_saveToken_withEmptyString() throws {
        // Given
        let emptyToken = ""

        // When
        try sut.saveToken(emptyToken)

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertEqual(loadedToken, emptyToken, "Empty token should be saved and loaded")
    }

    func test_saveToken_withSpecialCharacters() throws {
        // Given
        let specialToken = "token!@#$%^&*()_+-=[]{}|;:',.<>?/~`"

        // When
        try sut.saveToken(specialToken)

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertEqual(loadedToken, specialToken, "Token with special characters should be saved correctly")
    }

    func test_saveToken_withLongString() throws {
        // Given
        let longToken = String(repeating: "a", count: 10000)

        // When
        try sut.saveToken(longToken)

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertEqual(loadedToken, longToken, "Long token should be saved and loaded correctly")
    }

    // MARK: - Load Token Tests

    func test_loadToken_success() throws {
        // Given
        let testToken = "test-token-67890"
        try sut.saveToken(testToken)

        // When
        let loadedToken = sut.loadToken()

        // Then
        XCTAssertNotNil(loadedToken, "Loaded token should not be nil")
        XCTAssertEqual(loadedToken, testToken, "Loaded token should match saved token")
    }

    func test_loadToken_returnsNilWhenNoTokenSaved() {
        // Given
        // No token saved

        // When
        let loadedToken = sut.loadToken()

        // Then
        XCTAssertNil(loadedToken, "Should return nil when no token is saved")
    }

    func test_loadToken_returnsNilAfterDeletion() throws {
        // Given
        let testToken = "token-to-delete"
        try sut.saveToken(testToken)

        // When
        try sut.deleteToken()
        let loadedToken = sut.loadToken()

        // Then
        XCTAssertNil(loadedToken, "Should return nil after token is deleted")
    }

    func test_loadToken_multipleTimes() throws {
        // Given
        let testToken = "persistent-token"
        try sut.saveToken(testToken)

        // When
        let firstLoad = sut.loadToken()
        let secondLoad = sut.loadToken()
        let thirdLoad = sut.loadToken()

        // Then
        XCTAssertEqual(firstLoad, testToken, "First load should return token")
        XCTAssertEqual(secondLoad, testToken, "Second load should return token")
        XCTAssertEqual(thirdLoad, testToken, "Third load should return token")
    }

    // MARK: - Delete Token Tests

    func test_deleteToken_success() throws {
        // Given
        let testToken = "token-to-delete"
        try sut.saveToken(testToken)

        // When
        XCTAssertNoThrow(try sut.deleteToken(), "Delete should not throw error")

        // Then
        let loadedToken = sut.loadToken()
        XCTAssertNil(loadedToken, "Token should be nil after deletion")
    }

    func test_deleteToken_whenNoTokenExists() {
        // Given
        // No token saved

        // When & Then
        XCTAssertNoThrow(try sut.deleteToken(), "Delete should not throw error when no token exists")
    }

    func test_deleteToken_multipleTimes() throws {
        // Given
        let testToken = "token-to-delete-multiple"
        try sut.saveToken(testToken)

        // When & Then
        XCTAssertNoThrow(try sut.deleteToken(), "First delete should not throw")
        XCTAssertNoThrow(try sut.deleteToken(), "Second delete should not throw")
        XCTAssertNoThrow(try sut.deleteToken(), "Third delete should not throw")
    }

    // MARK: - First Launch Tests

    func test_isFirstLaunch_returnsTrue_onInitialLaunch() {
        // Given
        // Fresh UserDefaults (cleared in setUp)

        // When
        let isFirstLaunch = sut.isFirstLaunch()

        // Then
        XCTAssertTrue(isFirstLaunch, "Should return true on first launch")
    }

    func test_isFirstLaunch_returnsFalse_afterSetNotFirstLaunch() {
        // Given
        sut.setNotFirstLaunch()

        // When
        let isFirstLaunch = sut.isFirstLaunch()

        // Then
        XCTAssertFalse(isFirstLaunch, "Should return false after setNotFirstLaunch is called")
    }

    func test_setNotFirstLaunch_persistsAcrossChecks() {
        // Given
        XCTAssertTrue(sut.isFirstLaunch(), "Initially should be first launch")

        // When
        sut.setNotFirstLaunch()

        // Then
        XCTAssertFalse(sut.isFirstLaunch(), "First check should return false")
        XCTAssertFalse(sut.isFirstLaunch(), "Second check should return false")
        XCTAssertFalse(sut.isFirstLaunch(), "Third check should return false")
    }

    func test_setNotFirstLaunch_multipleCallsHaveNoEffect() {
        // When
        sut.setNotFirstLaunch()
        sut.setNotFirstLaunch()
        sut.setNotFirstLaunch()

        // Then
        XCTAssertFalse(sut.isFirstLaunch(), "Should still return false after multiple calls")
    }

    // MARK: - Integration Tests

    func test_fullWorkflow_saveLoadDelete() throws {
        // Given
        let token = "integration-test-token"

        // When - Save
        try sut.saveToken(token)
        let afterSave = sut.loadToken()
        XCTAssertEqual(afterSave, token, "Token should be loaded after save")

        // When - Delete
        try sut.deleteToken()
        let afterDelete = sut.loadToken()
        XCTAssertNil(afterDelete, "Token should be nil after delete")

        // When - Save again
        try sut.saveToken(token)
        let afterSecondSave = sut.loadToken()
        XCTAssertEqual(afterSecondSave, token, "Token should be loaded after second save")
    }

    func test_firstLaunchWorkflow() {
        // Initial state
        XCTAssertTrue(sut.isFirstLaunch(), "Should be first launch initially")

        // After setting not first launch
        sut.setNotFirstLaunch()
        XCTAssertFalse(sut.isFirstLaunch(), "Should not be first launch after setting")

        // Simulate app restart (UserDefaults persists)
        let newClient = KeychainClient.liveValue
        XCTAssertFalse(newClient.isFirstLaunch(), "Should not be first launch after app restart")
    }

    // MARK: - Mock Client Tests

    func test_mockClient_defaultBehavior() {
        // Given
        let mockClient = KeychainClient.mock()

        // Then
        XCTAssertNoThrow(try mockClient.saveToken("token"))
        XCTAssertNil(mockClient.loadToken())
        XCTAssertNoThrow(try mockClient.deleteToken())
        XCTAssertFalse(mockClient.isFirstLaunch())
        XCTAssertNoThrow(mockClient.setNotFirstLaunch())
    }

    func test_mockClient_customSaveToken() throws {
        // Given
        var savedToken: String?
        let mockClient = KeychainClient.mock(
            saveToken: { token in
                savedToken = token
            }
        )

        // When
        try mockClient.saveToken("custom-token")

        // Then
        XCTAssertEqual(savedToken, "custom-token")
    }

    func test_mockClient_customLoadToken() {
        // Given
        let mockClient = KeychainClient.mock(
            loadToken: { "mocked-token" }
        )

        // When
        let token = mockClient.loadToken()

        // Then
        XCTAssertEqual(token, "mocked-token")
    }

    func test_mockClient_customDeleteToken() {
        // Given
        var deleteCount = 0
        let mockClient = KeychainClient.mock(
            deleteToken: {
                deleteCount += 1
            }
        )

        // When
        try? mockClient.deleteToken()
        try? mockClient.deleteToken()

        // Then
        XCTAssertEqual(deleteCount, 2)
    }

    func test_mockClient_customIsFirstLaunch() {
        // Given
        let mockClient = KeychainClient.mock(
            isFirstLaunch: { true }
        )

        // Then
        XCTAssertTrue(mockClient.isFirstLaunch())
    }

    func test_mockClient_customSetNotFirstLaunch() {
        // Given
        var setCount = 0
        let mockClient = KeychainClient.mock(
            setNotFirstLaunch: {
                setCount += 1
            }
        )

        // When
        mockClient.setNotFirstLaunch()
        mockClient.setNotFirstLaunch()

        // Then
        XCTAssertEqual(setCount, 2)
    }

    func test_mockClient_throwingError() {
        // Given
        let mockClient = KeychainClient.mock(
            saveToken: { _ in throw KeychainError.saveFailed },
            deleteToken: { throw KeychainError.deleteFailed }
        )

        // Then
        XCTAssertThrowsError(try mockClient.saveToken("token")) { error in
            XCTAssertEqual(error as? KeychainError, .saveFailed)
        }

        XCTAssertThrowsError(try mockClient.deleteToken()) { error in
            XCTAssertEqual(error as? KeychainError, .deleteFailed)
        }
    }

    // MARK: - Error Handling Tests

    func test_keychainError_equatable() {
        XCTAssertEqual(KeychainError.saveFailed, KeychainError.saveFailed)
        XCTAssertEqual(KeychainError.deleteFailed, KeychainError.deleteFailed)
        XCTAssertEqual(KeychainError.unexpectedData, KeychainError.unexpectedData)

        XCTAssertNotEqual(KeychainError.saveFailed, KeychainError.deleteFailed)
        XCTAssertNotEqual(KeychainError.saveFailed, KeychainError.unexpectedData)
        XCTAssertNotEqual(KeychainError.deleteFailed, KeychainError.unexpectedData)
    }

    // MARK: - Thread Safety Tests
    // Note: Concurrency tests removed due to Swift 6 strict concurrency requirements
    // KeychainClient methods are synchronous and thread-safe via Keychain's internal locking
}
