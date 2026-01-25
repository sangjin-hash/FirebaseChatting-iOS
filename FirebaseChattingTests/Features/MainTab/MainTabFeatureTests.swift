//
//  MainTabFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct MainTabFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = MainTabFeature.State()

        // Then
        #expect(state.selectedTab == .home)
        #expect(state.home == HomeFeature.State())
        #expect(state.chatList == ChatListFeature.State())
    }

    // MARK: - Tab Selection Tests

    @Test
    func test_selectedTabChanged_toChat_changesCurrentTab() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When
        await store.send(.selectedTabChanged(.chat)) {
            // Then
            $0.selectedTab = .chat
        }
    }

    @Test
    func test_selectedTabChanged_toHome_changesCurrentTab() async {
        // Given
        var state = MainTabFeature.State()
        state.selectedTab = .chat

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When
        await store.send(.selectedTabChanged(.home)) {
            // Then
            $0.selectedTab = .home
        }
    }

    // MARK: - Child Feature Action Tests

    @Test
    func test_chatListAction_onAppear_propagates() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When & Then (ChatListFeature.onAppear does nothing for now)
        await store.send(.chatList(.onAppear))
    }

    // MARK: - Tab State Persistence Tests

    @Test
    func test_tabChange_preservesHomeState() async {
        // Given
        var state = MainTabFeature.State()
        state.home.currentUser = TestData.currentUser
        state.home.friends = TestData.friends

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When: Switch to chat tab
        await store.send(.selectedTabChanged(.chat)) {
            $0.selectedTab = .chat
        }

        // When: Switch back to home tab
        await store.send(.selectedTabChanged(.home)) {
            $0.selectedTab = .home
        }

        // Then: Home state should be preserved
        #expect(store.state.home.currentUser == TestData.currentUser)
        #expect(store.state.home.friends == TestData.friends)
    }

    // MARK: - Integration Tests

    @Test
    func test_homeSearchFlow_worksWithinMainTab() async {
        // Given
        var state = MainTabFeature.State()
        state.home.currentUser = TestData.currentUser

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When: Search button tapped in home
        await store.send(.home(.searchButtonTapped)) {
            $0.home.searchDestination = SearchFeature.State(
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        }
    }

    @Test
    func test_homeLogoutButtonFlow_worksWithinMainTab() async {
        // Given
        var state = MainTabFeature.State()
        state.home.currentUser = TestData.currentUser

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When: Logout button tapped in home
        await store.send(.home(.logoutButtonTapped)) {
            $0.home.showLogoutConfirm = true
        }

        // When: Dismiss logout confirm
        await store.send(.home(.logoutConfirmDismissed)) {
            $0.home.showLogoutConfirm = false
        }
    }
}
