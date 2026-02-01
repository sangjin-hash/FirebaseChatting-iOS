//
//  MainTabFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct MainTabFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var selectedTab: MainTabType = .home
        var home = HomeFeature.State()
        var chatList = ChatListFeature.State()

        // 전역 상태 (users/{userId} snapshot 데이터)
        var currentUser: User?
        var previousFriendIds: [String] = []
        var previousChatRoomIds: [String] = []
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case selectedTabChanged(MainTabType)
        case home(HomeFeature.Action)
        case chatList(ChatListFeature.Action)

        // 전역 리스너 관련
        case userDocumentUpdated(User)
        case friendsLoaded(Result<[Profile], Error>)
        case chatRoomProfilesLoaded(Result<[String: Profile], Error>)

        // Delegate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case logoutSucceeded
        }

        // Equatable 준수를 위한 에러 비교
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.onDisappear, .onDisappear):
                return true
            case let (.selectedTabChanged(lhs), .selectedTabChanged(rhs)):
                return lhs == rhs
            case let (.home(lhs), .home(rhs)):
                return lhs == rhs
            case let (.chatList(lhs), .chatList(rhs)):
                return lhs == rhs
            case let (.userDocumentUpdated(lhs), .userDocumentUpdated(rhs)):
                return lhs == rhs
            case let (.friendsLoaded(lhsResult), .friendsLoaded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhs), .success(rhs)):
                    return lhs == rhs
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.chatRoomProfilesLoaded(lhsResult), .chatRoomProfilesLoaded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhs), .success(rhs)):
                    return lhs == rhs
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.delegate(lhs), .delegate(rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    // MARK: - Dependency

    @Dependency(\.authRepository) var authRepository
    @Dependency(\.userRepository) var userRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let userId = authRepository.checkAuthenticationState() else {
                    return .none
                }
                return .run { [userRepository] send in
                    for await user in userRepository.observeUserDocument(userId) {
                        await send(.userDocumentUpdated(user))
                    }
                }
                .cancellable(id: "observeUserDocument")

            case .onDisappear:
                return .cancel(id: "observeUserDocument")

            case let .selectedTabChanged(tab):
                state.selectedTab = tab
                return .none

            case let .userDocumentUpdated(user):
                state.currentUser = user
                // HomeFeature에 currentUser 전달
                state.home.currentUser = user
                // ChatListFeature에 currentUserId와 nickname 전달
                state.chatList.currentUserId = user.profile.id
                state.chatList.currentUserNickname = user.profile.nickname ?? ""

                var effects: [Effect<Action>] = []

                // friendIds 변경 감지
                if state.previousFriendIds != user.friendIds {
                    state.previousFriendIds = user.friendIds
                    if !user.friendIds.isEmpty {
                        effects.append(
                            .run { [userRepository, friendIds = user.friendIds] send in
                                do {
                                    let friends = try await userRepository.getFriends(friendIds)
                                    await send(.friendsLoaded(.success(friends)))
                                } catch {
                                    await send(.friendsLoaded(.failure(error)))
                                }
                            }
                        )
                    } else {
                        state.home.friends = []
                    }
                }

                // chatRooms 변경 감지
                if state.previousChatRoomIds != user.chatRooms {
                    state.previousChatRoomIds = user.chatRooms

                    // ChatListFeature에 Action dispatch로 chatRoomIds 전달 (reducer 실행)
                    effects.append(.send(.chatList(.setChatRoomIds(user.chatRooms))))

                    if !user.chatRooms.isEmpty {
                        effects.append(
                            .run { [userRepository, chatRoomIds = user.chatRooms] send in
                                do {
                                    let profiles = try await userRepository.getUserBatch(chatRoomIds)
                                    await send(.chatRoomProfilesLoaded(.success(profiles)))
                                } catch {
                                    await send(.chatRoomProfilesLoaded(.failure(error)))
                                }
                            }
                        )
                    } else {
                        state.chatList.chatRoomProfiles = [:]
                    }
                }

                return effects.isEmpty ? .none : .merge(effects)

            case let .friendsLoaded(.success(friends)):
                state.home.friends = friends
                state.chatList.friends = friends
                return .none

            case let .friendsLoaded(.failure(error)):
                state.home.error = error.localizedDescription
                return .none

            case let .chatRoomProfilesLoaded(.success(profiles)):
                state.chatList.chatRoomProfiles = profiles
                return .none

            case let .chatRoomProfilesLoaded(.failure(error)):
                state.chatList.error = error.localizedDescription
                return .none

            case .home(.delegate(.logoutSucceeded)):
                return .send(.delegate(.logoutSucceeded))

            case .home(.searchDestination(.presented(.friendAdded(.success)))):
                // Firestore에 저장 → snapshot이 감지 → 자동 업데이트
                // 따라서 여기서는 아무것도 하지 않음
                return .none

            case .home:
                return .none

            case .chatList:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
