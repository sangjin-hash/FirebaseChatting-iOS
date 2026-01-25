//
//  AuthFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
@preconcurrency import ComposableArchitecture

@Reducer
struct AuthFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var authenticationState: AuthenticationState = .unauthenticated
        var isLoading = false
        var userId: String?
        var user: User?
        var error: AuthError?
        var mainTab: MainTabFeature.State?
    }

    enum AuthenticationState: Equatable {
        case unauthenticated
        case authenticated
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case authCheckCompleted(String?)

        case googleLoginButtonTapped
        case googleLoginResponse(Result<User, AuthError>)

        case logoutButtonTapped
        case logoutCompleted
        case logoutFailed(AuthError)

        case mainTab(MainTabFeature.Action)
    }

    // MARK: - Dependency

    @Dependency(\.authRepository) var authRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            // 인증 상태 확인
            case .onAppear:
                // Firebase Auth 상태 확인
                let userId = authRepository.checkAuthenticationState()
                return .send(.authCheckCompleted(userId))

            case let .authCheckCompleted(userId):
                if let userId {
                    state.userId = userId
                    state.authenticationState = .authenticated
                    state.mainTab = MainTabFeature.State()
                } else {
                    state.authenticationState = .unauthenticated
                    state.mainTab = nil
                }
                return .none

            // Google 로그인
            case .googleLoginButtonTapped:
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let user = try await authRepository.signInWithGoogle()
                        await send(.googleLoginResponse(.success(user)))
                    } catch let error as AuthError {
                        await send(.googleLoginResponse(.failure(error)))
                    } catch {
                        await send(.googleLoginResponse(.failure(.firebaseError(error.localizedDescription))))
                    }
                }

            case let .googleLoginResponse(.success(user)):
                state.isLoading = false
                state.user = user
                state.userId = user.id
                state.authenticationState = .authenticated
                state.mainTab = MainTabFeature.State()
                return .none

            case let .googleLoginResponse(.failure(error)):
                state.isLoading = false
                state.error = error
                return .none

            // 로그아웃
            case .logoutButtonTapped:
                return .run { send in
                    do {
                        try await authRepository.logout()
                        await send(.logoutCompleted)
                    } catch let error as AuthError {
                        await send(.logoutFailed(error))
                    } catch {
                        await send(.logoutFailed(.firebaseError(error.localizedDescription)))
                    }
                }

            case .logoutCompleted:
                state.authenticationState = .unauthenticated
                state.userId = nil
                state.user = nil
                state.mainTab = nil
                return .none

            case .logoutFailed:
                // 로그아웃 실패는 무시 (로컬 상태만 초기화)
                return .none

            case .mainTab(.delegate(.logoutSucceeded)):
                state.authenticationState = .unauthenticated
                state.userId = nil
                state.user = nil
                state.mainTab = nil
                return .none

            case .mainTab:
                return .none
            }
        }
        .ifLet(\.mainTab, action: \.mainTab) {
            MainTabFeature()
        }
    }
}
