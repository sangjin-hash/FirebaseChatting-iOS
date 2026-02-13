//
//  UITestTrigger.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

final class UITestTrigger: @unchecked Sendable {
    static let shared = UITestTrigger()

    private var chatListContinuation: AsyncStream<([ChatRoom], [String: Int])>.Continuation?
    private var triggerCount = 0

    // MARK: - SharedSendState (Send 시나리오)

    var messageContinuation: AsyncStream<[Message]>.Continuation?
    var lastSentMessage: String?

    func registerChatListContinuation(
        _ continuation: AsyncStream<([ChatRoom], [String: Int])>.Continuation
    ) {
        self.chatListContinuation = continuation
    }

    func fireChatListEvent() {
        triggerCount += 1

        switch triggerCount {
        case 1:
            chatListContinuation?.yield((
                [MockDataFactory.directRoom, MockDataFactory.groupRoom],
                ["D_current-user-123_friend-1": 3]
            ))
        case 2:
            chatListContinuation?.yield((
                [MockDataFactory.directRoom, MockDataFactory.groupRoom],
                ["D_current-user-123_friend-1": 4]
            ))
        default:
            break
        }
    }

    /// ChatList 재관찰 시 lastSentMessage를 반영한 채팅방 목록 yield
    func yieldUpdatedChatList() {
        guard let lastSentMessage else { return }
        let updatedRoom = ChatRoom(
            id: "D_current-user-123_friend-1",
            type: .direct,
            lastMessage: lastSentMessage,
            lastMessageAt: Date(),
            index: 61,
            userHistory: ["current-user-123", "friend-1"],
            activeUsers: ["current-user-123": Date.distantPast, "friend-1": Date.distantPast]
        )
        chatListContinuation?.yield(([updatedRoom], [:]))
    }
}
