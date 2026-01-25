//
//  HomeFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct HomeFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = HomeFeature.State()

        // Then
        #expect(state.currentUser == nil)
        #expect(state.friends == [])
        #expect(state.isLoading == false)
        #expect(state.error == nil)
        #expect(state.searchDestination == nil)
        #expect(state.chatConfirmTarget == nil)
        #expect(state.showLogoutConfirm == false)
    }

    // MARK: - Logout Button Tests

    @Test
    func test_logoutButtonTapped_showsConfirmDialog() async {
        // Given
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        // When
        await store.send(.logoutButtonTapped) {
            // Then
            $0.showLogoutConfirm = true
        }
    }

    @Test
    func test_logoutConfirmDismissed_hidesDialog() async {
        // Given
        var state = HomeFeature.State()
        state.showLogoutConfirm = true

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.logoutConfirmDismissed) {
            // Then
            $0.showLogoutConfirm = false
        }
    }

    // MARK: - Search Button Tests

    @Test
    func test_searchButtonTapped_presentsSearchSheet() async {
        // Given
        var state = HomeFeature.State()
        state.currentUser = TestData.currentUser

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.searchButtonTapped) {
            // Then
            $0.searchDestination = SearchFeature.State(
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        }
    }

    @Test
    func test_searchButtonTapped_noCurrentUser_doesNothing() async {
        // Given
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        // When & Then
        await store.send(.searchButtonTapped)
    }

    // MARK: - Chat Button Tests

    @Test
    func test_chatButtonTapped_showsChatConfirmDialog() async {
        // Given
        var state = HomeFeature.State()
        state.currentUser = TestData.currentUser
        state.friends = TestData.friends

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.chatButtonTapped(TestData.friend1)) {
            // Then
            $0.chatConfirmTarget = TestData.friend1
        }
    }

    @Test
    func test_chatConfirmDismissed_hidesDialog() async {
        // Given
        var state = HomeFeature.State()
        state.chatConfirmTarget = TestData.friend1

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.chatConfirmDismissed) {
            // Then
            $0.chatConfirmTarget = nil
        }
    }

    @Test
    func test_chatConfirmed_clearsTarget() async {
        // Given
        var state = HomeFeature.State()
        state.chatConfirmTarget = TestData.friend1

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.chatConfirmed) {
            // Then
            $0.chatConfirmTarget = nil
        }
    }
}
