//
//  ChatRoomSyncIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

/// 3.1 ~ 3.2: 캐시 → 서버 동기화 통합 테스트
@Suite(.serialized)
@MainActor
struct ChatRoomSyncIntegrationTests {

    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func makeMessages(count: Int, startIndex: Int, baseOffset: TimeInterval = 0) -> [Message] {
        (0..<count).map { i in
            Message(
                id: "msg-gen-\(startIndex + i)",
                index: startIndex + i,
                senderId: i.isMultiple(of: 2) ? "current-user-123" : "friend-1",
                type: .text,
                content: "메시지 \(startIndex + i)",
                createdAt: baseDate.addingTimeInterval(baseOffset + Double(i) * 10)
            )
        }
    }

    // MARK: - 3.1 Case A: 캐시 → 서버 동기화(unread=0) → 리스너 → 실시간 수신 (ID 기반 병합)

    @Test
    func test_caseA_cacheLoadThenObserve_mergesById() async {
        let joinedAt = Self.baseDate.addingTimeInterval(-7200)
        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            lastMessage: "Hello",
            lastMessageAt: Self.baseDate,
            index: 5,
            userHistory: ["current-user-123", "friend-1"],
            activeUsers: ["current-user-123": joinedAt, "friend-1": joinedAt]
        )

        let cachedMessages = TestData.messages
        let observerMessages = [TestData.message3] + TestData.newerMessages

        var expectedDict = Dictionary(uniqueKeysWithValues: cachedMessages.map { ($0.id, $0) })
        for msg in observerMessages {
            expectedDict[msg.id] = msg
        }
        let expectedMessages = expectedDict.values.sorted { $0.createdAt < $1.createdAt }

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile,
                initialUnreadCount: 0
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in cachedMessages }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in chatRoom }
            $0.chatRoomRepository.observeMessages = { _ in
                AsyncStream { continuation in
                    continuation.yield(observerMessages)
                    continuation.finish()
                }
            }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.cachedMessagesLoaded) {
            $0.messages = cachedMessages
            $0.isLoading = false
        }

        await store.receive(\.chatRoomLoaded) {
            $0.currentUserJoinedAt = joinedAt
            $0.needsRejoin = false
        }
        await store.receive(\.startObserving)

        await store.receive(\.messagesUpdated) {
            $0.messages = expectedMessages
            $0.isLoading = false
        }

        #expect(store.state.messages.count == 5)
        #expect(Set(store.state.messages.map(\.id)).count == 5)
    }

    // MARK: - 3.2 Case B: 캐시 → 순방향 페이지네이션 2회 → 리스너 전환

    @Test
    func test_caseB_paginationThenObserverTransition() async {
        let joinedAt = Self.baseDate.addingTimeInterval(-7200)
        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            lastMessage: "Hello",
            lastMessageAt: Self.baseDate,
            index: 50,
            userHistory: ["current-user-123", "friend-1"],
            activeUsers: ["current-user-123": joinedAt, "friend-1": joinedAt]
        )

        let cachedMessages = Self.makeMessages(count: 3, startIndex: 1, baseOffset: -1000)
        let newerPage1 = Self.makeMessages(count: 30, startIndex: 4, baseOffset: 0)
        let newerPage2 = Self.makeMessages(count: 15, startIndex: 34, baseOffset: 300)
        let realtimeMessage = Self.makeMessages(count: 1, startIndex: 49, baseOffset: 600)

        var fetchNewerCallCount = 0

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile,
                initialUnreadCount: 5
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in cachedMessages }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in chatRoom }
            $0.chatRoomRepository.fetchNewerMessages = { _, _, _ in
                fetchNewerCallCount += 1
                return fetchNewerCallCount == 1 ? newerPage1 : newerPage2
            }
            $0.chatRoomRepository.observeMessages = { _ in
                AsyncStream { continuation in
                    continuation.yield(realtimeMessage)
                    continuation.finish()
                }
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.cachedMessagesLoaded)
        await store.receive(\.chatRoomLoaded)

        await store.receive(\.newerMessagesFetched)
        #expect(store.state.hasMoreNewerMessages == true)
        #expect(store.state.unreadDividerMessageId == newerPage1.first?.id)

        await store.send(.loadNewerMessages)

        await store.receive(\.newerMessagesFetched)
        #expect(store.state.hasMoreNewerMessages == false)

        await store.receive(\.startObserving)
        await store.receive(\.messagesUpdated)

        #expect(fetchNewerCallCount == 2)
        #expect(store.state.messages.count > cachedMessages.count)
    }
}
