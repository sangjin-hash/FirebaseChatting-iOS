//
//  ChatRoomRejoinIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

/// 3.3: 재입장 전체 흐름 통합 테스트
@Suite(.serialized)
@MainActor
struct ChatRoomRejoinIntegrationTests {

    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static let rejoinChatRoom = ChatRoom(
        id: "chatroom-1",
        type: .direct,
        lastMessage: "Hello",
        lastMessageAt: baseDate,
        index: 1,
        userHistory: ["current-user-123", "friend-1"],
        activeUsers: ["friend-1": baseDate]
    )

    // 재입장 시나리오: 기존 메시지가 있어야 needsToCreateChatRoom = false
    private static let existingMessages = [
        Message(
            id: "msg-old-1",
            index: 1,
            senderId: "friend-1",
            type: .text,
            content: "이전 메시지",
            createdAt: baseDate.addingTimeInterval(-100)
        )
    ]

    // MARK: - 3.3-1: onAppear → needsRejoin 감지

    @Test
    func test_rejoinFlow_detectNeedsRejoin() async {
        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in Self.existingMessages }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in Self.rejoinChatRoom }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.cachedMessagesLoaded)
        await store.receive(\.chatRoomLoaded)

        #expect(store.state.needsRejoin == true)
        #expect(store.state.isLoading == false)
    }

    // MARK: - 3.3-2: 전송 → rejoin → 리스너 시작

    @Test
    func test_rejoinFlow_sendTriggersRejoin() async {
        var rejoinCalled = false
        var sendCalled = false

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in Self.existingMessages }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in Self.rejoinChatRoom }
            $0.chatRoomRepository.rejoinChatRoom = { _, _ in rejoinCalled = true }
            $0.chatRoomRepository.sendMessage = { _, _, _ in sendCalled = true }
            $0.chatRoomRepository.observeMessages = { _ in AsyncStream { $0.finish() } }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.cachedMessagesLoaded)
        await store.receive(\.chatRoomLoaded)
        #expect(store.state.needsRejoin == true)

        await store.send(.inputTextChanged("Hello"))
        await store.send(.sendButtonTapped)

        await store.receive(\.rejoinCompleted)
        await store.receive(\.startObserving)
        await store.receive(\.messageSent)

        #expect(rejoinCalled == true)
        #expect(sendCalled == true)
        #expect(store.state.needsRejoin == false)
    }
}
