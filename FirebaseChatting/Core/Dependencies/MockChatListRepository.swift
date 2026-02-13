//
//  MockChatListRepository.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

enum MockChatListRepository {
    static func make(scenario: UITestScenario) -> ChatListRepository {
        switch scenario {
        case .chatListBasic:
            return makeChatListBasic()
        case .chatListDisplay:
            return makeChatListDisplay()
        case .chatListRealtime:
            return makeChatListRealtime()
        case .chatRoomUnreadDivider:
            return makeChatRoomUnreadDivider()
        case .chatRoomSend:
            return makeChatRoomSend()
        default:
            return makeChatListBasic()
        }
    }

    private static func makeChatListBasic() -> ChatListRepository {
        ChatListRepository(
            observeChatRooms: { _ in
                AsyncStream { continuation in
                    continuation.yield((
                        [MockDataFactory.directRoom, MockDataFactory.groupRoom],
                        [:]
                    ))
                }
            },
            leaveChatRoom: { _, _ in }
        )
    }

    private static func makeChatListDisplay() -> ChatListRepository {
        ChatListRepository(
            observeChatRooms: { _ in
                AsyncStream { continuation in
                    continuation.yield((
                        [
                            MockDataFactory.directRoom,
                            MockDataFactory.groupRoom,
                            MockDataFactory.noParticipantRoom
                        ],
                        ["D_current-user-123_friend-1": 3]
                    ))
                }
            },
            leaveChatRoom: { _, _ in }
        )
    }

    private static func makeChatRoomUnreadDivider() -> ChatListRepository {
        ChatListRepository(
            observeChatRooms: { _ in
                AsyncStream { continuation in
                    continuation.yield((
                        [MockDataFactory.directRoom],
                        ["D_current-user-123_friend-1": 50]
                    ))
                }
            },
            leaveChatRoom: { _, _ in }
        )
    }

    private static func makeChatListRealtime() -> ChatListRepository {
        ChatListRepository(
            observeChatRooms: { _ in
                AsyncStream<([ChatRoom], [String: Int])> { continuation in
                    continuation.yield((
                        [MockDataFactory.directRoom],
                        ["D_current-user-123_friend-1": 3]
                    ))
                    UITestTrigger.shared.registerChatListContinuation(continuation)
                }
            },
            leaveChatRoom: { _, _ in }
        )
    }

    // MARK: - chatRoomSend: 재관찰 시 lastSentMessage 반영

    private static func makeChatRoomSend() -> ChatListRepository {
        ChatListRepository(
            observeChatRooms: { _ in
                AsyncStream<([ChatRoom], [String: Int])> { continuation in
                    // 메시지 전송 후 재관찰 시 lastSentMessage 반영
                    if let lastSent = UITestTrigger.shared.lastSentMessage {
                        let updatedRoom = ChatRoom(
                            id: "D_current-user-123_friend-1",
                            type: .direct,
                            lastMessage: lastSent,
                            lastMessageAt: Date(),
                            index: 61,
                            userHistory: ["current-user-123", "friend-1"],
                            activeUsers: ["current-user-123": Date.distantPast, "friend-1": Date.distantPast]
                        )
                        continuation.yield(([updatedRoom], [:]))
                    } else {
                        continuation.yield((
                            [MockDataFactory.directRoom],
                            [:]
                        ))
                    }
                    UITestTrigger.shared.registerChatListContinuation(continuation)
                }
            },
            leaveChatRoom: { _, _ in }
        )
    }
}
