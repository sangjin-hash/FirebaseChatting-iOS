//
//  AuthClientTests.swift
//  ChattingExampleTests
//
//  Created by Claude Code
//

import Testing
import ComposableArchitecture
@testable import FirebaseChatting

struct AuthClientTests {

    @Test @MainActor
    func testMockSignInReturnsUser() async throws {
        // Given: Mock AuthClient 설정
        let expectedUser = User(
            id: "test123",
            name: "Test User",
            profileURL: "https://example.com/photo.jpg"
        )

        let client = AuthClient.mock(
            signInWithGoogle: { expectedUser }
        )

        // When: Google 로그인 실행
        let user = try await client.signInWithGoogle()

        // Then: 예상한 사용자가 반환됨
        #expect(user.id == expectedUser.id)
        #expect(user.name == expectedUser.name)
        #expect(user.profileURL == expectedUser.profileURL)
    }

    @Test @MainActor
    func testMockCheckAuthenticationState() async {
        // Given: 로그인된 상태의 Mock
        let client = AuthClient.mock(
            checkAuthenticationState: { "user123" }
        )

        // When: 인증 상태 확인
        let userId = client.checkAuthenticationState()

        // Then: userId 반환
        #expect(userId == "user123")
    }

    @Test @MainActor
    func testMockCheckAuthenticationState_WhenLoggedOut() async {
        // Given: 로그아웃 상태의 Mock
        let client = AuthClient.mock(
            checkAuthenticationState: { nil }
        )

        // When: 인증 상태 확인
        let userId = client.checkAuthenticationState()

        // Then: nil 반환
        #expect(userId == nil)
    }

    @Test @MainActor
    func testMockLogout() async throws {
        // Given: Mock AuthClient
        var logoutCalled = false
        let client = AuthClient.mock(
            logout: {
                logoutCalled = true
            }
        )

        // When: 로그아웃 실행
        try await client.logout()

        // Then: logout 함수가 호출됨
        #expect(logoutCalled == true)
    }
}
