//
//  ChatRoomView.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import SwiftUI
import ComposableArchitecture

struct ChatRoomView: View {
    @Bindable var store: StoreOf<ChatRoomFeature>

    var body: some View {
        VStack {
            // 메시지 영역 (Phase 5에서 구현)
            Spacer()

            messageListPlaceholder

            Spacer()

            // 메시지 입력 영역 (Phase 5에서 구현)
            messageInputPlaceholder
        }
        .navigationTitle(store.otherUser?.nickname ?? Strings.Common.noName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    // MARK: - Placeholder Views

    private var messageListPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("메시지가 여기에 표시됩니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Phase 5에서 구현 예정")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var messageInputPlaceholder: some View {
        HStack(spacing: 12) {
            TextField(Strings.Chat.messageInputPlaceholder, text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)

            Button {
                // Phase 5에서 구현
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(true)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        ChatRoomView(
            store: Store(initialState: ChatRoomFeature.State(
                chatRoomId: "D_user-1_user-2",
                currentUserId: "user-1",
                otherUser: Profile(id: "user-2", nickname: "친구")
            )) {
                ChatRoomFeature()
            }
        )
    }
}
