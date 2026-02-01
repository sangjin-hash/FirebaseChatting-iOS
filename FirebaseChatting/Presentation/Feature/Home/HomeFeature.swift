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
        var friends: [Profile] = []
        var hasFriendsLoaded: Bool = false
        var error: String?
        @Presents var searchDestination: SearchFeature.State?
        @Presents var chatRoomDestination: ChatRoomFeature.State?
        var chatConfirmTarget: Profile? = nil
        var showLogoutConfirm: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable {
        case logoutButtonTapped
        case logoutConfirmDismissed
        case logoutConfirmed
        case logoutCompleted(Result<Void, Error>)
        case searchButtonTapped
        case searchDestination(PresentationAction<SearchFeature.Action>)
        case chatButtonTapped(Profile)
        case chatConfirmDismissed
        case chatConfirmed
        case chatRoomDestination(PresentationAction<ChatRoomFeature.Action>)

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case logoutSucceeded
        }

        // Equatable 준수를 위한 에러 비교
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.logoutButtonTapped, .logoutButtonTapped),
                 (.logoutConfirmDismissed, .logoutConfirmDismissed),
                 (.logoutConfirmed, .logoutConfirmed),
                 (.searchButtonTapped, .searchButtonTapped),
                 (.chatConfirmDismissed, .chatConfirmDismissed),
                 (.chatConfirmed, .chatConfirmed):
                return true
            case let (.chatButtonTapped(lhs), .chatButtonTapped(rhs)):
                return lhs == rhs
            case let (.logoutCompleted(lhsResult), .logoutCompleted(rhsResult)):
                switch (lhsResult, rhsResult) {
                case (.success, .success), (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.searchDestination(lhs), .searchDestination(rhs)):
                return lhs == rhs
            case let (.chatRoomDestination(lhs), .chatRoomDestination(rhs)):
                return lhs == rhs
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Dependency

    @Dependency(\.authRepository) var authRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
                    currentUserId: user.profile.id,
                    currentUserFriendIds: user.friendIds
                )
                return .none

            case .searchDestination(.presented(.friendAdded(.success(_)))):
                // Firestore에 저장 → snapshot이 감지 → MainTabFeature에서 자동 업데이트
                // 따라서 여기서는 아무것도 하지 않음
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
                guard let target = state.chatConfirmTarget,
                      let currentUser = state.currentUser else { return .none }
                state.chatConfirmTarget = nil
                // 빈 ChatRoom 화면으로 이동
                let chatRoomId = ChatRoom.directChatRoomId(uid1: currentUser.profile.id, uid2: target.id)
                state.chatRoomDestination = ChatRoomFeature.State(
                    chatRoomId: chatRoomId,
                    currentUserId: currentUser.profile.id,
                    otherUser: target
                )
                return .none

            case .chatRoomDestination:
                return .none
            }
        }
        .ifLet(\.$searchDestination, action: \.searchDestination) {
            SearchFeature()
        }
        .ifLet(\.$chatRoomDestination, action: \.chatRoomDestination) {
            ChatRoomFeature()
        }
    }
}
