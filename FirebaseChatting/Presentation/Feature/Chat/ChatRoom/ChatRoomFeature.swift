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

// MARK: - SelectedMediaItem

struct SelectedMediaItem: Equatable, Identifiable, Sendable {
    let id: String
    let type: MediaType
    let data: Data
    let thumbnail: Data?       // 동영상인 경우 썸네일
    let fileName: String
    let mimeType: String

    var fileExtension: String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/heic": return "heic"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        default: return "dat"
        }
    }
}

// MARK: - UploadingMediaItem

struct UploadingMediaItem: Equatable, Identifiable, Sendable {
    let id: String
    let type: MediaType
    let thumbnail: Data?
    let originalData: Data?      // 재전송용 원본 데이터
    let mimeType: String?        // 재전송용 MIME 타입
    var progress: Double
    var isCompleted: Bool
    var downloadURL: String?
    var error: String?
    var isFailed: Bool { error != nil }
}

// MARK: - MediaMessagePayload

struct MediaMessagePayload: Equatable, Sendable {
    let type: MessageType
    let urls: [String]
}

// MARK: - FullScreenImageViewerState

struct FullScreenImageViewerState: Equatable, Sendable {
    let imageURLs: [String]
    var currentIndex: Int
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

        // MARK: - Media 관련

        /// 미디어 선택 PhotosPicker 표시 상태
        var isMediaPickerPresented: Bool = false
        /// 선택된 미디어 아이템 목록
        var selectedMediaItems: IdentifiedArrayOf<SelectedMediaItem> = []
        /// 업로드 중인 미디어 아이템 목록
        var uploadingItems: IdentifiedArrayOf<UploadingMediaItem> = []
        /// 미디어 업로드 중 여부
        var isUploading: Bool = false
        /// 미디어 선택 최대 개수
        let mediaSelectionLimit: Int = 10
        /// 파일 최대 크기 (10MB)
        let maxFileSizeBytes: Int = 10 * 1024 * 1024

        // 전체화면 뷰어
        var fullScreenImageViewerState: FullScreenImageViewerState?
        var videoPlayerURL: URL?

        // 파일 크기 초과 에러
        var fileSizeExceededFileName: String?

        // 실패한 업로드 삭제 확인
        var deleteConfirmationItemId: String?

        // 스크롤 트리거 (미디어 전송 완료 시 스크롤용)
        var scrollToBottomTrigger: UUID?

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

        // MARK: - Media Computed Properties

        /// 미디어가 선택되었는지 여부
        var hasSelectedMedia: Bool {
            !selectedMediaItems.isEmpty
        }

        /// 더 선택할 수 있는 미디어 개수
        var remainingMediaCount: Int {
            mediaSelectionLimit - selectedMediaItems.count
        }

        /// 메시지 전송 가능 여부 (텍스트 또는 미디어)
        var canSendAny: Bool {
            canSendMessage || hasSelectedMedia
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

        // MARK: - Media Actions

        // 미디어 선택
        case mediaButtonTapped
        case setMediaPickerPresented(Bool)
        case mediaSelected([SelectedMediaItem])
        case removeSelectedMedia(String)  // itemId
        case clearSelectedMedia
        case fileSizeExceeded(String)     // fileName
        case dismissFileSizeError

        // 업로드 & 전송
        case sendMediaButtonTapped
        case uploadStarted
        case uploadProgress(itemId: String, progress: Double)
        case uploadCompleted(itemId: String, downloadURL: String)
        case uploadFailed(itemId: String, Error)
        case allUploadsCompleted
        case sendMediaMessages([MediaMessagePayload])
        case mediaMessageSent(Result<Void, Error>)

        // 이미지 전체화면 뷰어
        case imageTapped(imageURLs: [String], index: Int)
        case dismissImageViewer
        case imageViewerIndexChanged(Int)

        // 동영상 플레이어
        case videoTapped(URL)
        case dismissVideoPlayer

        // 업로드 실패 처리
        case retryUpload(itemId: String)
        case deleteFailedUpload(itemId: String)
        case showDeleteConfirmation(itemId: String)
        case dismissDeleteConfirmation
    }

    // MARK: - Dependencies

    @Dependency(\.chatRoomRepository) var chatRoomRepository
    @Dependency(\.storageClient) var storageClient

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
                // createdAt 기준 오름차순 정렬 (오래된 메시지가 위에)
                state.messages = messages.sorted { $0.createdAt < $1.createdAt }
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
                let beforeCreatedAt = state.messages.first?.createdAt  // 가장 오래된 메시지의 createdAt

                return .run { [chatRoomRepository] send in
                    do {
                        let olderMessages = try await chatRoomRepository.fetchMessages(
                            chatRoomId,
                            beforeCreatedAt,
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

            // MARK: - Media Actions

            case .mediaButtonTapped:
                state.isMediaPickerPresented = true
                return .none

            case let .setMediaPickerPresented(isPresented):
                state.isMediaPickerPresented = isPresented
                return .none

            case let .mediaSelected(items):
                for item in items {
                    state.selectedMediaItems.append(item)
                }
                return .none

            case let .removeSelectedMedia(itemId):
                state.selectedMediaItems.remove(id: itemId)
                return .none

            case .clearSelectedMedia:
                state.selectedMediaItems.removeAll()
                return .none

            case let .fileSizeExceeded(fileName):
                state.fileSizeExceededFileName = fileName
                return .none

            case .dismissFileSizeError:
                state.fileSizeExceededFileName = nil
                return .none

            case .sendMediaButtonTapped:
                guard !state.selectedMediaItems.isEmpty else { return .none }

                state.isUploading = true
                state.uploadingItems = IdentifiedArrayOf(uniqueElements: state.selectedMediaItems.map { item in
                    UploadingMediaItem(
                        id: item.id,
                        type: item.type,
                        thumbnail: item.thumbnail ?? (item.type == .image ? item.data : nil),
                        originalData: item.data,
                        mimeType: item.mimeType,
                        progress: 0,
                        isCompleted: false
                    )
                })

                let items = Array(state.selectedMediaItems)
                let chatRoomId = state.chatRoomId
                state.selectedMediaItems.removeAll()

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

                            // 업로드 진행률 스트림
                            for try await progress in storageClient.uploadMedia(chatRoomId, mediaItem) {
                                await send(.uploadProgress(itemId: item.id, progress: progress.progress))
                            }

                            // 다운로드 URL 획득
                            let url = try await storageClient.getDownloadURL(
                                chatRoomId,
                                "\(item.id).\(item.fileExtension)"
                            )
                            await send(.uploadCompleted(itemId: item.id, downloadURL: url.absoluteString))
                        } catch {
                            await send(.uploadFailed(itemId: item.id, error))
                            return
                        }
                    }

                    await send(.allUploadsCompleted)
                }

            case .uploadStarted:
                return .none

            case let .uploadProgress(itemId, progress):
                state.uploadingItems[id: itemId]?.progress = progress
                return .none

            case let .uploadCompleted(itemId, downloadURL):
                state.uploadingItems[id: itemId]?.isCompleted = true
                state.uploadingItems[id: itemId]?.downloadURL = downloadURL
                return .none

            case let .uploadFailed(itemId, error):
                state.uploadingItems[id: itemId]?.error = error.localizedDescription
                state.isUploading = false
                state.error = "업로드 실패: \(error.localizedDescription)"
                return .none

            case .allUploadsCompleted:
                // 업로드 완료된 아이템들을 메시지로 분리
                let completedItems = state.uploadingItems.filter { $0.isCompleted && $0.downloadURL != nil }

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

                state.uploadingItems.removeAll()

                return .send(.sendMediaMessages(payloads))

            case let .sendMediaMessages(payloads):
                guard !payloads.isEmpty else {
                    state.isUploading = false
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
                state.isUploading = false
                // 미디어 전송 완료 후 스크롤 트리거
                state.scrollToBottomTrigger = UUID()
                return .none

            case let .mediaMessageSent(.failure(error)):
                state.isUploading = false
                state.error = error.localizedDescription
                return .none

            case let .imageTapped(imageURLs, index):
                state.fullScreenImageViewerState = FullScreenImageViewerState(
                    imageURLs: imageURLs,
                    currentIndex: index
                )
                return .none

            case .dismissImageViewer:
                state.fullScreenImageViewerState = nil
                return .none

            case let .imageViewerIndexChanged(index):
                state.fullScreenImageViewerState?.currentIndex = index
                return .none

            case let .videoTapped(url):
                state.videoPlayerURL = url
                return .none

            case .dismissVideoPlayer:
                state.videoPlayerURL = nil
                return .none

            // MARK: - 업로드 실패 처리

            case let .retryUpload(itemId):
                guard let failedItem = state.uploadingItems[id: itemId],
                      let originalData = failedItem.originalData,
                      let mimeType = failedItem.mimeType else {
                    return .none
                }

                // 에러 상태 초기화
                state.uploadingItems[id: itemId]?.error = nil
                state.uploadingItems[id: itemId]?.progress = 0
                state.isUploading = true

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

            case let .showDeleteConfirmation(itemId):
                state.deleteConfirmationItemId = itemId
                return .none

            case .dismissDeleteConfirmation:
                state.deleteConfirmationItemId = nil
                return .none

            case let .deleteFailedUpload(itemId):
                state.uploadingItems.remove(id: itemId)
                state.deleteConfirmationItemId = nil
                // 모든 업로드 아이템이 제거되면 isUploading false
                if state.uploadingItems.isEmpty {
                    state.isUploading = false
                }
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
             (.inviteFriendsButtonTapped, .inviteFriendsButtonTapped),
             (.reinviteConfirmDismissed, .reinviteConfirmDismissed),
             (.reinviteConfirmed, .reinviteConfirmed),
             (.drawerButtonTapped, .drawerButtonTapped),
             (.inviteFromDrawerTapped, .inviteFromDrawerTapped),
             (.mediaButtonTapped, .mediaButtonTapped),
             (.clearSelectedMedia, .clearSelectedMedia),
             (.sendMediaButtonTapped, .sendMediaButtonTapped),
             (.uploadStarted, .uploadStarted),
             (.allUploadsCompleted, .allUploadsCompleted),
             (.dismissImageViewer, .dismissImageViewer),
             (.dismissVideoPlayer, .dismissVideoPlayer),
             (.dismissFileSizeError, .dismissFileSizeError),
             (.dismissDeleteConfirmation, .dismissDeleteConfirmation):
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

        // Media Actions
        case let (.setMediaPickerPresented(lhs), .setMediaPickerPresented(rhs)):
            return lhs == rhs

        case let (.mediaSelected(lhs), .mediaSelected(rhs)):
            return lhs == rhs

        case let (.removeSelectedMedia(lhs), .removeSelectedMedia(rhs)):
            return lhs == rhs

        case let (.fileSizeExceeded(lhs), .fileSizeExceeded(rhs)):
            return lhs == rhs

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

        case let (.imageTapped(lhsURLs, lhsIndex), .imageTapped(rhsURLs, rhsIndex)):
            return lhsURLs == rhsURLs && lhsIndex == rhsIndex

        case let (.imageViewerIndexChanged(lhs), .imageViewerIndexChanged(rhs)):
            return lhs == rhs

        case let (.videoTapped(lhs), .videoTapped(rhs)):
            return lhs == rhs

        case let (.retryUpload(lhs), .retryUpload(rhs)):
            return lhs == rhs

        case let (.deleteFailedUpload(lhs), .deleteFailedUpload(rhs)):
            return lhs == rhs

        case let (.showDeleteConfirmation(lhs), .showDeleteConfirmation(rhs)):
            return lhs == rhs

        default:
            return false
        }
    }
}
