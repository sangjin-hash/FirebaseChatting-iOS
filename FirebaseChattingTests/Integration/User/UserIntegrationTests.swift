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
        homeState.friends = TestData.friendProfiles

        let store = TestStore(initialState: homeState) {
            HomeFeature()
        }

        // When: User taps search button
        await store.send(.searchButtonTapped) {
            // Then: SearchFeature is created with correct friendIds from currentUser
            $0.searchDestination = SearchFeature.State(
                currentUserId: TestData.currentUser.profile.id,
                currentUserFriendIds: TestData.currentUser.friendIds
            )
        }

        // Verify: friendIds are correctly passed
        #expect(store.state.searchDestination?.currentUserFriendIds == ["friend-1", "friend-2"])
    }

    // MARK: - 2.2 Home updates friends when SearchFeature adds friend (via Firestore snapshot)
    // Note: HomeFeature doesn't directly update friends on friendAdded.
    // The update flow is: Firestore → MainTabFeature.userDocumentUpdated → home.friends update
    // This test verifies that HomeFeature does NOT change state on friendAdded (it waits for snapshot)

    @Test
    func test_homeDoesNotUpdateFriends_whenSearchAddsFriend() async {
        // Given: HomeFeature with no friends and open search
        var homeState = HomeFeature.State()
        homeState.currentUser = TestData.currentUserWithNoFriends
        homeState.friends = []
        homeState.searchDestination = SearchFeature.State(
            currentUserId: TestData.currentUserWithNoFriends.profile.id,
            currentUserFriendIds: []
        )

        let store = TestStore(initialState: homeState) {
            HomeFeature()
        }

        // When: SearchFeature reports friend added (simulating API success)
        // Then: HomeFeature does NOT change its state (waits for Firestore snapshot via MainTabFeature)
        await store.send(.searchDestination(.presented(.friendAdded(.success(TestData.strangerProfile))))) {
            // SearchFeature updates its own state
            $0.searchDestination?.currentUserFriendIds = [TestData.strangerProfile.id]
            $0.searchDestination?.addingFriendId = nil
        }

        // Verify: HomeFeature friends and currentUser are unchanged
        #expect(store.state.friends == [])
        #expect(store.state.currentUser?.friendIds == [])
    }

    // MARK: - 3.1 Login Failure Shows Error

    @Test
    func test_loginFailure_showsError() async {
        // Given: AuthFeature in unauthenticated state
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authRepository.checkAuthenticationState = { nil }
            $0.authRepository.signInWithGoogle = { throw AuthError.firebaseError("Network error") }
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
            searchResults: [TestData.strangerProfile],
            currentUserId: TestData.currentUser.profile.id,
            currentUserFriendIds: TestData.currentUser.friendIds
        )

        let store = TestStore(initialState: searchState) {
            SearchFeature()
        } withDependencies: {
            $0.userRepository.addFriend = { _ in throw TestError.serverError }
        }

        // When: User taps add friend button
        await store.send(.addFriendButtonTapped(TestData.strangerProfile)) {
            $0.addFriendConfirmTarget = TestData.strangerProfile
        }

        // When: User confirms add friend
        await store.send(.addFriendConfirmed) {
            $0.addingFriendId = TestData.strangerProfile.id
            $0.addFriendConfirmTarget = nil
        }

        // Then: Add friend fails with error
        await store.receive(\.friendAdded.failure) {
            $0.addingFriendId = nil
            $0.error = TestError.serverError.localizedDescription
        }

        // Verify: friendIds unchanged
        #expect(store.state.currentUserFriendIds == TestData.currentUser.friendIds)
        #expect(!store.state.currentUserFriendIds.contains(TestData.strangerProfile.id))
    }
}
