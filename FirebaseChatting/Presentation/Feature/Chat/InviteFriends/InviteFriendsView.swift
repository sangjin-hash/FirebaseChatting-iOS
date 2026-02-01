//
//  InviteFriendsView.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import SwiftUI
import ComposableArchitecture

struct InviteFriendsView: View {
    @Bindable var store: StoreOf<InviteFriendsFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 선택된 친구 수 표시
                selectionHeader

                // 친구 목록
                if store.friends.isEmpty {
                    emptyView
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

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("초대할 수 있는 친구가 없습니다")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var friendList: some View {
        List {
            ForEach(store.friends) { friend in
                InviteFriendSelectionRow(
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

    private var inviteButton: some View {
        Button(Strings.Chat.invite) {
            store.send(.inviteButtonTapped)
        }
        .disabled(!store.canInvite)
    }
}

// MARK: - InviteFriendSelectionRow

private struct InviteFriendSelectionRow: View {
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
