//
//  InviteFriendsFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct InviteFriendsFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )

        // Then
        #expect(state.friends == TestData.invitableFriends)
        #expect(state.selectedFriendIds.isEmpty)
        #expect(state.error == nil)
        #expect(state.canInvite == false)
        #expect(state.selectedCount == 0)
    }

    // MARK: - friendToggled Tests

    @Test
    func test_friendToggled_addsFriend() async {
        // Given
        let store = TestStore(
            initialState: InviteFriendsFeature.State(
                friends: TestData.invitableFriends
            )
        ) {
            InviteFriendsFeature()
        }

        // When
        await store.send(.friendToggled("friend-3")) {
            // Then
            $0.selectedFriendIds.insert("friend-3")
        }
    }

    @Test
    func test_friendToggled_removesFriend() async {
        // Given
        var state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )
        state.selectedFriendIds = ["friend-3"]

        let store = TestStore(initialState: state) {
            InviteFriendsFeature()
        }

        // When
        await store.send(.friendToggled("friend-3")) {
            // Then
            $0.selectedFriendIds.remove("friend-3")
        }
    }

    @Test
    func test_friendToggled_addsAndRemovesFriend() async {
        // Given
        let store = TestStore(
            initialState: InviteFriendsFeature.State(
                friends: TestData.invitableFriends
            )
        ) {
            InviteFriendsFeature()
        }

        // When - Add friend
        await store.send(.friendToggled("friend-3")) {
            $0.selectedFriendIds.insert("friend-3")
        }

        // When - Add another friend
        await store.send(.friendToggled("friend-4")) {
            $0.selectedFriendIds.insert("friend-4")
        }

        // When - Remove first friend
        await store.send(.friendToggled("friend-3")) {
            $0.selectedFriendIds.remove("friend-3")
        }
    }

    // MARK: - canInvite Computed Property Tests

    @Test
    func test_canInvite_returnsFalseWithNoSelection() {
        // Given
        let state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )

        // Then
        #expect(state.canInvite == false)
    }

    @Test
    func test_canInvite_returnsTrueWithSelection() {
        // Given
        var state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )
        state.selectedFriendIds = ["friend-3"]

        // Then
        #expect(state.canInvite == true)
    }

    // MARK: - inviteButtonTapped Tests

    @Test
    func test_inviteButtonTapped_withNoSelection_doesNothing() async {
        // Given
        let store = TestStore(
            initialState: InviteFriendsFeature.State(
                friends: TestData.invitableFriends
            )
        ) {
            InviteFriendsFeature()
        }

        // When & Then - should not change state
        await store.send(.inviteButtonTapped)
    }

    @Test
    func test_inviteButtonTapped_sendsDelegate() async {
        // Given
        var state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )
        state.selectedFriendIds = ["friend-3", "friend-4"]

        let store = TestStore(initialState: state) {
            InviteFriendsFeature()
        }

        // When
        await store.send(.inviteButtonTapped)

        // Then - delegate should be sent with selected friend ids
        await store.receive(\.delegate)
    }

    // MARK: - selectedCount Tests

    @Test
    func test_selectedCount_returnsCorrectCount() {
        // Given
        var state = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )

        // Then - 0 selected
        #expect(state.selectedCount == 0)

        // Given - 2 selected
        state.selectedFriendIds = ["friend-3", "friend-4"]

        // Then
        #expect(state.selectedCount == 2)
    }
}
