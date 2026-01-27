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
        var chatRoomIds: [String] = []  // 관찰할 채팅방 ID 목록
        var chatRooms: [ChatRoom] = []
        var chatRoomProfiles: [String: Profile] = [:]  // chatRoomId → 상대방 프로필
        var isLoading: Bool = false
        var error: String?
        var leaveConfirmTarget: ChatRoom? = nil
        @Presents var chatRoomDestination: ChatRoomFeature.State?

        // MARK: - Computed Properties

        /// 채팅방 표시 이름
        func displayName(for chatRoom: ChatRoom) -> String {
            if let profile = chatRoomProfiles[chatRoom.id] {
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
        case setChatRoomIds([String])
        case chatRoomsUpdated([ChatRoom])
        case chatRoomTapped(ChatRoom)
        case chatRoomDestination(PresentationAction<ChatRoomFeature.Action>)
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
                 (.leaveConfirmed, .leaveConfirmed):
                return true
            case let (.setCurrentUserId(lhs), .setCurrentUserId(rhs)):
                return lhs == rhs
            case let (.setChatRoomIds(lhs), .setChatRoomIds(rhs)):
                return lhs == rhs
            case let (.chatRoomsUpdated(lhs), .chatRoomsUpdated(rhs)):
                return lhs == rhs
            case let (.chatRoomTapped(lhs), .chatRoomTapped(rhs)):
                return lhs == rhs
            case let (.chatRoomDestination(lhs), .chatRoomDestination(rhs)):
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

    @Dependency(\.chatRoomRepository) var chatRoomRepository

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // chatRoomIds가 설정되어 있으면 관찰 시작
                guard !state.chatRoomIds.isEmpty else { return .none }
                state.isLoading = true
                let chatRoomIds = state.chatRoomIds

                return .run { [chatRoomRepository] send in
                    for await chatRooms in chatRoomRepository.observeChatRooms(chatRoomIds) {
                        await send(.chatRoomsUpdated(chatRooms))
                    }
                }
                .cancellable(id: "observeChatRooms")

            case .onDisappear:
                return .cancel(id: "observeChatRooms")

            case let .setCurrentUserId(userId):
                state.currentUserId = userId
                return .none

            case let .setChatRoomIds(chatRoomIds):
                state.chatRoomIds = chatRoomIds
                if chatRoomIds.isEmpty {
                    state.chatRooms = []
                    state.isLoading = false
                    return .cancel(id: "observeChatRooms")
                }
                state.isLoading = true
                return .run { [chatRoomRepository] send in
                    for await chatRooms in chatRoomRepository.observeChatRooms(chatRoomIds) {
                        await send(.chatRoomsUpdated(chatRooms))
                    }
                }
                .cancellable(id: "observeChatRooms", cancelInFlight: true)

            case let .chatRoomsUpdated(chatRooms):
                state.chatRooms = chatRooms
                state.isLoading = false
                state.error = nil
                return .none

            case let .chatRoomTapped(chatRoom):
                state.chatRoomDestination = ChatRoomFeature.State(
                    chatRoomId: chatRoom.id,
                    currentUserId: state.currentUserId,
                    otherUser: state.chatRoomProfiles[chatRoom.id]
                )
                return .none

            case .chatRoomDestination:
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
                state.leaveConfirmTarget = nil

                return .run { [chatRoomRepository] send in
                    do {
                        try await chatRoomRepository.leaveChatRoom(chatRoomId, userId)
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
    }
}
