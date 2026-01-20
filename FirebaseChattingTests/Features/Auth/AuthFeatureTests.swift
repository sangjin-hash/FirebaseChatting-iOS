//
//  AuthFeatureTests.swift
//  ChattingExampleTests
//
//  Created by Claude Code
//

import Testing
import ComposableArchitecture
@testable import FirebaseChatting

struct AuthFeatureTests {

    // MARK: - 인증 상태 확인 테스트

    @Test @MainActor
    func testCheckAuthenticationState_WhenLoggedIn() async {
        // Given: 로그인된 상태
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.keychainClient.loadToken = { nil }
            $0.authClient.checkAuthenticationState = { "user-123" }
        }

        // When: 앱 시작 시 인증 상태 확인
        await store.send(.onAppear)

        // Then: authenticated 상태로 변경
        await store.receive(\.authCheckCompleted) {
            $0.userId = "user-123"
            $0.authenticationState = .authenticated
        }
    }

    @Test @MainActor
    func testCheckAuthenticationState_WhenLoggedOut() async {
        // Given: 로그아웃 상태
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.keychainClient.loadToken = { nil }
            $0.authClient.checkAuthenticationState = { nil }
        }

        // When: 앱 시작 시 인증 상태 확인
        await store.send(.onAppear)

        // Then: unauthenticated 상태 유지
        await store.receive(\.authCheckCompleted)
    }

    @Test @MainActor
    func testCheckAuthenticationState_WithSavedToken_AutoLogin() async {
        // Given: 키체인에 저장된 토큰이 있는 상태
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.keychainClient.loadToken = { "saved-user-123" }
            // authClient.checkAuthenticationState는 호출되지 않아야 함
            $0.authClient.checkAuthenticationState = { nil }
        }

        // When: 앱 시작 시 인증 상태 확인
        await store.send(.onAppear)

        // Then: 키체인의 토큰으로 자동 로그인
        await store.receive(\.authCheckCompleted) {
            $0.userId = "saved-user-123"
            $0.authenticationState = .authenticated
        }
    }

    // MARK: - Google 로그인 테스트

    @Test @MainActor
    func testGoogleLogin_Success() async {
        // Given: Google 로그인 성공 Mock
        let mockUser = User(
            id: "123",
            name: "Test User",
            profileURL: "https://example.com/photo.jpg"
        )

        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithGoogle = { mockUser }
            $0.keychainClient.saveToken = { _ in }
        }

        // When: Google 로그인 버튼 탭
        await store.send(.googleLoginButtonTapped) {
            // Then: 로딩 상태 시작
            $0.isLoading = true
            $0.error = nil
        }

        // Then: 로그인 성공
        await store.receive(\.googleLoginResponse.success) {
            $0.isLoading = false
            $0.user = mockUser
            $0.userId = "123"
            $0.authenticationState = .authenticated
        }
    }

    @Test @MainActor
    func testGoogleLogin_Success_SavesTokenToKeychain() async {
        // Given: Google 로그인 성공 Mock
        let mockUser = User(
            id: "123",
            name: "Test User",
            profileURL: "https://example.com/photo.jpg"
        )

        var savedToken: String?
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithGoogle = { mockUser }
            $0.keychainClient.saveToken = { token in
                savedToken = token
            }
        }

        // When: Google 로그인 버튼 탭
        await store.send(.googleLoginButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        // Then: 로그인 성공 및 키체인에 토큰 저장
        await store.receive(\.googleLoginResponse.success) {
            $0.isLoading = false
            $0.user = mockUser
            $0.userId = "123"
            $0.authenticationState = .authenticated
        }

        // Verify: 키체인에 userId가 저장되었는지 확인
        #expect(savedToken == "123")
    }

    @Test @MainActor
    func testGoogleLogin_Failure() async {
        // Given: Google 로그인 실패 Mock
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithGoogle = { throw AuthError.tokenError }
        }

        // When: Google 로그인 버튼 탭
        await store.send(.googleLoginButtonTapped) {
            // Then: 로딩 상태 시작
            $0.isLoading = true
            $0.error = nil
        }

        // Then: 로그인 실패
        await store.receive(\.googleLoginResponse.failure) {
            $0.isLoading = false
            $0.error = AuthError.tokenError
        }
    }

    // MARK: - 로그아웃 테스트

    @Test @MainActor
    func testLogout_Success() async {
        // Given: 로그인된 상태
        var state = AuthFeature.State()
        state.authenticationState = .authenticated
        state.userId = "123"
        state.user = User(id: "123", name: "Test", profileURL: nil)

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.logout = { }
            $0.keychainClient.deleteToken = { }
        }

        // When: 로그아웃 버튼 탭
        await store.send(.logoutButtonTapped)

        // Then: 로그아웃 성공
        await store.receive(.logoutCompleted) {
            $0.authenticationState = .unauthenticated
            $0.userId = nil
            $0.user = nil
        }
    }

    @Test @MainActor
    func testLogout_Success_DeletesTokenFromKeychain() async {
        // Given: 로그인된 상태
        var state = AuthFeature.State()
        state.authenticationState = .authenticated
        state.userId = "123"
        state.user = User(id: "123", name: "Test", profileURL: nil)

        var tokenDeleted = false
        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.logout = { }
            $0.keychainClient.deleteToken = {
                tokenDeleted = true
            }
        }

        // When: 로그아웃 버튼 탭
        await store.send(.logoutButtonTapped)

        // Then: 로그아웃 성공 및 키체인에서 토큰 삭제
        await store.receive(.logoutCompleted) {
            $0.authenticationState = .unauthenticated
            $0.userId = nil
            $0.user = nil
        }

        // Verify: 키체인에서 토큰이 삭제되었는지 확인
        #expect(tokenDeleted == true)
    }

    @Test @MainActor
    func testLogout_Failure() async {
        // Given: 로그인된 상태
        var state = AuthFeature.State()
        state.authenticationState = .authenticated
        state.userId = "123"

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.logout = { throw AuthError.firebaseError("Logout failed") }
            $0.keychainClient.deleteToken = { }
        }

        // When: 로그아웃 버튼 탭
        await store.send(.logoutButtonTapped)

        // Then: 로그아웃 실패 (에러는 무시하고 상태 유지)
        await store.receive(\.logoutFailed)
    }

    // MARK: - 상태 초기화 테스트

    @Test @MainActor
    func testInitialState() async {
        // Given & When: 초기 상태 생성
        let state = AuthFeature.State()

        // Then: 기본값 확인
        #expect(state.authenticationState == .unauthenticated)
        #expect(state.isLoading == false)
        #expect(state.userId == nil)
        #expect(state.user == nil)
        #expect(state.error == nil)
    }
}
