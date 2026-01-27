//
//  UserRowComponent.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct UserRowComponent<TrailingContent: View>: View {
    let profile: Profile
    var imageSize: CGFloat = 44
    var caption: String? = nil
    @ViewBuilder var trailingContent: () -> TrailingContent

    init(
        profile: Profile,
        imageSize: CGFloat = 44,
        caption: String? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.profile = profile
        self.imageSize = imageSize
        self.caption = caption
        self.trailingContent = trailingContent
    }

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            AsyncImage(url: URL(string: profile.profilePhotoUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())

            // 사용자 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.nickname ?? Strings.Common.noName)
                    .font(imageSize > 50 ? .headline : .body)

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            trailingContent()
        }
    }
}

#Preview("기본") {
    UserRowComponent<EmptyView>(profile: Profile(id: "1", nickname: "테스트 유저"))
        .padding()
}

#Preview("내 프로필") {
    UserRowComponent<EmptyView>(
        profile: Profile(id: "1", nickname: "테스트 유저"),
        imageSize: 60,
        caption: "나"
    )
    .padding()
}

#Preview("채팅 버튼") {
    UserRowComponent(profile: Profile(id: "1", nickname: "테스트 유저")) {
        CircleIconButtonComponent(
            systemName: "bubble.right",
            action: {}
        )
    }
    .padding()
}

#Preview("친구 추가 버튼") {
    UserRowComponent(profile: Profile(id: "1", nickname: "테스트 유저")) {
        CircleIconButtonComponent(
            systemName: "person.badge.plus",
            action: {}
        )
    }
    .padding()
}

#Preview("친구") {
    UserRowComponent(profile: Profile(id: "1", nickname: "테스트 유저"), caption: "추가됨") {
        CircleIconButtonComponent(
            systemName: "person.badge.plus",
            isDisabled: true,
            action: {}
        )
    }
    .padding()
}
