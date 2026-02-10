//
//  FriendSelectionRowComponent.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct FriendSelectionRowComponent: View {
    let profile: Profile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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

                Text(profile.nickname ?? Strings.Common.noName)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

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

#Preview("선택됨") {
    FriendSelectionRowComponent(
        profile: Profile(id: "1", nickname: "홍길동"),
        isSelected: true,
        onTap: {}
    )
    .padding()
}

#Preview("미선택") {
    FriendSelectionRowComponent(
        profile: Profile(id: "1", nickname: "김철수"),
        isSelected: false,
        onTap: {}
    )
    .padding()
}
