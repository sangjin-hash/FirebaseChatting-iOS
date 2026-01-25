//
//  SearchFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct SearchFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = SearchFeature.State(
            currentUserId: "test-user",
            currentUserFriendIds: ["friend-1"]
        )

        // Then
        #expect(state.searchQuery == "")
        #expect(state.searchResults == [])
        #expect(state.currentUserId == "test-user")
        #expect(state.currentUserFriendIds == ["friend-1"])
        #expect(state.isSearching == false)
        #expect(state.hasSearched == false)
        #expect(state.addingFriendId == nil)
        #expect(state.error == nil)
        #expect(state.addFriendConfirmTarget == nil)
    }

    // MARK: - Search Button Tests

    @Test
    func test_searchButtonTapped_withEmptyQuery_doesNothing() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                searchQuery: "",
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When & Then
        await store.send(.searchButtonTapped)
    }

    @Test
    func test_searchButtonTapped_withWhitespaceQuery_doesNothing() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                searchQuery: "   ",
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When & Then
        await store.send(.searchButtonTapped)
    }

    // MARK: - Add Friend Tests

    @Test
    func test_addFriendButtonTapped_showsConfirmDialog() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                searchQuery: "test",
                searchResults: TestData.searchResults,
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When
        await store.send(.addFriendButtonTapped(TestData.searchResult1)) {
            // Then
            $0.addFriendConfirmTarget = TestData.searchResult1
        }
    }

    @Test
    func test_addFriendConfirmDismissed_hidesDialog() async {
        // Given
        var state = SearchFeature.State(
            currentUserId: TestData.currentUser.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )
        state.addFriendConfirmTarget = TestData.searchResult1

        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // When
        await store.send(.addFriendConfirmDismissed) {
            // Then
            $0.addFriendConfirmTarget = nil
        }
    }

    // MARK: - Binding Tests

    @Test
    func test_binding_searchQuery_updatesState() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When
        await store.send(\.binding.searchQuery, "new query") {
            // Then
            $0.searchQuery = "new query"
        }
    }
}
