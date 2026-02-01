//
//  InviteFriendsFeature.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import ComposableArchitecture

@Reducer
struct InviteFriendsFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String { "inviteFriends" }
        var friends: [Profile]  // 초대 가능한 친구 (채팅방에 없는 친구들)
        var selectedFriendIds: Set<String> = []
        var error: String?

        var canInvite: Bool {
            !selectedFriendIds.isEmpty
        }

        var selectedCount: Int {
            selectedFriendIds.count
        }

        init(friends: [Profile]) {
            self.friends = friends
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case friendToggled(String)
        case inviteButtonTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case friendsInvited([String])
        }
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .friendToggled(friendId):
                if state.selectedFriendIds.contains(friendId) {
                    state.selectedFriendIds.remove(friendId)
                } else {
                    state.selectedFriendIds.insert(friendId)
                }
                return .none

            case .inviteButtonTapped:
                guard state.canInvite else { return .none }
                let selectedIds = Array(state.selectedFriendIds)
                return .send(.delegate(.friendsInvited(selectedIds)))

            case .delegate:
                return .none
            }
        }
    }
}
