//
//  ChatRoomFeature.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation
import ComposableArchitecture

// MARK: - ReinviteTarget

struct ReinviteTarget: Equatable {
    let userId: String
    let nickname: String
}

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
        var isInviting: Bool = false

        // Pagination
        var hasMoreMessages: Bool = true

        // Error
        var error: String?

        // 재입장 관련
        var currentUserJoinedAt: Date?  // 현재 유저의 채팅방 참여 시점
        var needsRejoin: Bool = false   // 재입장이 필요한지 여부

        // 그룹 채팅 관련
        var chatRoomType: ChatRoomType = .direct
        var activeUserIds: [String] = []
        var allFriends: [Profile] = []
        @Presents var inviteFriendsDestination: InviteFriendsFeature.State?

        // Lazy 그룹 채팅방 생성 관련
        var pendingGroupChatUserIds: [String]? = nil  // nil이면 일반, 값 있으면 pending 그룹 채팅

        // 재초대 관련
        var reinviteConfirmTarget: ReinviteTarget? = nil

        // Drawer 관련
        var isDrawerOpen: Bool = false

        init(
            chatRoomId: String,
            currentUserId: String,
            otherUser: Profile? = nil,
            currentUserJoinedAt: Date? = nil,
            chatRoomType: ChatRoomType = .direct,
            activeUserIds: [String] = [],
            allFriends: [Profile] = [],
            pendingGroupChatUserIds: [String]? = nil
        ) {
            self.chatRoomId = chatRoomId
            self.currentUserId = currentUserId
            self.otherUser = otherUser
            self.currentUserJoinedAt = currentUserJoinedAt
            self.chatRoomType = chatRoomType
            self.activeUserIds = activeUserIds
            self.allFriends = allFriends
            self.pendingGroupChatUserIds = pendingGroupChatUserIds
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

        /// 그룹 채팅 여부
        var isGroupChat: Bool {
            chatRoomType == .group
        }

        /// 초대 가능한 친구 목록 (현재 채팅방에 없는 친구)
        var invitableFriends: [Profile] {
            allFriends.filter { !activeUserIds.contains($0.id) }
        }

        /// 그룹 채팅방이 새로 생성되어야 하는지 (Lazy 생성)
        var needsToCreateGroupChat: Bool {
            pendingGroupChatUserIds != nil
        }

        /// 채팅방 참여자 프로필 목록 (allFriends에서 activeUserIds 필터링)
        var activeUserProfiles: [Profile] {
            allFriends.filter { activeUserIds.contains($0.id) }
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

        // Invite Friends (Group Chat)
        case inviteFriendsButtonTapped
        case inviteFriendsDestination(PresentationAction<InviteFriendsFeature.Action>)
        case inviteCompleted(Result<[String], Error>)  // 초대한 친구 ID 반환

        // Reinvite (from system message link)
        case reinviteUserTapped(userId: String, nickname: String)
        case reinviteConfirmDismissed
        case reinviteConfirmed
        case reinviteCompleted(Result<String, Error>)  // 재초대한 유저 ID 반환

        // Drawer 관련
        case drawerButtonTapped
        case setDrawerOpen(Bool)
        case inviteFromDrawerTapped
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
                let isGroupChat = state.isGroupChat

                // 채팅방 정보 로드 + 메시지 관찰 동시 시작
                return .merge(
                    // 채팅방 정보 로드 (joinedAt 확인용)
                    .run { [chatRoomRepository] send in
                        if isGroupChat {
                            // 그룹 채팅: chatRoomId로 직접 조회
                            let chatRoom = try? await chatRoomRepository.getGroupChatRoom(chatRoomId: chatRoomId)
                            await send(.chatRoomLoaded(chatRoom))
                        } else if let otherUserId = otherUserId {
                            // 1:1 채팅: 기존 로직
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
                let needsToCreateGroupChat = state.needsToCreateGroupChat
                let pendingUserIds = state.pendingGroupChatUserIds
                let needsRejoin = state.needsRejoin
                let otherUserId = state.otherUser?.id

                // pendingGroupChatUserIds 초기화 (첫 메시지 전송 후 더 이상 필요 없음)
                if needsToCreateGroupChat {
                    state.pendingGroupChatUserIds = nil
                }

                return .run { [chatRoomRepository] send in
                    do {
                        if needsToCreateGroupChat, let userIds = pendingUserIds {
                            // Lazy 그룹 채팅방 생성 + 첫 메시지 전송
                            try await chatRoomRepository.createGroupChatRoomAndSendMessage(
                                chatRoomId,
                                userIds,
                                currentUserId,
                                trimmedText
                            )
                        } else if needsToCreate, let otherUserId = otherUserId {
                            // 새 1:1 채팅방 생성 + 첫 메시지 전송
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

            case .inviteFriendsButtonTapped:
                guard state.isGroupChat else { return .none }
                state.inviteFriendsDestination = InviteFriendsFeature.State(
                    friends: state.invitableFriends
                )
                return .none

            case let .inviteFriendsDestination(.presented(.delegate(.friendsInvited(invitedIds)))):
                state.inviteFriendsDestination = nil
                guard !invitedIds.isEmpty else { return .none }

                // 채팅방이 아직 생성되지 않은 경우 (Lazy 생성 대기 중)
                if state.needsToCreateGroupChat {
                    // pendingGroupChatUserIds에 초대한 친구 추가
                    state.pendingGroupChatUserIds?.append(contentsOf: invitedIds)
                    // activeUserIds에도 추가 (UI 표시용)
                    state.activeUserIds.append(contentsOf: invitedIds)
                    return .none
                }

                // 이미 생성된 채팅방인 경우 API 호출
                state.isInviting = true
                let chatRoomId = state.chatRoomId
                let allFriends = state.allFriends

                // 초대된 친구의 닉네임 가져오기
                let invitedNicknames = invitedIds.compactMap { userId -> String? in
                    allFriends.first { $0.id == userId }?.nickname
                }

                return .run { [chatRoomRepository, invitedIds] send in
                    do {
                        // 1. 친구 초대
                        try await chatRoomRepository.inviteToGroupChat(chatRoomId, invitedIds)

                        // 2. 각 친구에 대해 시스템 메시지 전송
                        for nickname in invitedNicknames {
                            let message = Strings.Chat.userJoinedMessage(nickname)
                            try await chatRoomRepository.sendSystemMessage(chatRoomId, message)
                        }

                        // 초대한 친구 ID 반환
                        await send(.inviteCompleted(.success(invitedIds)))
                    } catch {
                        await send(.inviteCompleted(.failure(error)))
                    }
                }

            case .inviteFriendsDestination:
                return .none

            case let .inviteCompleted(.success(invitedIds)):
                state.isInviting = false
                // 초대한 친구들을 activeUserIds에 추가
                state.activeUserIds.append(contentsOf: invitedIds)
                return .none

            case let .inviteCompleted(.failure(error)):
                state.isInviting = false
                state.error = error.localizedDescription
                return .none

            case let .reinviteUserTapped(userId, nickname):
                state.reinviteConfirmTarget = ReinviteTarget(userId: userId, nickname: nickname)
                return .none

            case .reinviteConfirmDismissed:
                state.reinviteConfirmTarget = nil
                return .none

            case .reinviteConfirmed:
                guard let target = state.reinviteConfirmTarget else { return .none }
                state.reinviteConfirmTarget = nil
                state.isInviting = true

                let chatRoomId = state.chatRoomId
                let userId = target.userId
                let nickname = target.nickname

                return .run { [chatRoomRepository, userId] send in
                    do {
                        // 1. 사용자 재초대
                        try await chatRoomRepository.inviteToGroupChat(chatRoomId, [userId])

                        // 2. 시스템 메시지 전송
                        let message = Strings.Chat.userJoinedMessage(nickname)
                        try await chatRoomRepository.sendSystemMessage(chatRoomId, message)

                        // 재초대한 유저 ID 반환
                        await send(.reinviteCompleted(.success(userId)))
                    } catch {
                        await send(.reinviteCompleted(.failure(error)))
                    }
                }

            case let .reinviteCompleted(.success(userId)):
                state.isInviting = false
                // 재초대한 유저를 activeUserIds에 추가
                state.activeUserIds.append(userId)
                return .none

            case let .reinviteCompleted(.failure(error)):
                state.isInviting = false
                state.error = error.localizedDescription
                return .none

            case .drawerButtonTapped:
                state.isDrawerOpen = true
                return .none

            case let .setDrawerOpen(isOpen):
                state.isDrawerOpen = isOpen
                return .none

            case .inviteFromDrawerTapped:
                state.isDrawerOpen = false
                // 0.3초 후 inviteFriendsButtonTapped 전송 (drawer 닫힘 애니메이션 대기)
                return .run { send in
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await send(.inviteFriendsButtonTapped)
                }
            }
        }
        .ifLet(\.$inviteFriendsDestination, action: \.inviteFriendsDestination) {
            InviteFriendsFeature()
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
             (.loadMoreMessages, .loadMoreMessages),
             (.inviteFriendsButtonTapped, .inviteFriendsButtonTapped),
             (.reinviteConfirmDismissed, .reinviteConfirmDismissed),
             (.reinviteConfirmed, .reinviteConfirmed),
             (.drawerButtonTapped, .drawerButtonTapped),
             (.inviteFromDrawerTapped, .inviteFromDrawerTapped):
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

        case let (.inviteFriendsDestination(lhs), .inviteFriendsDestination(rhs)):
            return lhs == rhs

        case let (.inviteCompleted(lhsResult), .inviteCompleted(rhsResult)):
            switch (lhsResult, rhsResult) {
            case let (.success(lhsIds), .success(rhsIds)):
                return lhsIds == rhsIds
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        case let (.reinviteUserTapped(lhsUserId, lhsNickname), .reinviteUserTapped(rhsUserId, rhsNickname)):
            return lhsUserId == rhsUserId && lhsNickname == rhsNickname

        case let (.reinviteCompleted(lhsResult), .reinviteCompleted(rhsResult)):
            switch (lhsResult, rhsResult) {
            case let (.success(lhsUserId), .success(rhsUserId)):
                return lhsUserId == rhsUserId
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        case let (.setDrawerOpen(lhs), .setDrawerOpen(rhs)):
            return lhs == rhs

        default:
            return false
        }
    }
}
