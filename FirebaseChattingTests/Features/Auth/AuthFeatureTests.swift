//
//  AuthFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct AuthFeatureTests {

    // MARK: - Test Data

    static let testUser = User(
        id: "test-user-123",
        nickname: "Test User",
        profilePhotoUrl: "https://example.com/photo.jpg",
        friendIds: [],
        chatRooms: []
    )

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = AuthFeature.State()

        // Then
        #expect(state.authenticationState == .unauthenticated)
        #expect(state.isLoading == false)
        #expect(state.userId == nil)
        #expect(state.user == nil)
        #expect(state.error == nil)
        #expect(state.mainTab == nil)
    }

    // MARK: - MainTab Delegate Tests

    @Test
    func test_mainTabLogoutSucceeded_clearsAuthState() async {
        // Given
        var state = AuthFeature.State()
        state.authenticationState = .authenticated
        state.userId = "123"
        state.user = Self.testUser
        state.mainTab = MainTabFeature.State()

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        // When
        await store.send(.mainTab(.delegate(.logoutSucceeded))) {
            // Then
            $0.authenticationState = .unauthenticated
            $0.userId = nil
            $0.user = nil
            $0.mainTab = nil
        }
    }
}
