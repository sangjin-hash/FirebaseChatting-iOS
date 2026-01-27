//
//  SearchFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct SearchFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var searchQuery: String = ""
        var searchResults: [Profile] = []
        var currentUserId: String = ""
        var currentUserFriendIds: [String]
        var isSearching: Bool = false
        var hasSearched: Bool = false
        var addingFriendId: String? = nil
        var error: String?
        var addFriendConfirmTarget: Profile? = nil
    }

    // MARK: - Action

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case searchButtonTapped
        case searchResultsLoaded(Result<[Profile], Error>)
        case addFriendButtonTapped(Profile)
        case addFriendConfirmDismissed
        case addFriendConfirmed
        case friendAdded(Result<Profile, Error>)
        case dismissButtonTapped

        // Equatable 준수를 위한 에러 비교
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.binding(lhs), .binding(rhs)):
                return lhs == rhs
            case (.searchButtonTapped, .searchButtonTapped),
                 (.dismissButtonTapped, .dismissButtonTapped),
                 (.addFriendConfirmDismissed, .addFriendConfirmDismissed),
                 (.addFriendConfirmed, .addFriendConfirmed):
                return true
            case let (.searchResultsLoaded(lhsResult), .searchResultsLoaded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhsValue), .success(rhsValue)):
                    return lhsValue == rhsValue
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case let (.addFriendButtonTapped(lhs), .addFriendButtonTapped(rhs)):
                return lhs == rhs
            case let (.friendAdded(lhsResult), .friendAdded(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhsUser), .success(rhsUser)):
                    return lhsUser == rhsUser
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        }
    }

    // MARK: - Dependency

    @Dependency(\.userRepository) var userRepository
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .searchButtonTapped:
                let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return .none }

                state.isSearching = true
                state.hasSearched = true
                state.error = nil

                return .run { [userRepository, query] send in
                    do {
                        let users = try await userRepository.searchUsers(query)
                        await send(.searchResultsLoaded(.success(users)))
                    } catch {
                        await send(.searchResultsLoaded(.failure(error)))
                    }
                }

            case let .searchResultsLoaded(.success(users)):
                state.isSearching = false
                state.searchResults = users
                return .none

            case let .searchResultsLoaded(.failure(error)):
                state.isSearching = false
                state.error = error.localizedDescription
                return .none

            case let .addFriendButtonTapped(user):
                state.addFriendConfirmTarget = user
                return .none

            case .addFriendConfirmDismissed:
                state.addFriendConfirmTarget = nil
                return .none

            case .addFriendConfirmed:
                guard let target = state.addFriendConfirmTarget else { return .none }
                state.addingFriendId = target.id
                state.addFriendConfirmTarget = nil

                return .run { [userRepository] send in
                    do {
                        try await userRepository.addFriend(target.id)
                        await send(.friendAdded(.success(target)))
                    } catch {
                        await send(.friendAdded(.failure(error)))
                    }
                }

            case let .friendAdded(.success(user)):
                // 친구 추가 성공 시 currentUserFriendIds 업데이트
                state.currentUserFriendIds.append(user.id)
                state.addingFriendId = nil
                return .none

            case let .friendAdded(.failure(error)):
                state.addingFriendId = nil
                state.error = error.localizedDescription
                return .none

            case .dismissButtonTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
