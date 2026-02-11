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
        #expect(state.unreadCounts == [:])
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
    func test_onAppear_doesNothing() async {
        // Given - onAppear는 탭 전환 시 스트림 유지를 위해 아무것도 하지 않음
        // 스트림 관리는 setChatRoomIds에서 담당
        let chatRoomIds = ["chatroom-1", "chatroom-2"]

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = chatRoomIds

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When & Then - onAppear should do nothing
        await store.send(.onAppear)
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
        await store.send(.chatRoomsUpdated(chatRooms, [:])) {
            // Then
            $0.chatRooms = chatRooms
            $0.isLoading = false
            $0.error = nil
        }
    }

    // MARK: - chatRoomTapped Tests

    @Test
    func test_chatRoomTapped_navigatesToChatRoomAndCancelsObserver() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRooms = TestData.chatRooms

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        let chatRoom = TestData.chatRooms[0]

        // When - chatRoomTapped should cancel observeChatRooms
        await store.send(.chatRoomTapped(chatRoom)) {
            // Then
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: chatRoom.id,
                currentUserId: "user-123",
                chatRoomType: chatRoom.type,
                activeUserIds: Array(chatRoom.activeUsers.keys)
            )
        }
        // Note: cancel effect는 TestStore에서 자동으로 처리됨
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
            $0.chatListRepository.leaveChatRoom = { _, _ in }
            $0.chatRoomRepository.sendSystemMessageWithLeftUser = { _, _, _, _ in }
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
    func test_onDisappear_doesNothing() async {
        // Given - onDisappear는 탭 전환 시 스트림 유지를 위해 아무것도 하지 않음
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When & Then - onDisappear should do nothing
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
            $0.chatListRepository.observeChatRooms = { ids in
                #expect(ids == chatRoomIds)
                return AsyncStream { continuation in
                    continuation.yield((chatRooms, [:]))
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
            $0.chatListRepository.observeChatRooms = { ids in
                AsyncStream { continuation in
                    if ids == newIds {
                        continuation.yield((newRooms, [:]))
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
    func test_setChatRoomIds_updatesUnreadCounts() async {
        // Given
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms
        let unreadCounts: [String: Int] = ["chatroom-1": 5, "chatroom-2": 3]

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { _ in
                AsyncStream { continuation in
                    continuation.yield((chatRooms, unreadCounts))
                    continuation.finish()
                }
            }
        }

        // When
        await store.send(.setChatRoomIds(chatRoomIds)) {
            $0.chatRoomIds = chatRoomIds
            $0.isLoading = true
        }

        // Then - unreadCounts가 State에 반영되어야 함
        await store.receive(\.chatRoomsUpdated) {
            $0.chatRooms = chatRooms
            $0.unreadCounts = unreadCounts
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

    @Test
    func test_displayName_whenProfileIsMyself_showsNoParticipant() {
        // Given - 상대방이 나간 경우 프로필이 자기 자신일 때
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.chatRoomProfiles = [
            "chatroom-1": Profile(id: "current-user-123", nickname: "나")
        ]

        let chatRoom = ChatRoom(
            id: "chatroom-1",
            type: .direct,
            index: 10
        )

        // When & Then - "대화 상대 없음" 표시
        #expect(state.displayName(for: chatRoom) == Strings.Chat.noParticipant)
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

        // When - chatRoomTapped should cancel observeChatRooms
        await store.send(.chatRoomTapped(TestData.chatRoom1)) {
            // Then - otherUser should be set
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: TestData.chatRoom1.id,
                currentUserId: "current-user-123",
                otherUser: profile,
                chatRoomType: TestData.chatRoom1.type,
                activeUserIds: Array(TestData.chatRoom1.activeUsers.keys)
            )
        }
    }

    // MARK: - chatRoomDestination dismiss Tests

    @Test
    func test_chatRoomDestination_dismiss_restartsObserver() async {
        // Given - 채팅방에 진입한 상태
        let chatRoomIds = ["chatroom-1", "chatroom-2"]
        let chatRooms = TestData.chatRooms

        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = chatRoomIds
        state.chatRooms = chatRooms
        state.chatRoomDestination = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "user-123"
        )

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatListRepository.observeChatRooms = { ids in
                #expect(ids == chatRoomIds)
                return AsyncStream { continuation in
                    continuation.yield((chatRooms, [:]))
                    continuation.finish()
                }
            }
        }

        // When - 채팅방에서 나감 (dismiss)
        await store.send(.chatRoomDestination(.dismiss)) {
            $0.chatRoomDestination = nil
        }

        // Then - observeChatRooms 재시작 (chatRooms가 동일하므로 상태 변경 없음)
        await store.receive(\.chatRoomsUpdated)
    }

    @Test
    func test_chatRoomDestination_dismiss_withEmptyChatRoomIds_doesNothing() async {
        // Given - chatRoomIds가 비어있는 상태
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.chatRoomIds = []
        state.chatRoomDestination = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "user-123"
        )

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When - 채팅방에서 나감 (dismiss)
        await store.send(.chatRoomDestination(.dismiss)) {
            $0.chatRoomDestination = nil
        }

        // Then - chatRoomIds가 비어있으면 아무것도 하지 않음
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
        await store.send(.chatRoomsUpdated([], [:])) {
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

    // MARK: - setFriends Tests

    @Test
    func test_setFriends_updatesFriends() async {
        // Given
        let store = TestStore(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }

        // When
        await store.send(.setFriends(TestData.friendProfiles)) {
            // Then
            $0.friends = TestData.friendProfiles
        }
    }

    // MARK: - setCurrentUserNickname Tests

    @Test
    func test_setCurrentUserNickname_updatesNickname() async {
        // Given
        let store = TestStore(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }

        // When
        await store.send(.setCurrentUserNickname("TestUser")) {
            // Then
            $0.currentUserNickname = "TestUser"
        }
    }

    // MARK: - createGroupChatButtonTapped Tests

    @Test
    func test_createGroupChatButtonTapped_presentsSheet() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.friends = TestData.friendProfiles

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.createGroupChatButtonTapped) {
            // Then
            $0.createGroupChatDestination = CreateGroupChatFeature.State(
                currentUserId: "user-123",
                friends: TestData.friendProfiles
            )
        }
    }

    @Test
    func test_createGroupChatButtonTapped_withNoFriends_stillPresentsSheet() async {
        // Given - 친구 없어도 모달 표시 (빈 상태 메시지)
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.friends = []

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.createGroupChatButtonTapped) {
            // Then - 친구 없어도 모달 표시
            $0.createGroupChatDestination = CreateGroupChatFeature.State(
                currentUserId: "user-123",
                friends: []
            )
        }
    }

    // MARK: - createGroupChatDestination Tests

    @Test
    func test_createGroupChatDestination_groupChatPrepared_navigatesToChatRoom() async {
        // Given
        var state = ChatListFeature.State()
        state.currentUserId = "user-123"
        state.friends = TestData.friendProfiles
        state.createGroupChatDestination = CreateGroupChatFeature.State(
            currentUserId: "user-123",
            friends: TestData.friendProfiles
        )

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        let selectedFriendIds: Set<String> = ["friend-1", "friend-2"]
        let userIds = Array(selectedFriendIds) + ["user-123"]

        // When
        await store.send(.createGroupChatDestination(.presented(.delegate(.groupChatPrepared(chatRoomId: "G_test123", selectedFriendIds: selectedFriendIds))))) {
            // Then - 모달 닫고 채팅방으로 이동
            $0.createGroupChatDestination = nil
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: "G_test123",
                currentUserId: "user-123",
                otherUser: TestData.friend1Profile,  // 첫 번째 선택된 친구
                chatRoomType: .group,
                activeUserIds: userIds,
                allFriends: TestData.friendProfiles,
                pendingGroupChatUserIds: userIds
            )
        }
    }

    // MARK: - leaveConfirmed for Group Chat Tests

    @Test
    func test_leaveConfirmed_sendsSystemMessage_forGroupChat() async {
        // Given
        let groupChatRoom = TestData.groupChatRoom1
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.currentUserNickname = "TestUser"
        state.chatRooms = [groupChatRoom]
        state.leaveConfirmTarget = groupChatRoom

        var sentSystemMessage: String?
        var sentChatRoomId: String?
        var sentLeftUserId: String?
        var sentLeftUserNickname: String?

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendSystemMessageWithLeftUser = { chatRoomId, message, leftUserId, leftUserNickname in
                sentChatRoomId = chatRoomId
                sentSystemMessage = message
                sentLeftUserId = leftUserId
                sentLeftUserNickname = leftUserNickname
            }
            $0.chatListRepository.leaveChatRoom = { _, _ in }
        }

        // When
        await store.send(.leaveConfirmed) {
            $0.leaveConfirmTarget = nil
        }

        // Then
        await store.receive(\.leaveCompleted.success) {
            $0.chatRooms.removeAll { $0.id == groupChatRoom.id }
            $0.chatRoomProfiles.removeValue(forKey: groupChatRoom.id)
        }

        #expect(sentChatRoomId == groupChatRoom.id)
        #expect(sentSystemMessage == Strings.Chat.userLeftMessage("TestUser"))
        #expect(sentLeftUserId == "current-user-123")
        #expect(sentLeftUserNickname == "TestUser")
    }

    @Test
    func test_leaveConfirmed_doesNotSendSystemMessage_forDirectChat() async {
        // Given
        let directChatRoom = TestData.chatRoom1
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.currentUserNickname = "TestUser"
        state.chatRooms = [directChatRoom]
        state.leaveConfirmTarget = directChatRoom

        var sendSystemMessageCalled = false

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendSystemMessage = { _, _ in
                sendSystemMessageCalled = true
            }
            $0.chatListRepository.leaveChatRoom = { _, _ in }
        }

        // When
        await store.send(.leaveConfirmed) {
            $0.leaveConfirmTarget = nil
        }

        // Then
        await store.receive(\.leaveCompleted.success) {
            $0.chatRooms.removeAll { $0.id == directChatRoom.id }
            $0.chatRoomProfiles.removeValue(forKey: directChatRoom.id)
        }

        #expect(sendSystemMessageCalled == false)
    }

    // MARK: - chatRoomTapped with Group Chat Tests

    @Test
    func test_chatRoomTapped_passesGroupChatInfo() async {
        // Given
        let groupChatRoom = TestData.groupChatRoom1
        var state = ChatListFeature.State()
        state.currentUserId = "current-user-123"
        state.chatRooms = [groupChatRoom]
        state.chatRoomProfiles = [groupChatRoom.id: TestData.friend1Profile]
        state.friends = TestData.friendProfiles

        let store = TestStore(initialState: state) {
            ChatListFeature()
        }

        // When
        await store.send(.chatRoomTapped(groupChatRoom)) {
            // Then
            $0.chatRoomDestination = ChatRoomFeature.State(
                chatRoomId: groupChatRoom.id,
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile,
                chatRoomType: .group,
                activeUserIds: Array(groupChatRoom.activeUsers.keys),
                allFriends: TestData.friendProfiles
            )
        }
    }
}
