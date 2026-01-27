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
        state.home.friends = TestData.friendProfiles

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
        #expect(store.state.home.friends == TestData.friendProfiles)
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
                currentUserId: TestData.currentUser.profile.id,
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

    // MARK: - onAppear/onDisappear Tests

    @Test
    func test_onAppear_withAuthenticatedUser_startsObservingUserDocument() async {
        // Given
        var observeUserDocumentCalled = false

        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.authRepository.checkAuthenticationState = { TestData.currentUser.profile.id }
            $0.userRepository.observeUserDocument = { _ in
                observeUserDocumentCalled = true
                return AsyncStream { continuation in
                    continuation.yield(TestData.currentUser)
                    continuation.finish()
                }
            }
            $0.userRepository.getFriends = { _ in TestData.friendProfiles }
            $0.userRepository.getUserBatch = { _ in [:] }
            $0.chatRoomRepository.observeChatRooms = { _ in
                AsyncStream { $0.finish() }
            }
        }
        store.exhaustivity = .off

        // When
        await store.send(.onAppear)

        // Wait for effects to complete
        await store.skipReceivedActions()

        // Then: observeUserDocument should have been called
        #expect(observeUserDocumentCalled)
    }

    @Test
    func test_onAppear_withNoAuthenticatedUser_doesNothing() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.authRepository.checkAuthenticationState = { nil }
        }

        // When & Then: No effects should be produced
        await store.send(.onAppear)
    }

    @Test
    func test_onDisappear_cancelsObservation() async {
        // Given
        var state = MainTabFeature.State()
        state.currentUser = TestData.currentUser

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When & Then
        await store.send(.onDisappear)
    }

    // MARK: - userDocumentUpdated Tests

    @Test
    func test_userDocumentUpdated_updatesCurrentUserAndChildStates() async {
        // Given
        var getFriendsCalled = false
        var getUserBatchCalled = false

        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.userRepository.getFriends = { _ in
                getFriendsCalled = true
                return TestData.friendProfiles
            }
            $0.userRepository.getUserBatch = { _ in
                getUserBatchCalled = true
                return [:]
            }
            $0.chatRoomRepository.observeChatRooms = { _ in
                AsyncStream { $0.finish() }
            }
        }
        store.exhaustivity = .off

        // When
        await store.send(.userDocumentUpdated(TestData.currentUser)) {
            // Then
            $0.currentUser = TestData.currentUser
            $0.home.currentUser = TestData.currentUser
            $0.chatList.currentUserId = TestData.currentUser.profile.id
            $0.previousFriendIds = TestData.currentUser.friendIds
            $0.previousChatRoomIds = TestData.currentUser.chatRooms
            $0.chatList.chatRoomIds = TestData.currentUser.chatRooms
        }

        // Wait for effects to complete
        await store.skipReceivedActions()

        // Verify API calls were made
        #expect(getFriendsCalled)
        #expect(getUserBatchCalled)
    }

    @Test
    func test_userDocumentUpdated_withNewFriendIds_callsGetFriends() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = ["old-friend"]
        state.previousChatRoomIds = TestData.currentUser.chatRooms // Don't trigger chatRoom effect

        let store = TestStore(initialState: state) {
            MainTabFeature()
        } withDependencies: {
            $0.userRepository.getFriends = { _ in TestData.friendProfiles }
        }

        // When
        await store.send(.userDocumentUpdated(TestData.currentUser)) {
            $0.currentUser = TestData.currentUser
            $0.home.currentUser = TestData.currentUser
            $0.chatList.currentUserId = TestData.currentUser.profile.id
            $0.previousFriendIds = TestData.currentUser.friendIds
        }

        // Then: Receiving friendsLoaded means getFriends was called
        await store.receive(\.friendsLoaded.success) {
            $0.home.friends = TestData.friendProfiles
        }
    }

    @Test
    func test_userDocumentUpdated_withSameFriendIds_doesNotCallGetFriends() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = TestData.currentUser.friendIds
        state.previousChatRoomIds = TestData.currentUser.chatRooms

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When: Send same friendIds and chatRoomIds
        await store.send(.userDocumentUpdated(TestData.currentUser)) {
            $0.currentUser = TestData.currentUser
            $0.home.currentUser = TestData.currentUser
            $0.chatList.currentUserId = TestData.currentUser.profile.id
        }

        // Then: No effects should be received (getFriends and getUserBatch not called)
        // Test passes if no additional effects are received
    }

    @Test
    func test_userDocumentUpdated_withEmptyFriendIds_clearsFriends() async {
        // Given
        var state = MainTabFeature.State()
        state.home.friends = TestData.friendProfiles
        state.previousFriendIds = TestData.currentUser.friendIds

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When
        await store.send(.userDocumentUpdated(TestData.currentUserWithNoFriends)) {
            // Then
            $0.currentUser = TestData.currentUserWithNoFriends
            $0.home.currentUser = TestData.currentUserWithNoFriends
            $0.chatList.currentUserId = TestData.currentUserWithNoFriends.profile.id
            $0.previousFriendIds = []
            $0.home.friends = []
        }
    }

    // MARK: - friendsLoaded Tests

    @Test
    func test_friendsLoaded_success_updatesFriendsInHomeState() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When
        await store.send(.friendsLoaded(.success(TestData.friendProfiles))) {
            // Then
            $0.home.friends = TestData.friendProfiles
        }
    }

    @Test
    func test_friendsLoaded_failure_setsErrorInHomeState() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When
        await store.send(.friendsLoaded(.failure(TestError.networkError))) {
            // Then
            $0.home.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Delegate Tests

    @Test
    func test_homeLogoutSucceeded_delegatesToParent() async {
        // Given
        var logoutCalled = false
        var state = MainTabFeature.State()
        state.home.currentUser = TestData.currentUser
        state.home.showLogoutConfirm = true

        let store = TestStore(initialState: state) {
            MainTabFeature()
        } withDependencies: {
            $0.authRepository.logout = { logoutCalled = true }
        }
        store.exhaustivity = .off

        // When: logoutConfirmed triggers logout flow
        await store.send(.home(.logoutConfirmed)) {
            $0.home.showLogoutConfirm = false
        }

        // Then: effects complete (logoutCompleted -> delegate.logoutSucceeded chain)
        await store.skipReceivedActions()

        // Verify logout was called
        #expect(logoutCalled)
    }

    // MARK: - ChatRoomIds Change Tests

    @Test
    func test_userDocumentUpdated_withNewChatRoomIds_sendsChatRoomIdsToChild() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = TestData.currentUserWithMultipleChatRooms.friendIds
        state.previousChatRoomIds = ["chatroom-1"]  // Only chatroom-1 previously

        let store = TestStore(initialState: state) {
            MainTabFeature()
        } withDependencies: {
            $0.userRepository.getUserBatch = { _ in TestData.chatRoomProfiles }
            $0.chatRoomRepository.observeChatRooms = { _ in
                AsyncStream { $0.finish() }
            }
        }

        // When - user document updated with new chatRoomIds
        await store.send(.userDocumentUpdated(TestData.currentUserWithMultipleChatRooms)) {
            $0.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.home.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.chatList.currentUserId = TestData.currentUserWithMultipleChatRooms.profile.id
            $0.previousChatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
            // setChatRoomIds should be sent to chatList
            $0.chatList.chatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
        }

        // Then - chatRoomProfilesLoaded should be received
        await store.receive(\.chatRoomProfilesLoaded.success) {
            $0.chatList.chatRoomProfiles = TestData.chatRoomProfiles
        }
    }

    @Test
    func test_userDocumentUpdated_withNewChatRoomIds_callsGetUserBatch() async {
        // Given
        var getUserBatchCalledWith: [String]?

        var state = MainTabFeature.State()
        state.previousFriendIds = TestData.currentUserWithMultipleChatRooms.friendIds
        state.previousChatRoomIds = []

        let store = TestStore(initialState: state) {
            MainTabFeature()
        } withDependencies: {
            $0.userRepository.getUserBatch = { ids in
                getUserBatchCalledWith = ids
                return TestData.chatRoomProfiles
            }
            $0.chatRoomRepository.observeChatRooms = { _ in
                AsyncStream { $0.finish() }
            }
        }

        // When
        await store.send(.userDocumentUpdated(TestData.currentUserWithMultipleChatRooms)) {
            $0.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.home.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.chatList.currentUserId = TestData.currentUserWithMultipleChatRooms.profile.id
            $0.previousChatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
            $0.chatList.chatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
        }

        // Then - chatRoomProfilesLoaded should be received
        await store.receive(\.chatRoomProfilesLoaded.success) {
            $0.chatList.chatRoomProfiles = TestData.chatRoomProfiles
        }

        // Then - getUserBatch should be called with chatRoomIds
        #expect(getUserBatchCalledWith == TestData.currentUserWithMultipleChatRooms.chatRooms)
    }

    @Test
    func test_userDocumentUpdated_withSameChatRoomIds_doesNotSendToChild() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = TestData.currentUserWithMultipleChatRooms.friendIds
        state.previousChatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
        state.chatList.chatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When - same chatRoomIds
        await store.send(.userDocumentUpdated(TestData.currentUserWithMultipleChatRooms)) {
            $0.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.home.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.chatList.currentUserId = TestData.currentUserWithMultipleChatRooms.profile.id
            // chatList.chatRoomIds should remain unchanged (no state change)
        }

        // Then - no additional actions should be received
    }

    @Test
    func test_userDocumentUpdated_withEmptyChatRooms_clearsChatRoomProfiles() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = []
        state.previousChatRoomIds = ["chatroom-1"]
        state.chatList.chatRoomProfiles = TestData.chatRoomProfiles
        state.chatList.chatRoomIds = ["chatroom-1"]

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When
        await store.send(.userDocumentUpdated(TestData.currentUserWithNoFriends)) {
            $0.currentUser = TestData.currentUserWithNoFriends
            $0.home.currentUser = TestData.currentUserWithNoFriends
            $0.chatList.currentUserId = TestData.currentUserWithNoFriends.profile.id
            $0.previousChatRoomIds = []
            $0.chatList.chatRoomProfiles = [:]
            $0.chatList.chatRoomIds = []
        }
    }

    @Test
    func test_userDocumentUpdated_withEmptyChatRooms_sendsEmptyIdsToChild() async {
        // Given
        var state = MainTabFeature.State()
        state.previousFriendIds = []
        state.previousChatRoomIds = ["chatroom-1"]
        state.chatList.chatRoomIds = ["chatroom-1"]

        let store = TestStore(initialState: state) {
            MainTabFeature()
        }

        // When
        await store.send(.userDocumentUpdated(TestData.currentUserWithNoFriends)) {
            $0.currentUser = TestData.currentUserWithNoFriends
            $0.home.currentUser = TestData.currentUserWithNoFriends
            $0.chatList.currentUserId = TestData.currentUserWithNoFriends.profile.id
            $0.previousChatRoomIds = []
            // chatList should receive empty chatRoomIds
            $0.chatList.chatRoomIds = []
            $0.chatList.chatRoomProfiles = [:]
        }
    }

    @Test
    func test_chatRoomProfilesLoaded_success_updatesChatRoomProfiles() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When
        await store.send(.chatRoomProfilesLoaded(.success(TestData.chatRoomProfiles))) {
            // Then
            $0.chatList.chatRoomProfiles = TestData.chatRoomProfiles
        }
    }

    @Test
    func test_chatRoomProfilesLoaded_failure_setsError() async {
        // Given
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // When
        await store.send(.chatRoomProfilesLoaded(.failure(TestError.networkError))) {
            // Then
            $0.chatList.error = TestError.networkError.localizedDescription
        }
    }

    @Test
    func test_userDocumentUpdated_withAddedChatRoom_triggersProfileReload() async {
        // Given
        var getUserBatchCalled = false

        var state = MainTabFeature.State()
        state.previousFriendIds = TestData.currentUser.friendIds
        state.previousChatRoomIds = TestData.currentUser.chatRooms  // ["chatroom-1"]
        state.chatList.chatRoomIds = TestData.currentUser.chatRooms

        let store = TestStore(initialState: state) {
            MainTabFeature()
        } withDependencies: {
            $0.userRepository.getUserBatch = { _ in
                getUserBatchCalled = true
                return TestData.chatRoomProfiles
            }
            $0.chatRoomRepository.observeChatRooms = { _ in
                AsyncStream { $0.finish() }
            }
        }
        store.exhaustivity = .off

        // When - add a new chatroom
        await store.send(.userDocumentUpdated(TestData.currentUserWithMultipleChatRooms)) {
            $0.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.home.currentUser = TestData.currentUserWithMultipleChatRooms
            $0.chatList.currentUserId = TestData.currentUserWithMultipleChatRooms.profile.id
            $0.previousChatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
            $0.chatList.chatRoomIds = TestData.currentUserWithMultipleChatRooms.chatRooms
        }

        // Wait for async
        await store.skipReceivedActions()

        // Then - getUserBatch should be called for profile reload
        #expect(getUserBatchCalled)
    }
}
