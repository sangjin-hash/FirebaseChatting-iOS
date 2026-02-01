//
//  CreateGroupChatFeature.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import ComposableArchitecture

@Reducer
struct CreateGroupChatFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String { "createGroupChat" }
        var currentUserId: String
        var friends: [Profile]
        var selectedFriendIds: Set<String> = []

        var canCreate: Bool {
            selectedFriendIds.count >= 2
        }

        var selectedCount: Int {
            selectedFriendIds.count
        }

        init(
            currentUserId: String,
            friends: [Profile]
        ) {
            self.currentUserId = currentUserId
            self.friends = friends
        }
    }

    // MARK: - Action

    @CasePathable
    enum Action: Equatable {
        case friendToggled(String)
        case createButtonTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case groupChatPrepared(chatRoomId: String, selectedFriendIds: Set<String>)
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

            case .createButtonTapped:
                guard state.canCreate else { return .none }

                // Lazy 생성: Repository 호출 없이 chatRoomId만 생성하고 delegate 전달
                let chatRoomId = ChatRoom.groupChatRoomId()
                let selectedFriendIds = state.selectedFriendIds

                return .send(.delegate(.groupChatPrepared(chatRoomId: chatRoomId, selectedFriendIds: selectedFriendIds)))

            case .delegate:
                return .none
            }
        }
    }
}
