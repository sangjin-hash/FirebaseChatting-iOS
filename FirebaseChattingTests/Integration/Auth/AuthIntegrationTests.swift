//
//  AuthIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct AuthIntegrationTests {

    // MARK: - 1.1 Auto Login Flow

    @Test
    func test_autoLoginFlow_success() async {
        // Given: AuthFeature with existing userId in keychain
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authRepository = .mock(
                checkAuthenticationState: { TestData.currentUser.id }
            )
        }

        // When: onAppear triggers auth check
        await store.send(.onAppear)

        // Then: Auth check completes with userId and MainTab is created
        await store.receive(\.authCheckCompleted) {
            $0.userId = TestData.currentUser.id
            $0.authenticationState = .authenticated
            $0.mainTab = MainTabFeature.State()
        }
    }

    // MARK: - 1.2 Google Login Flow

    @Test
    func test_googleLoginFlow_success() async {
        // Given: AuthFeature with no existing session (unauthenticated)
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authRepository = .mock(
                checkAuthenticationState: { nil },
                signInWithGoogle: { TestData.currentUser }
            )
        }

        // When: Check auth state first (no user)
        await store.send(.onAppear)

        // authCheckCompleted with nil - no state changes needed
        // (authenticationState is already .unauthenticated, mainTab is already nil)
        await store.receive(\.authCheckCompleted)

        // When: User taps login button
        await store.send(.googleLoginButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        // Then: Login succeeds and MainTab is created
        await store.receive(\.googleLoginResponse.success) {
            $0.isLoading = false
            $0.user = TestData.currentUser
            $0.userId = TestData.currentUser.id
            $0.authenticationState = .authenticated
            $0.mainTab = MainTabFeature.State()
        }
    }

    // MARK: - 1.3 Logout Flow (Delegate from MainTab)

    @Test
    func test_logoutFlow_delegateFromMainTab() async {
        // Given: Authenticated state with MainTab
        var initialState = AuthFeature.State()
        initialState.authenticationState = .authenticated
        initialState.userId = TestData.currentUser.id
        initialState.user = TestData.currentUser
        initialState.mainTab = MainTabFeature.State()

        let store = TestStore(initialState: initialState) {
            AuthFeature()
        }

        // When: MainTabFeature emits logout delegate (simulating delegate chain)
        await store.send(.mainTab(.delegate(.logoutSucceeded))) {
            // Then: AuthFeature clears all state
            $0.authenticationState = .unauthenticated
            $0.userId = nil
            $0.user = nil
            $0.mainTab = nil
        }
    }
}
