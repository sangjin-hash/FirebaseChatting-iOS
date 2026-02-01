//
//  ChatListIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct ChatListIntegrationTests {

    // MARK: - Full Flow Tests

    @Test
    func test_fullFlow_loadChatRoomsAndNavigate() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { ids in
                #expect(ids == chatRoomIds)
                return AsyncStream { continuation in
                    continuation.yield(chatRooms)
                    continuation.finish()
                }
            }
        }

        // When - setChatRoomIds starts loading (MainTabFeature에서 호출)
        await store.send(.setChatRoomIds(chatRoomIds)) {
            $0.chatRoomIds = chatRoomIds
            $0.isLoading = true
        }

        // Then - chatRoomsUpdated received
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = chatRooms
            $0.isLoading = false
            $0.error = nil
        }

        // When - user taps a chat room (cancels observer)
        await store.send(.chatRoomTapped(chatRooms[0])) {
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: chatRooms[0].id,
                currentUserId: "user-123",
                chatRoomType: chatRooms[0].type,
                activeUserIds: Array(chatRooms[0].activeUsers.keys)
            )
        }
    }

    @Test
    func test_fullFlow_leaveRoom() async {
        // Given
        let chatRoom = TestData.chatRoom1
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = [chatRoom]

        var leaveCalled = false

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.leaveChatRoom = { roomId, userId in
                #expect(roomId == chatRoom.id)
                #expect(userId == "user-123")
                leaveCalled = true
            }
        }

        // When - user swipes to leave
        await store.send(.leaveSwipeAction(chatRoom)) {
            $0.leaveConfirmTarget = chatRoom
        }

        // And - confirms leave
        await store.send(.leaveConfirmed) {
            $0.leaveConfirmTarget = nil
        }

        // Then - room is removed
        await store.receive(\.leaveCompleted) {
            $0.chatRooms = []
        }

        // Verify repository was called
        #expect(leaveCalled)
    }

    @Test
    func test_realTimeUpdate_newChatRoom() async {
        // Given
        let chatRoomIds = ["chatroom-1"]
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let initialRooms = [TestData.chatRoom1]

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { _ in
                AsyncStream { continuation in
                    continuation.yield(initialRooms)
                    continuation.finish()
                }
            }
        }

        // When - setChatRoomIds starts observing (MainTabFeature에서 호출)
        await store.send(.setChatRoomIds(chatRoomIds)) {
            $0.chatRoomIds = chatRoomIds
            $0.isLoading = true
        }

        // Then - verify we receive chatRooms update
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = initialRooms
            $0.isLoading = false
            $0.error = nil
        }
    }

    @Test
    func test_displayName_direct() {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms
        state.chatRoomProfiles = [
            "chatroom-1": Profile(id: "user-456", nickname: "홍길동")
        ]

        // Then
        #expect(state.displayName(for: TestData.chatRoom1) == "홍길동")
        #expect(state.displayName(for: TestData.chatRoom2) == "chatroom-2")  // No profile
    }

    // MARK: - (7)-1: Empty ChatRooms Integration Test

    @Test
    func test_fullFlow_emptyChatRooms_rendersEmptyUI() async {
        // Given - 기존 채팅방이 있는 상태에서 시작
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = ["chatroom-1"]
        state.chatRooms = [TestData.chatRoom1]
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When - setChatRoomIds with empty array
        await store.send(.setChatRoomIds([])) {
            $0.chatRoomIds = []
            $0.chatRooms = []
            $0.isLoading = false
        }

        // Then - verify empty state
        #expect(store.state.chatRooms.isEmpty)
        #expect(!store.state.isLoading)
    }

    // MARK: - (7)-2: Set ChatRoomIds Integration Test

    @Test
    func test_fullFlow_setChatRoomIds_loadsAndDisplaysRooms() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        var observeCalledWithIds: [String]?

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { ids in
                observeCalledWithIds = ids
                return AsyncStream { continuation in
                    continuation.yield(chatRooms)
                    continuation.finish()
                }
            }
        }

        // When - setChatRoomIds
        await store.send(.setChatRoomIds(chatRoomIds)) {
            $0.chatRoomIds = chatRoomIds
            $0.isLoading = true
        }

        // Then - chatRoomsUpdated should be received
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = chatRooms
            $0.isLoading = false
            $0.error = nil
        }

        // Verify observeChatRooms was called with correct ids
        #expect(observeCalledWithIds == chatRoomIds)
    }

    // MARK: - (8): New ChatRoom Added Integration Test

    @Test
    func test_fullFlow_newChatRoomAdded_updatesUI() async {
        // Given - 기존 채팅방 1개
        let initialIds = ["chatroom-1"]
        let initialRooms = [TestData.chatRoom1]

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = initialIds
        state.chatRooms = initialRooms

        // 새 채팅방 추가 후 상태
        let newIds = ["chatroom-1", "chatroom-2"]
        let allRooms = TestData.chatRooms

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { ids in
                AsyncStream { continuation in
                    if ids == newIds {
                        continuation.yield(allRooms)
                    }
                    continuation.finish()
                }
            }
        }

        // When - 새 chatRoomIds 설정 (user document 업데이트 시뮬레이션)
        await store.send(.setChatRoomIds(newIds)) {
            $0.chatRoomIds = newIds
            $0.isLoading = true
        }

        // Then - 새 채팅방 포함된 목록으로 업데이트
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = allRooms
            $0.isLoading = false
            $0.error = nil
        }

        #expect(store.state.chatRooms.count == 2)
    }

    // MARK: - ChatRoom Navigation Flow Tests

    @Test
    func test_fullFlow_enterAndExitChatRoom_managesObserverCorrectly() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = chatRoomIds
        state.chatRooms = chatRooms

        var observeCallCount = 0

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { ids in
                observeCallCount += 1
                return AsyncStream { continuation in
                    continuation.yield(chatRooms)
                    continuation.finish()
                }
            }
        }

        // When - 채팅방 진입 (observer cancel)
        await store.send(.chatRoomTapped(chatRooms[0])) {
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: chatRooms[0].id,
                currentUserId: "user-123",
                chatRoomType: chatRooms[0].type,
                activeUserIds: Array(chatRooms[0].activeUsers.keys)
            )
        }

        // When - 채팅방 나감 (observer restart)
        await store.send(.chatRoomDestination(.dismiss)) {
            $0.chatRoomDestination = nil
        }

        // Then - observer가 다시 시작됨 (chatRooms가 동일하므로 상태 변경 없음)
        await store.receive(\.chatRoomsUpdated)

        #expect(observeCallCount == 1)
    }

    // MARK: - Group ChatRoom Display Name Integration Test

    @Test
    func test_fullFlow_groupChatRoom_displaysCorrectName() {
        // Given - Group 채팅방 (3명)
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.chatRooms = TestData.chatRoomsWithGroup
        state.chatRoomProfiles = TestData.chatRoomProfiles

        // Then - 3명 그룹: "Friend One 외 1명"
        #expect(state.displayName(for: TestData.groupChatRoom1) == "Friend One 외 1명")

        // 2명 그룹: "Friend One"
        #expect(state.displayName(for: TestData.groupChatRoom2TwoUsers) == "Friend One")

        // Direct: Profile 닉네임
        #expect(state.displayName(for: TestData.chatRoom1) == "Friend One")
    }
}
