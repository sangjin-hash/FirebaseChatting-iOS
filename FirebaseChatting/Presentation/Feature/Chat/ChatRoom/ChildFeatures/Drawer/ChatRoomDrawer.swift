//
//  ChatRoomDrawer.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import ComposableArchitecture
import SwiftUI

struct ChatRoomDrawer: View {
    @Bindable var store: StoreOf<ChatRoomFeature>
    var widthRatio: CGFloat = 0.75

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // 반투명 배경 (탭하면 닫힘)
                if store.drawer.isOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.drawer(.setOpen(false)))
                        }
                }

                // Drawer 컨텐츠
                HStack(spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 0) {
                        // 헤더
                        Text(Strings.Chat.participants)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()

                        Divider()

                        // 참여자 목록
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(store.activeUserProfiles, id: \.id) { profile in
                                    UserRowComponent<EmptyView>(
                                        profile: profile,
                                        imageSize: 44,
                                        caption: profile.id == store.currentUserId ? Strings.Common.me : nil
                                    )
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)

                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }

                        Spacer()

                        Divider()

                        // 친구 초대 버튼
                        Button {
                            store.send(.drawer(.inviteButtonTapped))
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text(Strings.Chat.inviteFriendsButton)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .disabled(store.invitableFriends.isEmpty)
                    }
                    .frame(width: geometry.size.width * widthRatio)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(.systemBackground))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
                    .offset(x: store.drawer.isOpen ? 0 : geometry.size.width * widthRatio)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.drawer.isOpen)
    }
}

// MARK: - Preview

#Preview {
    ChatRoomDrawer(
        store: Store(initialState: ChatRoomFeature.State(
            chatRoomId: "G_test",
            currentUserId: "user-1",
            otherUser: nil
        )) {
            ChatRoomFeature()
        }
    )
}
