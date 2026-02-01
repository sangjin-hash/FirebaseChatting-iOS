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
                // 선택된 친구 수 표시
                selectionHeader

                // 친구 목록
                friendList
            }
            .navigationTitle(Strings.Chat.createGroupChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    createButton
                }
            }
        }
    }

    // MARK: - Subviews

    private var selectionHeader: some View {
        HStack {
            if store.selectedCount > 0 {
                Text("\(store.selectedCount)\(Strings.Chat.selected)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            } else {
                Text(Strings.Chat.selectFriends)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var friendList: some View {
        Group {
            if store.friends.isEmpty {
                emptyFriendsView
            } else {
                List {
                    ForEach(store.friends) { friend in
                        FriendSelectionRow(
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
        }
    }

    private var emptyFriendsView: some View {
        VStack(spacing: 12) {
            Text(Strings.Chat.noFriendsForGroupChat)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var createButton: some View {
        Button {
            store.send(.createButtonTapped)
        } label: {
            Text(Strings.Chat.create)
        }
        .disabled(!store.canCreate)
    }
}

// MARK: - FriendSelectionRow

private struct FriendSelectionRow: View {
    let profile: Profile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 프로필 이미지
                AsyncImage(url: URL(string: profile.profilePhotoUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                // 닉네임
                Text(profile.nickname ?? Strings.Common.noName)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                // 체크박스
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title2)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
