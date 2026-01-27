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
                currentUserId: TestData.currentUser.profile.id,
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
                currentUserId: TestData.currentUser.profile.id,
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
                searchResults: TestData.searchResultProfiles,
                currentUserId: TestData.currentUser.profile.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When
        await store.send(.addFriendButtonTapped(TestData.searchResult1Profile)) {
            // Then
            $0.addFriendConfirmTarget = TestData.searchResult1Profile
        }
    }

    @Test
    func test_addFriendConfirmDismissed_hidesDialog() async {
        // Given
        var state = SearchFeature.State(
            currentUserId: TestData.currentUser.profile.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )
        state.addFriendConfirmTarget = TestData.searchResult1Profile

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
                currentUserId: TestData.currentUser.profile.id,
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

    // MARK: - Search Button Tapped Tests

    @Test
    func test_searchButtonTapped_withValidQuery_callsSearchUsers() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                searchQuery: "test user",
                currentUserId: TestData.currentUser.profile.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        } withDependencies: {
            $0.userRepository.searchUsers = { _ in TestData.searchResultProfiles }
        }

        // When
        await store.send(.searchButtonTapped) {
            $0.isSearching = true
            $0.hasSearched = true
            $0.error = nil
        }

        // Then
        await store.receive(\.searchResultsLoaded.success) {
            $0.isSearching = false
            $0.searchResults = TestData.searchResultProfiles
        }
    }

    @Test
    func test_searchResultsLoaded_failure_setsError() async {
        // Given
        var state = SearchFeature.State(
            currentUserId: TestData.currentUser.profile.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )
        state.searchQuery = "test"
        state.isSearching = true

        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // When
        await store.send(.searchResultsLoaded(.failure(TestError.networkError))) {
            // Then
            $0.isSearching = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Add Friend Tests

    @Test
    func test_addFriendConfirmed_callsAddFriendAPI() async {
        // Given
        var state = SearchFeature.State(
            currentUserId: TestData.currentUser.profile.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )
        state.addFriendConfirmTarget = TestData.searchResult1Profile

        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.userRepository.addFriend = { _ in }
        }

        // When
        await store.send(.addFriendConfirmed) {
            $0.addingFriendId = TestData.searchResult1Profile.id
            $0.addFriendConfirmTarget = nil
        }

        // Then
        await store.receive(\.friendAdded.success) {
            $0.currentUserFriendIds.append(TestData.searchResult1Profile.id)
            $0.addingFriendId = nil
        }
    }

    @Test
    func test_addFriendConfirmed_withNoTarget_doesNothing() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                currentUserId: TestData.currentUser.profile.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        }

        // When & Then: No effects should be produced
        await store.send(.addFriendConfirmed)
    }

    @Test
    func test_friendAdded_failure_setsError() async {
        // Given
        var state = SearchFeature.State(
            currentUserId: TestData.currentUser.profile.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )
        state.addingFriendId = TestData.searchResult1Profile.id

        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        // When
        await store.send(.friendAdded(.failure(TestError.networkError))) {
            // Then
            $0.addingFriendId = nil
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Dismiss Tests

    @Test
    func test_dismissButtonTapped_triggersDismissal() async {
        // Given
        let store = TestStore(
            initialState: SearchFeature.State(
                currentUserId: TestData.currentUser.profile.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        ) {
            SearchFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        // When & Then
        await store.send(.dismissButtonTapped)
    }
}
