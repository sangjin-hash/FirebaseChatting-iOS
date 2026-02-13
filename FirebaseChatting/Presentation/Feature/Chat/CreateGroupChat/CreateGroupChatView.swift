//
//  CreateGroupChatView.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import SwiftUI
import ComposableArchitecture

struct CreateGroupChatView: View {
    @Bindable var store: StoreOf<CreateGroupChatFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SelectionHeaderComponent(selectedCount: store.selectedCount)
                friendList
            }
            .navigationTitle(Strings.Chat.createGroupChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.CreateGroupChat.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    createButton
                }
            }
        }
    }
}

// MARK: - Subviews

private extension CreateGroupChatView {
    var friendList: some View {
        Group {
            if store.friends.isEmpty {
                EmptyStateComponent(
                    systemImageName: "person.2",
                    title: Strings.Chat.noFriendsForGroupChat
                )
            } else {
                List {
                    ForEach(store.friends) { friend in
                        FriendSelectionRowComponent(
                            profile: friend,
                            isSelected: store.selectedFriendIds.contains(friend.id),
                            onTap: {
                                store.send(.friendToggled(friend.id))
                            }
                        )
                        .accessibilityIdentifier(AccessibilityID.CreateGroupChat.friend(friend.id))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    var createButton: some View {
        Button {
            store.send(.createButtonTapped)
        } label: {
            Text(Strings.Chat.create)
        }
        .disabled(!store.canCreate)
        .accessibilityIdentifier(AccessibilityID.CreateGroupChat.createButton)
    }
}

// MARK: - Preview

#Preview("친구 목록") {
    CreateGroupChatView(
        store: Store(initialState: CreateGroupChatFeature.State(
            currentUserId: "user-1",
            friends: [
                Profile(id: "friend-1", nickname: "홍길동"),
                Profile(id: "friend-2", nickname: "김철수"),
                Profile(id: "friend-3", nickname: "이영희")
            ]
        )) {
            CreateGroupChatFeature()
        }
    )
}

#Preview("친구 선택됨") {
    var state = CreateGroupChatFeature.State(
        currentUserId: "user-1",
        friends: [
            Profile(id: "friend-1", nickname: "홍길동"),
            Profile(id: "friend-2", nickname: "김철수"),
            Profile(id: "friend-3", nickname: "이영희")
        ]
    )
    state.selectedFriendIds = ["friend-1", "friend-2"]

    return CreateGroupChatView(
        store: Store(initialState: state) {
            CreateGroupChatFeature()
        }
    )
}
