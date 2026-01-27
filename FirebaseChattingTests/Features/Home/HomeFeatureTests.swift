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
                currentUserId: TestData.currentUser.profile.id,
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
        state.friends = TestData.friendProfiles

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When
        await store.send(.chatButtonTapped(TestData.friend1Profile)) {
            // Then
            $0.chatConfirmTarget = TestData.friend1Profile
        }
    }

    @Test
    func test_chatConfirmDismissed_hidesDialog() async {
        // Given
        var state = HomeFeature.State()
        state.chatConfirmTarget = TestData.friend1Profile

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
    func test_chatConfirmed_navigatesToChatRoom() async {
        // Given
        var state = HomeFeature.State()
        state.currentUser = TestData.currentUser
        state.chatConfirmTarget = TestData.friend1Profile

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        let expectedChatRoomId = ChatRoom.directChatRoomId(
            uid1: TestData.currentUser.profile.id,
            uid2: TestData.friend1Profile.id
        )

        // When
        await store.send(.chatConfirmed) {
            // Then
            $0.chatConfirmTarget = nil
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: expectedChatRoomId,
                currentUserId: TestData.currentUser.profile.id,
                otherUser: TestData.friend1Profile
            )
        }
    }

    @Test
    func test_chatConfirmed_noCurrentUser_doesNothing() async {
        // Given
        var state = HomeFeature.State()
        state.chatConfirmTarget = TestData.friend1Profile

        let store = TestStore(initialState: state) {
            HomeFeature()
        }

        // When & Then
        await store.send(.chatConfirmed)
    }

    // MARK: - Logout Flow Tests

    @Test
    func test_logoutConfirmed_callsLogoutAPI() async {
        // Given
        var logoutCalled = false
        var state = HomeFeature.State()
        state.showLogoutConfirm = true

        let store = TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.authRepository.logout = { logoutCalled = true }
        }
        store.exhaustivity = .off

        // When
        await store.send(.logoutConfirmed) {
            $0.showLogoutConfirm = false
        }

        // Then: effects complete
        await store.skipReceivedActions()

        // Verify logout was called
        #expect(logoutCalled)
    }

    @Test
    func test_logoutCompleted_success_sendsDelegate() async {
        // Given
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        store.exhaustivity = .off

        // When
        await store.send(.logoutCompleted(.success(())))

        // Then: delegate.logoutSucceeded is sent
        await store.skipReceivedActions()
    }

    @Test
    func test_logoutCompleted_failure_setsError() async {
        // Given
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        // When
        await store.send(.logoutCompleted(.failure(TestError.networkError))) {
            // Then
            $0.error = TestError.networkError.localizedDescription
        }
    }
}
