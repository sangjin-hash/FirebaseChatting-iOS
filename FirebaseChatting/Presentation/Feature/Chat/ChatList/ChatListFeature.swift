//
//  ChatListFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct ChatListFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var currentUserId: String = ""
        var currentUserNickname: String = ""
        var chatRoomIds: [String] = []  // 관찰할 채팅방 ID 목록
        var chatRooms: [ChatRoom] = []
        var chatRoomProfiles: [String: Profile] = [:]  // chatRoomId → 상대방 프로필
        var friends: [Profile] = []  // 그룹 채팅 생성용
        var isLoading: Bool = false
        var error: String?
        var unreadCounts: [String: Int] = [:]
        var leaveConfirmTarget: ChatRoom? = nil
        @Presents var chatRoomDestination: ChatRoomFeature.State?
        @Presents var createGroupChatDestination: CreateGroupChatFeature.State?

        // MARK: - Computed Properties

        /// 채팅방 표시 이름
        func displayName(for chatRoom: ChatRoom) -> String {
            if let profile = chatRoomProfiles[chatRoom.id] {
                // 프로필이 자기 자신이면 "대화 상대 없음" 표시
                if profile.id == currentUserId {
                    return Strings.Chat.noParticipant
                }

                if chatRoom.type == .group {
                    // 1:N 채팅방의 경우 "닉네임 외 N명" 표시
                    let otherCount = chatRoom.activeUsers.count - 1
                    if otherCount > 1 {
                        return "\(profile.nickname ?? Strings.Common.unknown) 외 \(otherCount - 1)명"
                    }
                }
                return profile.nickname ?? Strings.Common.unknown
            }
            return chatRoom.id
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case onDisappear
        case setCurrentUserId(String)
        case setCurrentUserNickname(String)
        case setChatRoomIds([String])
        case setFriends([Profile])
        case chatRoomsUpdated([ChatRoom], [String: Int])
        case chatRoomTapped(ChatRoom)
        case chatRoomDestination(PresentationAction<ChatRoomFeature.Action>)
        case createGroupChatButtonTapped
        case createGroupChatDestination(PresentationAction<CreateGroupChatFeature.Action>)
        case leaveSwipeAction(ChatRoom)
        case leaveConfirmDismissed
        case leaveConfirmed
        case leaveCompleted(Result<String, Error>)
        case loadFailed(Error)

        // Equatable 준수를 위한 에러 비교
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case (.onAppear, .onAppear),
                 (.onDisappear, .onDisappear),
                 (.leaveConfirmDismissed, .leaveConfirmDismissed),
                 (.leaveConfirmed, .leaveConfirmed),
                 (.createGroupChatButtonTapped, .createGroupChatButtonTapped):
                return true
            case let (.setCurrentUserId(lhs), .setCurrentUserId(rhs)):
                return lhs == rhs
            case let (.setCurrentUserNickname(lhs), .setCurrentUserNickname(rhs)):
                return lhs == rhs
            case let (.setChatRoomIds(lhs), .setChatRoomIds(rhs)):
                return lhs == rhs
            case let (.setFriends(lhs), .setFriends(rhs)):
                return lhs == rhs
            case let (.chatRoomsUpdated(lhsRooms, lhsCounts), .chatRoomsUpdated(rhsRooms, rhsCounts)):
                return lhsRooms == rhsRooms && lhsCounts == rhsCounts
            case let (.chatRoomTapped(lhs), .chatRoomTapped(rhs)):
                return lhs == rhs
            case let (.chatRoomDestination(lhs), .chatRoomDestination(rhs)):
                return lhs == rhs
            case let (.createGroupChatDestination(lhs), .createGroupChatDestination(rhs)):
                return lhs == rhs
            case let (.leaveSwipeAction(lhs), .leaveSwipeAction(rhs)):
                return lhs == rhs
            case let (.leaveCompleted(lhsResult), .leaveCompleted(rhsResult)):
                switch (lhsResult, rhsResult) {
                case let (.success(lhs), .success(rhs)):
                    return lhs == rhs
                case (.failure, .failure):
                    return true
                default:
                    return false
                }
            case (.loadFailed, .loadFailed):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Dependency

    @Dependency(\.chatListRepository) var chatListRepository
    @Dependency(\.chatRoomRepository) var chatRoomRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 탭 전환 시에는 스트림 유지 (setChatRoomIds에서 관리)
                return .none

            case .onDisappear:
                // 탭 전환 시에는 스트림 유지
                return .none

            case let .setCurrentUserId(userId):
                state.currentUserId = userId
                return .none

            case let .setCurrentUserNickname(nickname):
                state.currentUserNickname = nickname
                return .none

            case let .setFriends(friends):
                state.friends = friends
                return .none

            case let .setChatRoomIds(chatRoomIds):
                state.chatRoomIds = chatRoomIds
                if chatRoomIds.isEmpty {
                    state.chatRooms = []
                    state.isLoading = false
                    return .cancel(id: "observeChatRooms")
                }
                state.isLoading = true
                return .run { [chatListRepository] send in
                    for await (chatRooms, unreadCounts) in chatListRepository.observeChatRooms(chatRoomIds) {
                        await send(.chatRoomsUpdated(chatRooms, unreadCounts))
                    }
                }
                .cancellable(id: "observeChatRooms", cancelInFlight: true)

            case let .chatRoomsUpdated(chatRooms, unreadCounts):
                state.chatRooms = chatRooms
                state.unreadCounts = unreadCounts
                state.isLoading = false
                state.error = nil
                return .none

            case let .chatRoomTapped(chatRoom):
                state.chatRoomDestination = ChatRoomFeature.State(
                    chatRoomId: chatRoom.id,
                    currentUserId: state.currentUserId,
                    otherUser: state.chatRoomProfiles[chatRoom.id],
                    chatRoomType: chatRoom.type,
                    activeUserIds: Array(chatRoom.activeUsers.keys),
                    allFriends: state.friends,
                    initialUnreadCount: state.unreadCounts[chatRoom.id] ?? 0
                )
                // 채팅방 진입 시 chatRooms 스트림 해제
                return .cancel(id: "observeChatRooms")

            case .chatRoomDestination(.dismiss):
                // 채팅방에서 나갈 때 chatRooms 스트림 재시작
                guard !state.chatRoomIds.isEmpty else { return .none }
                let chatRoomIds = state.chatRoomIds
                return .run { [chatListRepository] send in
                    for await (chatRooms, unreadCounts) in chatListRepository.observeChatRooms(chatRoomIds) {
                        await send(.chatRoomsUpdated(chatRooms, unreadCounts))
                    }
                }
                .cancellable(id: "observeChatRooms")

            case .chatRoomDestination:
                return .none

            case .createGroupChatButtonTapped:
                state.createGroupChatDestination = CreateGroupChatFeature.State(
                    currentUserId: state.currentUserId,
                    friends: state.friends
                )
                return .none

            case let .createGroupChatDestination(.presented(.delegate(.groupChatPrepared(chatRoomId, selectedFriendIds)))):
                state.createGroupChatDestination = nil

                // Lazy 생성: Firestore 호출 없이 ChatRoomFeature.State 생성
                // 본인 포함 userIds 생성
                var userIds = Array(selectedFriendIds)
                userIds.append(state.currentUserId)

                // 선택된 친구 중 첫 번째를 대표 프로필로 사용
                let representativeProfile = state.friends.first { selectedFriendIds.contains($0.id) }

                state.chatRoomDestination = ChatRoomFeature.State(
                    chatRoomId: chatRoomId,
                    currentUserId: state.currentUserId,
                    otherUser: representativeProfile,
                    chatRoomType: .group,
                    activeUserIds: userIds,
                    allFriends: state.friends,
                    pendingGroupChatUserIds: userIds
                )

                // 채팅방 진입 시 chatRooms 스트림 해제
                return .cancel(id: "observeChatRooms")

            case .createGroupChatDestination:
                return .none

            case let .leaveSwipeAction(chatRoom):
                state.leaveConfirmTarget = chatRoom
                return .none

            case .leaveConfirmDismissed:
                state.leaveConfirmTarget = nil
                return .none

            case .leaveConfirmed:
                guard let chatRoom = state.leaveConfirmTarget else { return .none }
                let chatRoomId = chatRoom.id
                let userId = state.currentUserId
                let isGroupChat = chatRoom.type == .group
                let nickname = state.currentUserNickname
                state.leaveConfirmTarget = nil

                return .run { [chatListRepository, chatRoomRepository] send in
                    do {
                        // 그룹 채팅방인 경우 나가기 전 시스템 메시지 전송 (나간 사용자 정보 포함)
                        if isGroupChat {
                            let displayNickname = nickname.isEmpty ? Strings.Common.unknown : nickname
                            let message = Strings.Chat.userLeftMessage(displayNickname)
                            try await chatRoomRepository.sendSystemMessageWithLeftUser(
                                chatRoomId,
                                message,
                                userId,
                                displayNickname
                            )
                        }
                        try await chatListRepository.leaveChatRoom(chatRoomId, userId)
                        await send(.leaveCompleted(.success(chatRoomId)))
                    } catch {
                        await send(.leaveCompleted(.failure(error)))
                    }
                }

            case let .leaveCompleted(.success(chatRoomId)):
                state.chatRooms.removeAll { $0.id == chatRoomId }
                state.chatRoomProfiles.removeValue(forKey: chatRoomId)
                return .none

            case let .leaveCompleted(.failure(error)):
                state.error = error.localizedDescription
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
            }
        }
        .ifLet(\.$chatRoomDestination, action: \.chatRoomDestination) {
            ChatRoomFeature()
        }
        .ifLet(\.$createGroupChatDestination, action: \.createGroupChatDestination) {
            CreateGroupChatFeature()
        }
    }
}
