//
//  UserIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct UserIntegrationTests {

    // MARK: - 2.1 Home opens Search with correct friendIds

    @Test
    func test_homeOpensSearch_withCorrectFriendIds() async {
        // Given: HomeFeature with existing friends
        var homeState = HomeFeature.State()
        homeState.currentUser = TestData.currentUser
        homeState.friends = TestData.friends

        let store = TestStore(initialState: homeState) {
            HomeFeature()
        } withDependencies: {
            $0.userRepository = .mock()
            $0.authRepository = .mock()
        }

        // When: User taps search button
        await store.send(.searchButtonTapped) {
            // Then: SearchFeature is created with correct friendIds from currentUser
            $0.searchDestination = SearchFeature.State(
                currentUserId: TestData.currentUser.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        }

        // Verify: friendIds are correctly passed
        #expect(store.state.searchDestination?.currentUserFriendIds == ["friend-1", "friend-2"])
    }

    // MARK: - 2.2 Home updates friends when SearchFeature adds friend

    @Test
    func test_homeUpdatesFriends_whenSearchAddsFriend() async {
        // Given: HomeFeature with no friends and open search
        var homeState = HomeFeature.State()
        homeState.currentUser = TestData.currentUserWithNoFriends
        homeState.friends = []
        homeState.searchDestination = SearchFeature.State(
            currentUserId: TestData.currentUserWithNoFriends.id,
            currentUserFriendIds: []
        )

        let store = TestStore(initialState: homeState) {
            HomeFeature()
        } withDependencies: {
            $0.userRepository = .mock()
            $0.authRepository = .mock()
        }

        // When: SearchFeature reports friend added (simulating API success)
        await store.send(.searchDestination(.presented(.friendAdded(.success(TestData.stranger))))) {
            // Then: HomeFeature updates its state
            $0.friends = [TestData.stranger]
            $0.currentUser?.friendIds = [TestData.stranger.id]
            // SearchFeature also updates
            $0.searchDestination?.currentUserFriendIds = [TestData.stranger.id]
            $0.searchDestination?.addingFriendId = nil
        }
    }

    // MARK: - 3.1 Login Failure Shows Error

    @Test
    func test_loginFailure_showsError() async {
        // Given: AuthFeature in unauthenticated state
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authRepository = .mock(
                checkAuthenticationState: { nil },
                signInWithGoogle: { throw AuthError.firebaseError("Network error") }
            )
        }

        // When: User taps login button
        await store.send(.googleLoginButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        // Then: Login fails with error
        await store.receive(\.googleLoginResponse.failure) {
            $0.isLoading = false
            $0.error = .firebaseError("Network error")
        }

        // Verify: MainTab was not created
        #expect(store.state.mainTab == nil)
        #expect(store.state.authenticationState == .unauthenticated)
    }

    // MARK: - 3.2 Add Friend Failure Shows Error

    @Test
    func test_addFriendFailure_showsError() async {
        // Given: SearchFeature with search results
        let searchState = SearchFeature.State(
            searchQuery: "test",
            searchResults: [TestData.stranger],
            currentUserId: TestData.currentUser.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )

        let store = TestStore(initialState: searchState) {
            SearchFeature()
        } withDependencies: {
            $0.userRepository = .mock(
                addFriend: { _ in throw TestError.serverError }
            )
        }

        // When: User taps add friend button
        await store.send(.addFriendButtonTapped(TestData.stranger)) {
            $0.addFriendConfirmTarget = TestData.stranger
        }

        // When: User confirms add friend
        await store.send(.addFriendConfirmed) {
            $0.addingFriendId = TestData.stranger.id
            $0.addFriendConfirmTarget = nil
        }

        // Then: Add friend fails with error
        await store.receive(\.friendAdded.failure) {
            $0.addingFriendId = nil
            $0.error = TestError.serverError.localizedDescription
        }

        // Verify: friendIds unchanged
        #expect(store.state.currentUserFriendIds == TestData.currentUser.friendIds)
        #expect(!store.state.currentUserFriendIds.contains(TestData.stranger.id))
    }
}
