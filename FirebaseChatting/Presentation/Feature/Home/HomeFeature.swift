//
//  HomeFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct HomeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var currentUser: User?
        var friends: [User] = []
        var isLoading: Bool = false
        var error: String?
        @Presents var searchDestination: SearchFeature.State?
        var chatConfirmTarget: User? = nil
        var showLogoutConfirm: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case userWithFriendsLoaded(Result<(User, [User]), Error>)
        case logoutButtonTapped
        case logoutConfirmDismissed
        case logoutConfirmed
        case logoutCompleted(Result<Void, Error>)
        case searchButtonTapped
        case searchDestination(PresentationAction<SearchFeature.Action>)
        case chatButtonTapped(User)
        case chatConfirmDismissed
        case chatConfirmed

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case logoutSucceeded
        }

        // Equatable 준수를 위한 에러 비교
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.logoutButtonTapped, .logoutButtonTapped),
                 (.logoutConfirmDismissed, .logoutConfirmDismissed),
                 (.logoutConfirmed, .logoutConfirmed),
                 (.searchButtonTapped, .searchButtonTapped),
                 (.chatConfirmDismissed, .chatConfirmDismissed),
                 (.chatConfirmed, .chatConfirmed):
                return true
            case let (.chatButtonTapped(lhs), .chatButtonTapped(rhs)):
                return lhs == rhs
            case let (.userWithFriendsLoaded(lhsResult), .userWithFriendsLoaded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhsValue), .success(rhsValue)):
                    return lhsValue.0 == rhsValue.0 && lhsValue.1 == rhsValue.1
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.logoutCompleted(lhsResult), .logoutCompleted(rhsResult)):
                switch (lhsResult, rhsResult) {
                case (.success, .success), (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.searchDestination(lhs), .searchDestination(rhs)):
                return lhs == rhs
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Dependency

    @Dependency(\.userRepository) var userRepository
    @Dependency(\.authRepository) var authRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [userRepository] send in
                    do {
                        let result = try await userRepository.getUserWithFriends()
                        await send(.userWithFriendsLoaded(.success((result.user, result.friends))))
                    } catch {
                        await send(.userWithFriendsLoaded(.failure(error)))
                    }
                }

            case let .userWithFriendsLoaded(.success((user, friends))):
                state.isLoading = false
                state.currentUser = user
                state.friends = friends
                state.error = nil
                return .none

            case let .userWithFriendsLoaded(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .logoutButtonTapped:
                state.showLogoutConfirm = true
                return .none

            case .logoutConfirmDismissed:
                state.showLogoutConfirm = false
                return .none

            case .logoutConfirmed:
                state.showLogoutConfirm = false
                return .run { [authRepository] send in
                    do {
                        try await authRepository.logout()
                        await send(.logoutCompleted(.success(())))
                    } catch {
                        await send(.logoutCompleted(.failure(error)))
                    }
                }

            case .logoutCompleted(.success):
                return .send(.delegate(.logoutSucceeded))

            case let .logoutCompleted(.failure(error)):
                state.error = error.localizedDescription
                return .none

            case .delegate:
                return .none

            case .searchButtonTapped:
                guard let user = state.currentUser else { return .none }
                state.searchDestination = SearchFeature.State(
                    currentUserId: user.id,
                    currentUserFriendIds: user.friendIds
                )
                return .none

            case let .searchDestination(.presented(.friendAdded(.success(newFriend)))):
                // 친구 추가 성공 시 직접 friends 배열에 추가 (API 재호출 없음)
                state.friends.append(newFriend)
                // currentUser의 friendIds도 업데이트
                state.currentUser?.friendIds.append(newFriend.id)
                return .none

            case .searchDestination:
                return .none

            case let .chatButtonTapped(friend):
                state.chatConfirmTarget = friend
                return .none

            case .chatConfirmDismissed:
                state.chatConfirmTarget = nil
                return .none

            case .chatConfirmed:
                // TODO: 1:1 채팅 시작 로직 구현
                state.chatConfirmTarget = nil
                return .none
            }
        }
        .ifLet(\.$searchDestination, action: \.searchDestination) {
            SearchFeature()
        }
    }
}
