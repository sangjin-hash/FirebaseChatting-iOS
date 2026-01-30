//
//  ChatRoomFeature.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import ComposableArchitecture

@Reducer
struct ChatRoomFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String { chatRoomId }
        var chatRoomId: String
        var currentUserId: String
        var otherUser: Profile?

        // Messages
        var messages: [Message] = []
        var inputText: String = ""

        // Loading States
        var isLoading: Bool = false
        var isSending: Bool = false
        var isLoadingMore: Bool = false

        // Pagination
        var hasMoreMessages: Bool = true

        // Error
        var error: String?

        // 재입장 관련
        var currentUserJoinedAt: Date?  // 현재 유저의 채팅방 참여 시점
        var needsRejoin: Bool = false   // 재입장이 필요한지 여부

        init(
            chatRoomId: String,
            currentUserId: String,
            otherUser: Profile? = nil,
            currentUserJoinedAt: Date? = nil
        ) {
            self.chatRoomId = chatRoomId
            self.currentUserId = currentUserId
            self.otherUser = otherUser
            self.currentUserJoinedAt = currentUserJoinedAt
        }

        // MARK: - Computed Properties

        var canSendMessage: Bool {
            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
        }

        /// 채팅방이 새로 생성되어야 하는지 (첫 메시지 전송 시)
        var needsToCreateChatRoom: Bool {
            messages.isEmpty && currentUserJoinedAt == nil
        }

        /// joinedAt 이후의 메시지만 필터링
        /// - needsRejoin이 true면 빈 배열 반환 (재입장 전까지 메시지 숨김)
        var filteredMessages: [Message] {
            // 재입장이 필요한 경우 빈 채팅방 표시
            if needsRejoin {
                return []
            }
            guard let joinedAt = currentUserJoinedAt else {
                return messages
            }
            return messages.filter { $0.createdAt >= joinedAt }
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case onDisappear

        // Input
        case inputTextChanged(String)
        case sendButtonTapped

        // Messages
        case messagesUpdated([Message])
        case messagesLoadFailed(Error)
        case messageSent(Result<Void, Error>)

        // Pagination
        case loadMoreMessages
        case moreMessagesLoaded(Result<[Message], Error>)

        // Rejoin
        case chatRoomLoaded(ChatRoom?)
        case rejoinCompleted(Result<Void, Error>)
    }

    // MARK: - Dependencies

    @Dependency(\.chatRoomRepository) var chatRoomRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let chatRoomId = state.chatRoomId
                let currentUserId = state.currentUserId
                let otherUserId = state.otherUser?.id

                // 채팅방 정보 로드 + 메시지 관찰 동시 시작
                return .merge(
                    // 채팅방 정보 로드 (joinedAt 확인용)
                    .run { [chatRoomRepository] send in
                        if let otherUserId = otherUserId {
                            let chatRoom = try? await chatRoomRepository.getDirectChatRoom(currentUserId, otherUserId)
                            await send(.chatRoomLoaded(chatRoom))
                        } else {
                            await send(.chatRoomLoaded(nil))
                        }
                    },
                    // 메시지 실시간 관찰
                    .run { [chatRoomRepository] send in
                        for await messages in chatRoomRepository.observeMessages(chatRoomId, 30) {
                            await send(.messagesUpdated(messages))
                        }
                    }
                    .cancellable(id: "observeMessages", cancelInFlight: true)
                )

            case .onDisappear:
                return .cancel(id: "observeMessages")

            case let .inputTextChanged(text):
                state.inputText = text
                return .none

            case .sendButtonTapped:
                let trimmedText = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    return .none
                }

                state.isSending = true
                state.inputText = ""

                let chatRoomId = state.chatRoomId
                let currentUserId = state.currentUserId
                let needsToCreate = state.needsToCreateChatRoom
                let needsRejoin = state.needsRejoin
                let otherUserId = state.otherUser?.id

                return .run { [chatRoomRepository] send in
                    do {
                        if needsToCreate, let otherUserId = otherUserId {
                            // 새 채팅방 생성 + 첫 메시지 전송
                            let userIds = [currentUserId, otherUserId]
                            try await chatRoomRepository.createChatRoomAndSendMessage(
                                chatRoomId,
                                userIds,
                                currentUserId,
                                trimmedText
                            )
                        } else if needsRejoin {
                            // 재입장 + 메시지 전송
                            try await chatRoomRepository.rejoinChatRoom(chatRoomId, currentUserId)
                            await send(.rejoinCompleted(.success(())))
                            try await chatRoomRepository.sendMessage(
                                chatRoomId,
                                currentUserId,
                                trimmedText
                            )
                        } else {
                            // 기존 채팅방에 메시지 전송
                            try await chatRoomRepository.sendMessage(
                                chatRoomId,
                                currentUserId,
                                trimmedText
                            )
                        }
                        await send(.messageSent(.success(())))
                    } catch {
                        await send(.messageSent(.failure(error)))
                    }
                }

            case let .messagesUpdated(messages):
                // index 기준 오름차순 정렬 (오래된 메시지가 위에)
                state.messages = messages.sorted { $0.index < $1.index }
                state.isLoading = false
                return .none

            case let .messagesLoadFailed(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .messageSent(.success):
                state.isSending = false
                return .none

            case let .messageSent(.failure(error)):
                state.isSending = false
                state.error = error.localizedDescription
                return .none

            case .loadMoreMessages:
                guard !state.isLoadingMore, state.hasMoreMessages else {
                    return .none
                }

                state.isLoadingMore = true
                let chatRoomId = state.chatRoomId
                let beforeIndex = state.messages.first?.index  // 가장 오래된 메시지의 index

                return .run { [chatRoomRepository] send in
                    do {
                        let olderMessages = try await chatRoomRepository.fetchMessages(
                            chatRoomId,
                            beforeIndex,
                            30
                        )
                        await send(.moreMessagesLoaded(.success(olderMessages)))
                    } catch {
                        await send(.moreMessagesLoaded(.failure(error)))
                    }
                }

            case let .moreMessagesLoaded(.success(olderMessages)):
                state.isLoadingMore = false
                state.hasMoreMessages = !olderMessages.isEmpty
                if !olderMessages.isEmpty {
                    // 기존 메시지 앞에 이전 메시지 추가
                    state.messages = olderMessages + state.messages
                }
                return .none

            case let .moreMessagesLoaded(.failure(error)):
                state.isLoadingMore = false
                state.error = error.localizedDescription
                return .none

            case let .chatRoomLoaded(chatRoom):
                if let chatRoom = chatRoom {
                    // 채팅방 존재
                    if let joinedAt = chatRoom.activeUsers[state.currentUserId] {
                        // 현재 활성 유저 → joinedAt 저장
                        state.currentUserJoinedAt = joinedAt
                        state.needsRejoin = false
                    } else {
                        // 나간 상태 → 재입장 필요
                        state.needsRejoin = true
                    }
                } else {
                    // 새 채팅방 (아직 생성되지 않음)
                    state.needsRejoin = false
                }
                return .none

            case .rejoinCompleted(.success):
                // 재입장 완료 → joinedAt을 현재 시간으로 설정
                state.currentUserJoinedAt = Date()
                state.needsRejoin = false
                return .none

            case let .rejoinCompleted(.failure(error)):
                state.isSending = false
                state.error = error.localizedDescription
                return .none
            }
        }
    }
}

// MARK: - Equatable for Error

extension ChatRoomFeature.Action {
    static func == (lhs: ChatRoomFeature.Action, rhs: ChatRoomFeature.Action) -> Bool {
        switch (lhs, rhs) {
        case (.onAppear, .onAppear),
             (.onDisappear, .onDisappear),
             (.sendButtonTapped, .sendButtonTapped),
             (.loadMoreMessages, .loadMoreMessages):
            return true

        case let (.inputTextChanged(lhsText), .inputTextChanged(rhsText)):
            return lhsText == rhsText

        case let (.messagesUpdated(lhsMessages), .messagesUpdated(rhsMessages)):
            return lhsMessages == rhsMessages

        case let (.messagesLoadFailed(lhsError), .messagesLoadFailed(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription

        case let (.messageSent(lhsResult), .messageSent(rhsResult)):
            switch (lhsResult, rhsResult) {
            case (.success, .success):
                return true
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        case let (.moreMessagesLoaded(lhsResult), .moreMessagesLoaded(rhsResult)):
            switch (lhsResult, rhsResult) {
            case let (.success(lhsMessages), .success(rhsMessages)):
                return lhsMessages == rhsMessages
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        case let (.chatRoomLoaded(lhsChatRoom), .chatRoomLoaded(rhsChatRoom)):
            return lhsChatRoom == rhsChatRoom

        case let (.rejoinCompleted(lhsResult), .rejoinCompleted(rhsResult)):
            switch (lhsResult, rhsResult) {
            case (.success, .success):
                return true
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        default:
            return false
        }
    }
}
