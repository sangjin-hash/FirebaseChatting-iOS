//
//  ChatListView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct ChatListView: View {
    @Bindable var store: StoreOf<ChatListFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.chatRooms.isEmpty {
                    loadingView
                } else if store.chatRooms.isEmpty {
                    emptyView
                } else {
                    chatRoomList
                }
            }
            .navigationTitle(Strings.Chat.title)
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.onDisappear)
            }
            .alert(Strings.Common.error, isPresented: .constant(store.error != nil)) {
                Button(Strings.Common.confirm) {
                    // 에러 상태 초기화
                }
            } message: {
                if let error = store.error {
                    Text(error)
                }
            }
            .confirmDialog(
                isPresented: Binding(
                    get: { store.leaveConfirmTarget != nil },
                    set: { if !$0 { store.send(.leaveConfirmDismissed) } }
                ),
                message: Strings.Chat.leaveConfirmMessage,
                onConfirm: {
                    store.send(.leaveConfirmed)
                }
            )
            .navigationDestination(
                item: $store.scope(state: \.chatRoomDestination, action: \.chatRoomDestination)
            ) { chatRoomStore in
                ChatRoomView(store: chatRoomStore)
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView(Strings.Common.loading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(Strings.Chat.noChatRooms)
                .foregroundColor(.secondary)
            Text(Strings.Chat.noChatRoomsDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatRoomList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.chatRooms) { chatRoom in
                    ChatRoomRowComponent(
                        chatRoom: chatRoom,
                        profile: store.chatRoomProfiles[chatRoom.id],
                        displayName: store.state.displayName(for: chatRoom),
                        onTap: {
                            store.send(.chatRoomTapped(chatRoom))
                        },
                        onLeave: {
                            store.send(.leaveSwipeAction(chatRoom))
                        }
                    )
                }
            }
            .padding()
        }
    }
}

#Preview("채팅방 있음") {
    ChatListView(
        store: Store(initialState: ChatListFeature.State(
            currentUserId: "user-1",
            chatRooms: [
                ChatRoom(
                    id: "D_user-1_user-2",
                    type: .direct,
                    lastMessage: "안녕하세요!",
                    lastMessageAt: Date(),
                    index: 5,
                    activeUsers: ["user-1": Date(), "user-2": Date()]
                ),
                ChatRoom(
                    id: "D_user-1_user-3",
                    type: .direct,
                    lastMessage: "오늘 시간 되세요?",
                    lastMessageAt: Date().addingTimeInterval(-3600),
                    index: 10,
                    activeUsers: ["user-1": Date(), "user-3": Date()]
                )
            ],
            chatRoomProfiles: [
                "D_user-1_user-2": Profile(id: "user-2", nickname: "홍길동"),
                "D_user-1_user-3": Profile(id: "user-3", nickname: "김철수")
            ]
        )) {
            ChatListFeature()
        }
    )
}

#Preview("빈 목록") {
    ChatListView(
        store: Store(initialState: ChatListFeature.State(
            currentUserId: "user-1"
        )) {
            ChatListFeature()
        }
    )
}
