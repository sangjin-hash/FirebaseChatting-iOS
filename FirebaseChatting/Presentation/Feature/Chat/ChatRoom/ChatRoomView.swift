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
        VStack(spacing: 0) {
            // 메시지 목록
            messageList

            // 메시지 입력
            messageInput
        }
        .navigationTitle(store.otherUser?.nickname ?? Strings.Common.noName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Message List

    @State private var initialScrollDone = false

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // 스크롤 상단 도달 시 이전 메시지 로드 트리거
                    if store.hasMoreMessages && !store.filteredMessages.isEmpty {
                        loadMoreTrigger
                    }

                    // 메시지들
                    ForEach(groupedMessages, id: \.date) { group in
                        // 날짜 구분선
                        dateSeparator(date: group.date)

                        ForEach(group.messages) { message in
                            messageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)  // iOS 17+: 스크롤 시작점을 하단으로
            .onChange(of: store.filteredMessages.count) { oldCount, newCount in
                // 초기 로드 시 최신 메시지(하단)로 스크롤
                if oldCount == 0 && newCount > 0, !initialScrollDone {
                    initialScrollDone = true
                    if let lastId = store.filteredMessages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.filteredMessages.last?.id) { oldValue, newValue in
                // 새 메시지 도착 시 하단으로 스크롤 (초기 로드 이후)
                if let id = newValue, oldValue != nil {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
        .overlay {
            if store.isLoading && store.filteredMessages.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Load More Trigger

    private var loadMoreTrigger: some View {
        Group {
            if store.isLoadingMore {
                ProgressView()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        store.send(.loadMoreMessages)
                    }
            }
        }
    }

    // MARK: - Date Separator

    private func dateSeparator(date: Date) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text(formatDate(date))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(message: Message) -> some View {
        if message.isSystemMessage {
            systemMessageView(message: message)
        } else if message.isMine(myUserId: store.currentUserId) {
            myMessageView(message: message)
        } else {
            otherMessageView(message: message)
        }
    }

    // MARK: - System Message View

    private func systemMessageView(message: Message) -> some View {
        Text(message.content ?? "")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
    }

    // MARK: - My Message View

    private func myMessageView(message: Message) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Spacer(minLength: 60)

            Text(formatTime(message.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(message.content ?? "")
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Other Message View

    private func otherMessageView(message: Message) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(message.content ?? "")
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(formatTime(message.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 60)
        }
    }

    // MARK: - Message Input

    private var messageInput: some View {
        HStack(spacing: 12) {
            TextField(Strings.Chat.messageInputPlaceholder, text: $store.inputText.sending(\.inputTextChanged))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    store.send(.sendButtonTapped)
                }

            Button {
                store.send(.sendButtonTapped)
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(store.canSendMessage ? Color.blue : Color.blue.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!store.canSendMessage)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Grouped Messages

    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [Message] = []

        for message in store.filteredMessages {
            let messageDate = calendar.startOfDay(for: message.createdAt)

            if currentDate == nil {
                currentDate = messageDate
                currentMessages = [message]
            } else if currentDate == messageDate {
                currentMessages.append(message)
            } else {
                groups.append(MessageGroup(date: currentDate!, messages: currentMessages))
                currentDate = messageDate
                currentMessages = [message]
            }
        }

        if let date = currentDate, !currentMessages.isEmpty {
            groups.append(MessageGroup(date: date, messages: currentMessages))
        }

        return groups
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if Calendar.current.isDateInToday(date) {
            return "오늘"
        } else if Calendar.current.isDateInYesterday(date) {
            return "어제"
        } else {
            formatter.dateFormat = "yyyy년 M월 d일"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Message Group

private struct MessageGroup: Equatable {
    let date: Date
    let messages: [Message]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatRoomView(
            store: Store(initialState: ChatRoomFeature.State(
                chatRoomId: "D_user-1_user-2",
                currentUserId: "user-1",
                otherUser: Profile(id: "user-2", nickname: "친구")
            )) {
                ChatRoomFeature()
            } withDependencies: {
                $0.chatRoomRepository.observeMessages = { _, _ in
                    AsyncStream { continuation in
                        let messages = [
                            Message(id: "1", index: 1, senderId: "user-1", type: .text, content: "안녕하세요!", createdAt: Date().addingTimeInterval(-3600)),
                            Message(id: "2", index: 2, senderId: "user-2", type: .text, content: "반갑습니다!", createdAt: Date().addingTimeInterval(-1800)),
                            Message(id: "3", index: 3, senderId: "user-1", type: .text, content: "오늘 날씨가 좋네요", createdAt: Date())
                        ]
                        continuation.yield(messages)
                        continuation.finish()
                    }
                }
            }
        )
    }
}
