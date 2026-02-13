//
//  InviteFriendsView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct InviteFriendsView: View {
    @Bindable var store: StoreOf<InviteFriendsFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SelectionHeaderComponent(selectedCount: store.selectedCount)

                if store.friends.isEmpty {
                    emptyContent
                } else {
                    friendList
                }
            }
            .navigationTitle(Strings.Chat.inviteFriends)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    inviteButton
                }
            }
        }
    }
}

// MARK: - Subviews

private extension InviteFriendsView {
    var emptyContent: some View {
        EmptyStateComponent(
            systemImageName: "person.badge.plus",
            title: "초대할 수 있는 친구가 없습니다"
        )
    }

    var friendList: some View {
        List {
            ForEach(store.friends) { friend in
                FriendSelectionRowComponent(
                    profile: friend,
                    isSelected: store.selectedFriendIds.contains(friend.id),
                    onTap: {
                        store.send(.friendToggled(friend.id))
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    var inviteButton: some View {
        Button(Strings.Chat.invite) {
            store.send(.inviteButtonTapped)
        }
        .disabled(!store.canInvite)
        .accessibilityIdentifier(AccessibilityID.InviteFriends.inviteButton)
    }
}

// MARK: - Preview

#Preview("친구 목록") {
    InviteFriendsView(
        store: Store(initialState: InviteFriendsFeature.State(
            friends: [
                Profile(id: "friend-1", nickname: "홍길동"),
                Profile(id: "friend-2", nickname: "김철수")
            ]
        )) {
            InviteFriendsFeature()
        }
    )
}

#Preview("빈 목록") {
    InviteFriendsView(
        store: Store(initialState: InviteFriendsFeature.State(
            friends: []
        )) {
            InviteFriendsFeature()
        }
    )
}
