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
        var isLoading: Bool = false
        var error: String?

        // Phase 5에서 추가될 속성들:
        // - messages: [Message]
        // - inputText: String
        // - isSending: Bool

        init(
            chatRoomId: String,
            currentUserId: String,
            otherUser: Profile? = nil
        ) {
            self.chatRoomId = chatRoomId
            self.currentUserId = currentUserId
            self.otherUser = otherUser
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
        case onDisappear

        // Phase 5에서 추가될 액션들:
        // case inputTextChanged(String)
        // case sendButtonTapped
        // case messagesLoaded(Result<[Message], Error>)
        // case messageSent(Result<Void, Error>)
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Phase 5에서 메시지 로딩 구현
                return .none

            case .onDisappear:
                // Phase 5에서 리스너 정리 구현
                return .none
            }
        }
    }
}
