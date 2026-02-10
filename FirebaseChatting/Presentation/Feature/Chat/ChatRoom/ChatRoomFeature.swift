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

// MARK: - MediaMessagePayload

struct MediaMessagePayload: Equatable, Sendable {
    let type: MessageType
    let urls: [String]
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
        var hasMoreNewerMessages: Bool = false
        var isLoadingNewer: Bool = false
        var initialUnreadCount: Int = 0

        // Unread divider
        var unreadDividerMessageId: String? = nil

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

        init(
            chatRoomId: String,
            currentUserId: String,
            otherUser: Profile? = nil,
            currentUserJoinedAt: Date? = nil,
            chatRoomType: ChatRoomType = .direct,
            activeUserIds: [String] = [],
            allFriends: [Profile] = [],
            pendingGroupChatUserIds: [String]? = nil,
            initialUnreadCount: Int = 0
        ) {
            self.chatRoomId = chatRoomId
            self.currentUserId = currentUserId
            self.otherUser = otherUser
            self.currentUserJoinedAt = currentUserJoinedAt
            self.chatRoomType = chatRoomType
            self.activeUserIds = activeUserIds
            self.allFriends = allFriends
            self.pendingGroupChatUserIds = pendingGroupChatUserIds
            self.initialUnreadCount = initialUnreadCount
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

        // MARK: - Media Computed Properties
        /// 메시지 전송 가능 여부 (텍스트 또는 미디어)
        var canSendAny: Bool {
            canSendMessage || mediaUpload.hasSelectedMedia
        }
        
        // MARK: - 자식 Feature 의 State
        var mediaViewer = MediaViewerFeature.State()
        var drawer = DrawerFeature.State()
        var mediaUpload = MediaUploadFeature.State()
    }

    // MARK: - Action

    enum Action: Equatable {

        // MARK: - Lifecycle

        case onAppear
        case onDisappear

        // MARK: - Text Message Send

        case inputTextChanged(String)
        case sendButtonTapped
        case messageSent(Result<Void, Error>)

        // MARK: - Message Sync (캐시 로드 + 실시간 관찰 + 순방향 페이지네이션)

        case cachedMessagesLoaded([Message])
        case startObserving
        case messagesUpdated([Message])
        case messagesLoadFailed(Error)
        case newerMessagesFetched(Result<[Message], Error>)

        // MARK: - Pagination (역방향: 위로 스크롤 / 순방향: 아래로 스크롤)

        case loadMoreMessages
        case moreMessagesLoaded(Result<[Message], Error>)
        case loadNewerMessages

        // MARK: - ChatRoom Load + Rejoin (동기화 전략 결정)

        case chatRoomLoaded(ChatRoom?)
        case rejoinCompleted(Result<Void, Error>)

        // MARK: - Invite Friends (그룹 채팅 초대)

        case inviteFriendsButtonTapped
        case inviteFriendsDestination(PresentationAction<InviteFriendsFeature.Action>)
        case inviteCompleted(Result<[String], Error>)

        // MARK: - Reinvite (시스템 메시지 재초대)

        case reinviteUserTapped(userId: String, nickname: String)
        case reinviteConfirmDismissed
        case reinviteConfirmed
        case reinviteCompleted(Result<String, Error>)

        // MARK: - Media Upload & Send

        case uploadStarted
        case uploadProgress(itemId: String, progress: Double)
        case uploadCompleted(itemId: String, downloadURL: String)
        case uploadFailed(itemId: String, Error)
        case allUploadsCompleted
        case sendMediaMessages([MediaMessagePayload])
        case mediaMessageSent(Result<Void, Error>)

        // MARK: - Media Retry

        case retryUpload(itemId: String)

        // MARK: - Child Feature Actions

        case mediaViewer(MediaViewerFeature.Action)
        case drawer(DrawerFeature.Action)
        case mediaUpload(MediaUploadFeature.Action)
    }

    // MARK: - Dependencies

    @Dependency(\.chatRoomRepository) var chatRoomRepository
    @Dependency(\.storageClient) var storageClient

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Scope(state: \.mediaViewer, action: \.mediaViewer) {
            MediaViewerFeature()
        }
        
        Scope(state: \.drawer, action: \.drawer) {
            DrawerFeature()
        }
        
        Scope(state: \.mediaUpload, action: \.mediaUpload) {
            MediaUploadFeature()
        }
        
        Reduce { state, action in
            switch action {

            // MARK: - Lifecycle

            case .onAppear:
                state.isLoading = true
                let chatRoomId = state.chatRoomId
                let currentUserId = state.currentUserId
                let otherUserId = state.otherUser?.id
                let isGroupChat = state.isGroupChat

                return .merge(
                    // 캐싱한 메시지 로드
                    .run { [chatRoomRepository] send in
                        let cached = try await chatRoomRepository.loadCachedMessages(chatRoomId, 30)
                        await send(.cachedMessagesLoaded(cached))
                    },
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
                )

            case .onDisappear:
                return .cancel(id: "observeMessages")

            // MARK: - Text Message Send

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

            // MARK: - Message Sync (캐시 로드 + 실시간 관찰 + 순방향 페이지네이션)

            case let .messagesUpdated(newMessages):
                // ID 기반 중복 제거 후 병합 (기존 messages + observer 메시지)
                var messageDict = Dictionary(uniqueKeysWithValues: state.messages.map { ($0.id, $0) })
                for msg in newMessages {
                    messageDict[msg.id] = msg
                }
                state.messages = messageDict.values.sorted { $0.createdAt < $1.createdAt }
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
            
            case let .cachedMessagesLoaded(messages):
                if !messages.isEmpty {
                    state.messages = messages
                    state.isLoading = false
                }
                return .none

            case .startObserving:
                let chatRoomId = state.chatRoomId
                return .run { [chatRoomRepository] send in
                    for await messages in chatRoomRepository.observeMessages(chatRoomId) {
                        await send(.messagesUpdated(messages))
                    }
                }
                .cancellable(id: "observeMessages", cancelInFlight: true)

            case let .newerMessagesFetched(.success(messages)):
                state.isLoadingNewer = false

                // 첫 순방향 페이지네이션 결과에서 unread divider 위치 설정
                if state.unreadDividerMessageId == nil && state.initialUnreadCount > 0 && !messages.isEmpty {
                    state.unreadDividerMessageId = messages.first?.id
                }

                if !messages.isEmpty {
                    var messageDict = Dictionary(uniqueKeysWithValues: state.messages.map { ($0.id, $0) })
                    for msg in messages {
                        messageDict[msg.id] = msg
                    }
                    state.messages = messageDict.values.sorted { $0.createdAt < $1.createdAt }
                }
                state.isLoading = false
                if messages.count < 30 {
                    // 마지막 페이지 도달 → 리스너 시작
                    state.hasMoreNewerMessages = false
                    return .send(.startObserving)
                } else {
                    state.hasMoreNewerMessages = true
                    return .none
                }

            case let .newerMessagesFetched(.failure(error)):
                state.isLoadingNewer = false
                state.isLoading = false
                state.hasMoreNewerMessages = false
                state.error = error.localizedDescription
                // 실패 시에도 리스너 시작하여 실시간 메시지는 수신
                return .send(.startObserving)

            // MARK: - Pagination (역방향: 위로 스크롤 / 순방향: 아래로 스크롤)

            case .loadMoreMessages:
                guard !state.isLoadingMore, state.hasMoreMessages else {
                    return .none
                }

                state.isLoadingMore = true
                let chatRoomId = state.chatRoomId
                let beforeCreatedAt = state.messages.first?.createdAt
                let joinedAt = state.currentUserJoinedAt

                return .run { [chatRoomRepository] send in
                    do {
                        guard let beforeCreatedAt else { return }
                        let olderMessages = try await chatRoomRepository.fetchOlderMessages(
                            chatRoomId,
                            beforeCreatedAt,
                            joinedAt,
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

            case .loadNewerMessages:
                guard state.hasMoreNewerMessages, !state.isLoadingNewer else { return .none }
                guard let afterCreatedAt = state.messages.last?.createdAt else { return .none }

                state.isLoadingNewer = true
                let chatRoomId = state.chatRoomId

                return .run { [chatRoomRepository] send in
                    do {
                        let newer = try await chatRoomRepository.fetchNewerMessages(chatRoomId, afterCreatedAt, 30)
                        await send(.newerMessagesFetched(.success(newer)))
                    } catch {
                        await send(.newerMessagesFetched(.failure(error)))
                    }
                }

            // MARK: - ChatRoom Load + Rejoin (동기화 전략 결정)

            case let .chatRoomLoaded(chatRoom):
                if let chatRoom = chatRoom {
                    if let joinedAt = chatRoom.activeUsers[state.currentUserId] {
                        state.currentUserJoinedAt = joinedAt
                        state.needsRejoin = false
                    } else {
                        state.needsRejoin = true
                    }
                } else {
                    state.needsRejoin = false
                }

                // 동기화 전략 결정
                if state.needsRejoin {
                    // Case E: 재입장 필요 → 사용자가 메시지 전송할 때까지 대기
                    state.isLoading = false
                    return .none
                } else if state.initialUnreadCount == 0 || state.messages.isEmpty {
                    // Case A/D: 안읽은 메시지 없음 또는 캐시 없음 → 리스너 즉시 시작
                    return .send(.startObserving)
                } else {
                    // Case B: 안읽은 메시지 있음 + 캐시 있음 → 순방향 페이지네이션
                    guard let afterCreatedAt = state.messages.last?.createdAt else {
                        return .send(.startObserving)
                    }
                    state.hasMoreNewerMessages = true
                    state.isLoadingNewer = true
                    let chatRoomId = state.chatRoomId
                    return .run { [chatRoomRepository] send in
                        do {
                            let newer = try await chatRoomRepository.fetchNewerMessages(chatRoomId, afterCreatedAt, 30)
                            await send(.newerMessagesFetched(.success(newer)))
                        } catch {
                            await send(.newerMessagesFetched(.failure(error)))
                        }
                    }
                }

            case .rejoinCompleted(.success):
                // 재입장 완료 → joinedAt을 현재 시간으로 설정 + 리스너 시작
                state.currentUserJoinedAt = Date()
                state.needsRejoin = false
                return .send(.startObserving)

            case let .rejoinCompleted(.failure(error)):
                state.isSending = false
                state.error = error.localizedDescription
                return .none

            // MARK: - Invite Friends (그룹 채팅 초대)

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

            // MARK: - Reinvite (시스템 메시지 재초대)

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

            // MARK: - Media Upload & Send

            case .uploadStarted:
                return .none

            case let .uploadProgress(itemId, progress):
                state.mediaUpload.uploadingItems[id: itemId]?.progress = progress
                return .none

            case let .uploadCompleted(itemId, downloadURL):
                state.mediaUpload.uploadingItems[id: itemId]?.isCompleted = true
                state.mediaUpload.uploadingItems[id: itemId]?.downloadURL = downloadURL
                return .none

            case let .uploadFailed(itemId, error):
                state.mediaUpload.uploadingItems[id: itemId]?.error = error.localizedDescription
                state.mediaUpload.isUploading = false
                state.error = "업로드 실패: \(error.localizedDescription)"
                return .none

            case .allUploadsCompleted:
                // 업로드 완료된 아이템들을 메시지로 분리
                let completedItems = state.mediaUpload.uploadingItems.filter { $0.isCompleted && $0.downloadURL != nil }

                // 이미지와 동영상 분리
                let images = completedItems.filter { $0.type == .image }
                let videos = completedItems.filter { $0.type == .video }

                var payloads: [MediaMessagePayload] = []

                // 이미지 메시지 (한 메시지에 모든 이미지)
                if !images.isEmpty {
                    let urls = images.compactMap { $0.downloadURL }
                    payloads.append(MediaMessagePayload(type: .image, urls: urls))
                }

                // 동영상 메시지 (각각 별도 메시지)
                for video in videos {
                    if let url = video.downloadURL {
                        payloads.append(MediaMessagePayload(type: .video, urls: [url]))
                    }
                }

                state.mediaUpload.uploadingItems.removeAll()

                return .send(.sendMediaMessages(payloads))

            case let .sendMediaMessages(payloads):
                guard !payloads.isEmpty else {
                    state.mediaUpload.isUploading = false
                    return .none
                }

                let chatRoomId = state.chatRoomId
                let currentUserId = state.currentUserId
                let needsToCreate = state.needsToCreateChatRoom
                let needsToCreateGroupChat = state.needsToCreateGroupChat
                let pendingUserIds = state.pendingGroupChatUserIds
                let needsRejoin = state.needsRejoin
                let otherUserId = state.otherUser?.id

                // pendingGroupChatUserIds 초기화
                if needsToCreateGroupChat {
                    state.pendingGroupChatUserIds = nil
                }

                return .run { [chatRoomRepository] send in
                    do {
                        for (index, payload) in payloads.enumerated() {
                            if index == 0 {
                                // 첫 메시지: 채팅방 생성 로직 포함
                                if needsToCreateGroupChat, let userIds = pendingUserIds {
                                    try await chatRoomRepository.createGroupChatRoomAndSendMediaMessage(
                                        chatRoomId,
                                        userIds,
                                        currentUserId,
                                        payload.type,
                                        payload.urls
                                    )
                                } else if needsToCreate, let otherUserId = otherUserId {
                                    let userIds = [currentUserId, otherUserId]
                                    try await chatRoomRepository.createChatRoomAndSendMediaMessage(
                                        chatRoomId,
                                        userIds,
                                        currentUserId,
                                        payload.type,
                                        payload.urls
                                    )
                                } else if needsRejoin {
                                    try await chatRoomRepository.rejoinChatRoom(chatRoomId, currentUserId)
                                    await send(.rejoinCompleted(.success(())))
                                    try await chatRoomRepository.sendMediaMessage(
                                        chatRoomId,
                                        currentUserId,
                                        payload.type,
                                        payload.urls
                                    )
                                } else {
                                    try await chatRoomRepository.sendMediaMessage(
                                        chatRoomId,
                                        currentUserId,
                                        payload.type,
                                        payload.urls
                                    )
                                }
                            } else {
                                // 추가 메시지 (동영상 등)
                                try await chatRoomRepository.sendMediaMessage(
                                    chatRoomId,
                                    currentUserId,
                                    payload.type,
                                    payload.urls
                                )
                            }
                        }
                        await send(.mediaMessageSent(.success(())))
                    } catch {
                        await send(.mediaMessageSent(.failure(error)))
                    }
                }

            case .mediaMessageSent(.success):
                state.mediaUpload.isUploading = false
                // 미디어 전송 완료 후 스크롤 트리거
                state.mediaUpload.scrollToBottomTrigger = UUID()
                return .none

            case let .mediaMessageSent(.failure(error)):
                state.mediaUpload.isUploading = false
                state.error = error.localizedDescription
                return .none

            // MARK: - Media Retry

            case let .retryUpload(itemId):
                guard let failedItem = state.mediaUpload.uploadingItems[id: itemId],
                      let originalData = failedItem.originalData,
                      let mimeType = failedItem.mimeType else {
                    return .none
                }

                // 에러 상태 초기화
                state.mediaUpload.uploadingItems[id: itemId]?.error = nil
                state.mediaUpload.uploadingItems[id: itemId]?.progress = 0
                state.mediaUpload.isUploading = true

                let chatRoomId = state.chatRoomId
                let type = failedItem.type

                return .run { [storageClient] send in
                    do {
                        let mediaItem = MediaItem(
                            id: itemId,
                            data: originalData,
                            type: type,
                            mimeType: mimeType
                        )

                        for try await progress in storageClient.uploadMedia(chatRoomId, mediaItem) {
                            await send(.uploadProgress(itemId: itemId, progress: progress.progress))
                        }

                        let fileExtension = mimeType.contains("video") ? "mp4" : "jpg"
                        let url = try await storageClient.getDownloadURL(
                            chatRoomId,
                            "\(itemId).\(fileExtension)"
                        )
                        await send(.uploadCompleted(itemId: itemId, downloadURL: url.absoluteString))

                        // 모든 업로드 완료 확인
                        await send(.allUploadsCompleted)
                    } catch {
                        await send(.uploadFailed(itemId: itemId, error))
                    }
                }
                
            // MARK: - Child Feature Actions

            case .mediaViewer:
                return .none
                
            case .drawer(.delegate(.inviteTapped)):
                guard state.isGroupChat else { return .none }
                state.inviteFriendsDestination = InviteFriendsFeature.State(
                    friends: state.invitableFriends
                )
                return .none
            
            case .drawer:
                return .none
            
            case let .mediaUpload(.delegate(.uploadRequested(items))):
                let chatRoomId = state.chatRoomId
                return .run { [storageClient] send in
                    await send(.uploadStarted)
                    for item in items {
                        do {
                            let mediaItem = MediaItem(
                                id: item.id,
                                data: item.data,
                                type: item.type,
                                mimeType: item.mimeType
                            )
                            
                            for try await progress in storageClient.uploadMedia(chatRoomId, mediaItem) {
                                await send(.uploadProgress(itemId: item.id, progress: progress.progress))
                            }
                            
                            let url = try await storageClient.getDownloadURL(
                                chatRoomId, "\(item.id).\(item.fileExtension)"
                            )
                            await send(.uploadCompleted(itemId: item.id, downloadURL: url.absoluteString))
                        } catch {
                            await send(.uploadFailed(itemId: item.id, error))
                            return
                        }
                    }
                    await send(.allUploadsCompleted)
                }
                
            case .mediaUpload:
                return .none
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
             (.loadNewerMessages, .loadNewerMessages),
             (.startObserving, .startObserving),
             (.inviteFriendsButtonTapped, .inviteFriendsButtonTapped),
             (.reinviteConfirmDismissed, .reinviteConfirmDismissed),
             (.reinviteConfirmed, .reinviteConfirmed),
             (.uploadStarted, .uploadStarted),
             (.allUploadsCompleted, .allUploadsCompleted):
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

        case let (.cachedMessagesLoaded(lhsMessages), .cachedMessagesLoaded(rhsMessages)):
            return lhsMessages == rhsMessages

        case let (.newerMessagesFetched(lhsResult), .newerMessagesFetched(rhsResult)):
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

        // Media Actions
        case let (.uploadProgress(lhsId, lhsProgress), .uploadProgress(rhsId, rhsProgress)):
            return lhsId == rhsId && lhsProgress == rhsProgress

        case let (.uploadCompleted(lhsId, lhsURL), .uploadCompleted(rhsId, rhsURL)):
            return lhsId == rhsId && lhsURL == rhsURL

        case let (.uploadFailed(lhsId, lhsError), .uploadFailed(rhsId, rhsError)):
            return lhsId == rhsId && lhsError.localizedDescription == rhsError.localizedDescription

        case let (.sendMediaMessages(lhs), .sendMediaMessages(rhs)):
            return lhs == rhs

        case let (.mediaMessageSent(lhsResult), .mediaMessageSent(rhsResult)):
            switch (lhsResult, rhsResult) {
            case (.success, .success):
                return true
            case let (.failure(lhsError), .failure(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }

        case let (.retryUpload(lhs), .retryUpload(rhs)):
            return lhs == rhs

        // Child Feature Actions
        case let (.mediaViewer(lhs), .mediaViewer(rhs)):
            return lhs == rhs

        case let (.drawer(lhs), .drawer(rhs)):
            return lhs == rhs

        case let (.mediaUpload(lhs), .mediaUpload(rhs)):
            return lhs == rhs

        default:
            return false
        }
    }
}
