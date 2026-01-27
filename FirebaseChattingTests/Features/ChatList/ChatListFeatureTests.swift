//
//  ChatListFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct ChatListFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = ChatListFeature.State()

        // Then
        #expect(state.currentUserId == "")
        #expect(state.chatRoomIds == [])
        #expect(state.chatRooms == [])
        #expect(state.chatRoomProfiles == [:])
        #expect(state.isLoading == false)
        #expect(state.error == nil)
        #expect(state.leaveConfirmTarget == nil)
        #expect(state.chatRoomDestination == nil)
    }

    // MARK: - setCurrentUserId Tests

    @Test
    func test_setCurrentUserId_updatesState() async {
        // Given
        let store = TestStore(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }

        // When
        await store.send(.setCurrentUserId("user-123")) {
            // Then
            $0.currentUserId = "user-123"
        }
    }

    // MARK: - onAppear Tests

    @Test
    func test_onAppear_withNoChatRoomIds_doesNothing() async {
        // Given
        let store = TestStore(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }

        // When & Then
        await store.send(.onAppear)
    }

    @Test
    func test_onAppear_withChatRoomIds_startsChatRoomsObserver() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = chatRoomIds

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.observeChatRooms = { ids in
                #expect(ids == chatRoomIds)
                return AsyncStream { continuation in
                    continuation.yield(chatRooms)
                    continuation.finish()
                }
            }
        }

        // When
        await store.send(.onAppear) {
            $0.isLoading = true
        }

        // Then - verify we receive chatRooms update
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = chatRooms
            $0.isLoading = false
            $0.error = nil
        }
    }

    // MARK: - chatRoomsUpdated Tests

    @Test
    func test_chatRoomsUpdated_sortsByLastMessageAt() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        let chatRooms = TestData.chatRooms

        // When
        await store.send(.chatRoomsUpdated(chatRooms)) {
            // Then
            $0.chatRooms = chatRooms
            $0.isLoading = false
            $0.error = nil
        }
    }

    // MARK: - chatRoomTapped Tests

    @Test
    func test_chatRoomTapped_navigatesToChatRoom() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        let chatRoom = TestData.chatRooms[0]

        // When
        await store.send(.chatRoomTapped(chatRoom)) {
            // Then
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: chatRoom.id,
                currentUserId: "user-123"
            )
        }
    }

    // MARK: - Leave Swipe Action Tests

    @Test
    func test_leaveSwipeAction_showsConfirmDialog() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        let chatRoom = TestData.chatRooms[0]

        // When
        await store.send(.leaveSwipeAction(chatRoom)) {
            // Then
            $0.leaveConfirmTarget = chatRoom
        }
    }

    @Test
    func test_leaveConfirmDismissed_hidesDialog() async {
        // Given
        var state = ChatListFeature.State()
        state.leaveConfirmTarget = TestData.chatRooms[0]

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.leaveConfirmDismissed) {
            // Then
            $0.leaveConfirmTarget = nil
        }
    }

    @Test
    func test_leaveConfirmed_removesChatRoom() async {
        // Given
        let chatRoom = TestData.chatRooms[0]
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms
        state.leaveConfirmTarget = chatRoom

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.leaveChatRoom = { _, _ in }
        }

        // When
        await store.send(.leaveConfirmed) {
            $0.leaveConfirmTarget = nil
        }

        // Then
        await store.receive(\.leaveCompleted) {
            $0.chatRooms.removeAll { $0.id == chatRoom.id }
        }
    }

    // MARK: - displayName Tests

    @Test
    func test_displayName_withProfile() {
        // Given
        var state = ChatListFeature.State()
        state.chatRoomProfiles = ["chatroom-1": Profile(id: "user-456", nickname: "홍길동")]

        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            index: 10
        )

        // When & Then
        #expect(state.displayName(for: chatRoom) == "홍길동")
    }

    @Test
    func test_displayName_withoutProfile() {
        // Given
        let state = ChatListFeature.State()

        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            index: 10
        )

        // When & Then
        #expect(state.displayName(for: chatRoom) == "chatroom-1")
    }

    // MARK: - onDisappear Tests

    @Test
    func test_onDisappear_cancelsObserver() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When & Then - onDisappear should cancel the observer
        await store.send(.onDisappear)
    }

    // MARK: - setChatRoomIds Tests

    @Test
    func test_setChatRoomIds_withEmptyIds_clearsRoomsAndCancels() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms
        state.chatRoomIds = ["chatroom-1"]
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.setChatRoomIds([])) {
            // Then
            $0.chatRoomIds = []
            $0.chatRooms = []
            $0.isLoading = false
        }
    }

    @Test
    func test_setChatRoomIds_withIds_startsObserving() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.observeChatRooms = { ids in
                #expect(ids == chatRoomIds)
                return AsyncStream { continuation in
                    continuation.yield(chatRooms)
                    continuation.finish()
                }
            }
        }

        // When
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
    }

    @Test
    func test_setChatRoomIds_withNewIds_cancelsAndRestarts() async {
        // Given
        let initialIds = ["chatroom-1"]
        let newIds = ["chatroom-1", "chatroom-2"]
        let newRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = initialIds

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.observeChatRooms = { ids in
                AsyncStream { continuation in
                    if ids == newIds {
                        continuation.yield(newRooms)
                    }
                    continuation.finish()
                }
            }
        }

        // When - set new chatRoomIds
        await store.send(.setChatRoomIds(newIds)) {
            $0.chatRoomIds = newIds
            $0.isLoading = true
        }

        // Then - should receive updated chatRooms
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = newRooms
            $0.isLoading = false
            $0.error = nil
        }
    }

    @Test
    func test_loadFailed_setsErrorAndStopsLoading() async {
        // Given
        var state = ChatListFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.loadFailed(TestError.networkError)) {
            // Then
            $0.isLoading = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - displayName for Group ChatRoom Tests

    @Test
    func test_displayName_forGroupChatRoom_showsCountSuffix() {
        // Given
        var state = ChatListFeature.State()
        state.chatRoomProfiles = ["G_group123": TestData.friend1Profile]

        // When & Then - 3명 (activeUsers 3명 - 1명(본인) = 2명) → "닉네임 외 1명"
        #expect(state.displayName(for: TestData.groupChatRoom1) == "Friend One 외 1명")
    }

    @Test
    func test_displayName_forGroupChatRoom_withTwoUsers_showsNicknameOnly() {
        // Given
        var state = ChatListFeature.State()
        state.chatRoomProfiles = ["G_group456": TestData.friend1Profile]

        // When & Then - 2명 (activeUsers 2명 - 1명(본인) = 1명) → 닉네임만 표시
        #expect(state.displayName(for: TestData.groupChatRoom2TwoUsers) == "Friend One")
    }

    @Test
    func test_displayName_forDirectChatRoom_withNilNickname_showsUnknown() {
        // Given
        var state = ChatListFeature.State()
        state.chatRoomProfiles = ["chatroom-1": Profile(id: "user-456", nickname: nil)]

        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            index: 10
        )

        // When & Then
        #expect(state.displayName(for: chatRoom) == Strings.Common.unknown)
    }

    // MARK: - chatRoomTapped with Profile Tests

    @Test
    func test_chatRoomTapped_withProfile_includesOtherUserInDestination() async {
        // Given
        let profile = TestData.friend1Profile
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.chatRooms = [TestData.chatRoom1]
        state.chatRoomProfiles = ["chatroom-1": profile]

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.chatRoomTapped(TestData.chatRoom1)) {
            // Then - otherUser should be set
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: TestData.chatRoom1.id,
                currentUserId: "current-user-123",
                otherUser: profile
            )
        }
    }

    // MARK: - chatRoomsUpdated with Empty List Tests

    @Test
    func test_chatRoomsUpdated_withEmptyList_setsEmptyChatRooms() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.chatRoomsUpdated([])) {
            // Then
            $0.chatRooms = []
            $0.isLoading = false
            $0.error = nil
        }
    }

    // MARK: - leaveCompleted Failure Tests

    @Test
    func test_leaveCompleted_failure_setsError() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.leaveCompleted(.failure(TestError.networkError))) {
            // Then
            $0.error = TestError.networkError.localizedDescription
        }
    }
}
