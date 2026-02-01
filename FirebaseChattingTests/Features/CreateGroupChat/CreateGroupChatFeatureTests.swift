//
//  CreateGroupChatFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct CreateGroupChatFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )

        // Then
        #expect(state.currentUserId == "user-1")
        #expect(state.friends == TestData.friendProfiles)
        #expect(state.selectedFriendIds.isEmpty)
        #expect(state.canCreate == false)
        #expect(state.selectedCount == 0)
    }

    // MARK: - friendToggled Tests

    @Test
    func test_friendToggled_addsFriend() async {
        // Given
        let store = TestStore(
            initialState: CreateGroupChatFeature.State(
                currentUserId: "user-1",
                friends: TestData.friendProfiles
            )
        ) {
            CreateGroupChatFeature()
        }

        // When
        await store.send(.friendToggled("friend-1")) {
            // Then
            $0.selectedFriendIds.insert("friend-1")
        }
    }

    @Test
    func test_friendToggled_removesFriend() async {
        // Given
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )
        state.selectedFriendIds = ["friend-1"]

        let store = TestStore(initialState: state) {
            CreateGroupChatFeature()
        }

        // When
        await store.send(.friendToggled("friend-1")) {
            // Then
            $0.selectedFriendIds.remove("friend-1")
        }
    }

    @Test
    func test_friendToggled_addsAndRemovesFriend() async {
        // Given
        let store = TestStore(
            initialState: CreateGroupChatFeature.State(
                currentUserId: "user-1",
                friends: TestData.friendProfiles
            )
        ) {
            CreateGroupChatFeature()
        }

        // When - Add friend
        await store.send(.friendToggled("friend-1")) {
            $0.selectedFriendIds.insert("friend-1")
        }

        // When - Add another friend
        await store.send(.friendToggled("friend-2")) {
            $0.selectedFriendIds.insert("friend-2")
        }

        // When - Remove first friend
        await store.send(.friendToggled("friend-1")) {
            $0.selectedFriendIds.remove("friend-1")
        }
    }

    // MARK: - canCreate Computed Property Tests

    @Test
    func test_canCreate_returnsFalseWithLessThanTwoFriends() {
        // Given - 0 friends selected
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )

        // Then
        #expect(state.canCreate == false)

        // Given - 1 friend selected
        state.selectedFriendIds = ["friend-1"]

        // Then
        #expect(state.canCreate == false)
    }

    @Test
    func test_canCreate_returnsTrueWithTwoOrMoreFriends() {
        // Given - 2 friends selected
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )
        state.selectedFriendIds = ["friend-1", "friend-2"]

        // Then
        #expect(state.canCreate == true)

        // Given - 3 friends selected
        state.selectedFriendIds = ["friend-1", "friend-2", "friend-3"]

        // Then
        #expect(state.canCreate == true)
    }

    // MARK: - createButtonTapped Tests

    @Test
    func test_createButtonTapped_withLessThanTwoFriends_doesNothing() async {
        // Given
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )
        state.selectedFriendIds = ["friend-1"]  // Only 1 friend

        let store = TestStore(initialState: state) {
            CreateGroupChatFeature()
        }

        // When & Then - should not change state
        await store.send(.createButtonTapped)
    }

    @Test
    func test_createButtonTapped_preparesGroupChat_lazyCreation() async {
        // Given
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )
        state.selectedFriendIds = ["friend-1", "friend-2"]

        let store = TestStore(initialState: state) {
            CreateGroupChatFeature()
        }

        // When & Then - Lazy 생성: Repository 호출 없이 delegate만 전송
        await store.send(.createButtonTapped)

        // Then - delegate 수신
        await store.receive(\.delegate.groupChatPrepared)
    }

    // MARK: - selectedCount Tests

    @Test
    func test_selectedCount_returnsCorrectCount() {
        // Given
        var state = CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: TestData.friendProfiles
        )

        // Then - 0 selected
        #expect(state.selectedCount == 0)

        // Given - 2 selected
        state.selectedFriendIds = ["friend-1", "friend-2"]

        // Then
        #expect(state.selectedCount == 2)
    }
}
