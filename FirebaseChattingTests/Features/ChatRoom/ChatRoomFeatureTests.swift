//
//  ChatRoomFeatureTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct ChatRoomFeatureTests {

    // MARK: - Initial State Tests

    @Test
    func test_initialState_hasCorrectDefaults() {
        // Given & When
        let state = ChatRoomFeature.State(
            chatRoomId: "D_user1_user2",
            currentUserId: "user1"
        )

        // Then
        #expect(state.chatRoomId == "D_user1_user2")
        #expect(state.currentUserId == "user1")
        #expect(state.otherUser == nil)
        #expect(state.messages == [])
        #expect(state.inputText == "")
        #expect(state.isLoading == false)
        #expect(state.isSending == false)
        #expect(state.error == nil)
        #expect(state.hasMoreMessages == true)
    }

    // MARK: - onAppear Tests

    @Test
    func test_onAppear_startsMessageObserver() async {
        // Given
        let messages = TestData.messages

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123"
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.observeMessages = { chatRoomId, limit in
                #expect(chatRoomId == "chatroom-1")
                #expect(limit == 30)
                return AsyncStream { continuation in
                    continuation.yield(messages)
                    continuation.finish()
                }
            }
        }

        // When
        await store.send(.onAppear) {
            $0.isLoading = true
        }

        // Then - otherUser가 없으면 chatRoomLoaded(nil)을 받음
        await store.receive(\.chatRoomLoaded) // nil case
        await store.receive(\.messagesUpdated) {
            $0.messages = messages
            $0.isLoading = false
        }
    }

    @Test
    func test_onAppear_withExistingChatRoom_loadsMessages() async {
        // Given
        let messages = TestData.messages
        let joinedAt = Date()
        let chatRoom = ChatRoom(
            id: "D_current-user-123_friend-1",
            type: .direct,
            lastMessage: "Hello",
            lastMessageAt: Date(),
            index: 1,
            userHistory: ["current-user-123", "friend-1"],
            activeUsers: ["current-user-123": joinedAt, "friend-1": joinedAt]
        )

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.observeMessages = { _, _ in
                AsyncStream { continuation in
                    continuation.yield(messages)
                    continuation.finish()
                }
            }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in
                return chatRoom
            }
        }

        // When
        await store.send(.onAppear) {
            $0.isLoading = true
        }

        // Then - chatRoomLoaded로 joinedAt 설정
        await store.receive(\.chatRoomLoaded) {
            $0.currentUserJoinedAt = joinedAt
            $0.needsRejoin = false
        }
        await store.receive(\.messagesUpdated) {
            $0.messages = messages
            $0.isLoading = false
        }
    }

    // MARK: - onDisappear Tests

    @Test
    func test_onDisappear_cancelsMessageObserver() async {
        // Given
        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123"
            )
        ) {
            ChatRoomFeature()
        }

        // When & Then
        await store.send(.onDisappear)
    }

    // MARK: - Input Text Tests

    @Test
    func test_inputTextChanged_updatesState() async {
        // Given
        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "chatroom-1",
                currentUserId: "current-user-123"
            )
        ) {
            ChatRoomFeature()
        }

        // When
        await store.send(.inputTextChanged("안녕하세요")) {
            // Then
            $0.inputText = "안녕하세요"
        }
    }

    // MARK: - Send Message Tests

    @Test
    func test_sendButtonTapped_withEmptyText_doesNothing() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = ""

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then - should not change state or trigger effects
        await store.send(.sendButtonTapped)
    }

    @Test
    func test_sendButtonTapped_withWhitespaceOnly_doesNothing() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "   "

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then
        await store.send(.sendButtonTapped)
    }

    @Test
    func test_sendButtonTapped_sendsMessage_success() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "테스트 메시지"
        state.messages = [TestData.message1] // 기존 메시지가 있어야 sendMessage 호출

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMessage = { chatRoomId, userId, content in
                #expect(chatRoomId == "chatroom-1")
                #expect(userId == "current-user-123")
                #expect(content == "테스트 메시지")
            }
        }

        // When
        await store.send(.sendButtonTapped) {
            $0.isSending = true
            $0.inputText = ""
        }

        // Then
        await store.receive(\.messageSent) {
            $0.isSending = false
        }
    }

    @Test
    func test_sendButtonTapped_sendsMessage_failure() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "테스트 메시지"
        state.messages = [TestData.message1]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMessage = { _, _, _ in
                throw TestError.networkError
            }
        }

        // When
        await store.send(.sendButtonTapped) {
            $0.isSending = true
            $0.inputText = ""
        }

        // Then
        await store.receive(\.messageSent) {
            $0.isSending = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Create ChatRoom and Send First Message Tests

    @Test
    func test_sendFirstMessage_createsChatRoomAndSendsMessage() async {
        // Given - 채팅방이 없는 상태에서 첫 메시지 전송
        var state = ChatRoomFeature.State(
            chatRoomId: "D_current-user-123_friend-1",
            currentUserId: "current-user-123",
            otherUser: TestData.friend1Profile
        )
        state.inputText = "첫 메시지입니다"
        // messages가 비어있으면 createChatRoomAndSendMessage 호출

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.createChatRoomAndSendMessage = { chatRoomId, userIds, senderId, content in
                #expect(chatRoomId == "D_current-user-123_friend-1")
                #expect(userIds.contains("current-user-123"))
                #expect(userIds.contains("friend-1"))
                #expect(senderId == "current-user-123")
                #expect(content == "첫 메시지입니다")
            }
        }

        // When
        await store.send(.sendButtonTapped) {
            $0.isSending = true
            $0.inputText = ""
        }

        // Then
        await store.receive(\.messageSent) {
            $0.isSending = false
        }
    }

    // MARK: - Load More Messages Tests (Pagination)

    @Test
    func test_loadMoreMessages_fetchesOlderMessages() async {
        // Given
        let existingMessages = TestData.messages  // sorted by index ascending: [1, 2, 3]
        let olderMessages = TestData.olderMessages  // indices: [-2, -1]

        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = existingMessages

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.fetchMessages = { chatRoomId, beforeIndex, limit in
                #expect(chatRoomId == "chatroom-1")
                // 가장 오래된 메시지(index가 작은)의 index보다 작은 메시지를 가져옴
                #expect(beforeIndex == existingMessages.first?.index)
                #expect(limit == 30)
                return olderMessages
            }
        }

        // When
        await store.send(.loadMoreMessages) {
            $0.isLoadingMore = true
        }

        // Then
        await store.receive(\.moreMessagesLoaded) {
            $0.isLoadingMore = false
            // 이전 메시지가 앞에 추가됨
            $0.messages = olderMessages + existingMessages
            $0.hasMoreMessages = !olderMessages.isEmpty
        }
    }

    @Test
    func test_loadMoreMessages_withNoMoreMessages_setsHasMoreMessagesFalse() async {
        // Given
        let existingMessages = TestData.messages

        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = existingMessages

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.fetchMessages = { _, _, _ in
                return [] // 더 이상 메시지 없음
            }
        }

        // When
        await store.send(.loadMoreMessages) {
            $0.isLoadingMore = true
        }

        // Then
        await store.receive(\.moreMessagesLoaded) {
            $0.isLoadingMore = false
            $0.hasMoreMessages = false
        }
    }

    @Test
    func test_loadMoreMessages_whenAlreadyLoading_doesNothing() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.isLoadingMore = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then - should not change state
        await store.send(.loadMoreMessages)
    }

    @Test
    func test_loadMoreMessages_whenNoMoreMessages_doesNothing() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.hasMoreMessages = false

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then
        await store.send(.loadMoreMessages)
    }

    // MARK: - Message Update Tests

    @Test
    func test_messagesUpdated_sortsMessagesByIndex() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        let unsortedMessages = [
            TestData.message3,  // index: 3
            TestData.message1,  // index: 1
            TestData.message2   // index: 2
        ]

        let sortedMessages = [
            TestData.message1,
            TestData.message2,
            TestData.message3
        ]

        // When
        await store.send(.messagesUpdated(unsortedMessages)) {
            // Then - messages should be sorted by index (ascending for display)
            $0.messages = sortedMessages
            $0.isLoading = false
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func test_messagesLoadFailed_setsError() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.messagesLoadFailed(TestError.networkError)) {
            // Then
            $0.isLoading = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - canSendMessage Computed Property Tests

    @Test
    func test_canSendMessage_returnsTrueWhenTextNotEmpty() {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "Hello"
        state.isSending = false

        // When & Then
        #expect(state.canSendMessage == true)
    }

    @Test
    func test_canSendMessage_returnsFalseWhenSending() {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "Hello"
        state.isSending = true

        // When & Then
        #expect(state.canSendMessage == false)
    }

    @Test
    func test_canSendMessage_returnsFalseWhenTextEmpty() {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = ""
        state.isSending = false

        // When & Then
        #expect(state.canSendMessage == false)
    }

    // MARK: - System Message Tests

    @Test
    func test_messagesUpdated_includesSystemMessages() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        let messagesWithSystem = [
            TestData.message1,
            TestData.systemMessage,
            TestData.message2
        ]

        // When
        await store.send(.messagesUpdated(messagesWithSystem)) {
            // Then
            $0.messages = messagesWithSystem.sorted { $0.index < $1.index }
            $0.isLoading = false
        }
    }

    // MARK: - Group Chat Tests

    @Test
    func test_isGroupChat_returnsTrueForGroupType() {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )

        // Then
        #expect(state.isGroupChat == true)
    }

    @Test
    func test_isGroupChat_returnsFalseForDirectType() {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "D_user1_user2",
            currentUserId: "current-user-123",
            chatRoomType: .direct
        )

        // Then
        #expect(state.isGroupChat == false)
    }

    @Test
    func test_invitableFriends_filtersActiveUsers() {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group,
            activeUserIds: ["current-user-123", "friend-1", "friend-2"],
            allFriends: TestData.allFriends
        )

        // Then - friend-1 and friend-2 are already in chat room
        let invitableFriends = state.invitableFriends
        #expect(invitableFriends.contains { $0.id == "friend-1" } == false)
        #expect(invitableFriends.contains { $0.id == "friend-2" } == false)
        #expect(invitableFriends.contains { $0.id == "friend-3" } == true)
        #expect(invitableFriends.contains { $0.id == "friend-4" } == true)
    }

    // MARK: - inviteFriendsButtonTapped Tests

    @Test
    func test_inviteFriendsButtonTapped_presentsSheet_forGroupChat() async {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group,
            activeUserIds: ["current-user-123", "friend-1", "friend-2"],
            allFriends: TestData.allFriends
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.inviteFriendsButtonTapped) {
            // Then
            $0.inviteFriendsDestination = InviteFriendsFeature.State(
                friends: state.invitableFriends
            )
        }
    }

    @Test
    func test_inviteFriendsButtonTapped_doesNothing_forDirectChat() async {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "D_user1_user2",
            currentUserId: "current-user-123",
            chatRoomType: .direct
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then - should not change state
        await store.send(.inviteFriendsButtonTapped)
    }

    // MARK: - inviteFriendsDestination Tests

    @Test
    func test_inviteFriendsDestination_friendsInvited_invitesAndSendsSystemMessage() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group,
            activeUserIds: ["current-user-123", "friend-1", "friend-2"],
            allFriends: TestData.allFriends
        )
        state.inviteFriendsDestination = InviteFriendsFeature.State(
            friends: TestData.invitableFriends
        )

        var invitedUserIds: [String]?
        var sentSystemMessages: [String] = []

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.inviteToGroupChat = { _, userIds in
                invitedUserIds = userIds
            }
            $0.chatRoomRepository.sendSystemMessage = { _, message in
                sentSystemMessages.append(message)
            }
        }

        // When
        await store.send(.inviteFriendsDestination(.presented(.delegate(.friendsInvited(["friend-3", "friend-4"]))))) {
            $0.inviteFriendsDestination = nil
            $0.isInviting = true
        }

        // Then
        await store.receive(\.inviteCompleted.success) {
            $0.isInviting = false
            // 초대한 친구들이 activeUserIds에 추가됨
            $0.activeUserIds.append(contentsOf: ["friend-3", "friend-4"])
        }

        #expect(invitedUserIds?.contains("friend-3") == true)
        #expect(invitedUserIds?.contains("friend-4") == true)
        #expect(sentSystemMessages.count == 2)
    }

    @Test
    func test_inviteCompleted_failure_setsError() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )
        state.isInviting = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.inviteCompleted(.failure(TestError.networkError))) {
            // Then
            $0.isInviting = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Reinvite User Tests

    @Test
    func test_reinviteUserTapped_setsConfirmTarget() async {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.reinviteUserTapped(userId: "friend-2", nickname: "Friend Two")) {
            // Then
            $0.reinviteConfirmTarget = ReinviteTarget(userId: "friend-2", nickname: "Friend Two")
        }
    }

    @Test
    func test_reinviteConfirmDismissed_clearsTarget() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )
        state.reinviteConfirmTarget = ReinviteTarget(userId: "friend-2", nickname: "Friend Two")

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.reinviteConfirmDismissed) {
            // Then
            $0.reinviteConfirmTarget = nil
        }
    }

    @Test
    func test_reinviteConfirmed_invitesUserAndSendsSystemMessage() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )
        state.reinviteConfirmTarget = ReinviteTarget(userId: "friend-2", nickname: "Friend Two")

        var invitedUserIds: [String]?
        var sentSystemMessage: String?

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.inviteToGroupChat = { _, userIds in
                invitedUserIds = userIds
            }
            $0.chatRoomRepository.sendSystemMessage = { _, message in
                sentSystemMessage = message
            }
        }

        // When
        await store.send(.reinviteConfirmed) {
            $0.reinviteConfirmTarget = nil
            $0.isInviting = true
        }

        // Then
        await store.receive(\.reinviteCompleted.success) {
            $0.isInviting = false
            // Bug fix: 재초대한 유저가 activeUserIds에 추가됨
            $0.activeUserIds.append("friend-2")
        }

        #expect(invitedUserIds == ["friend-2"])
        #expect(sentSystemMessage == Strings.Chat.userJoinedMessage("Friend Two"))
    }

    @Test
    func test_reinviteConfirmed_withNoTarget_doesNothing() async {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When & Then - should not change state
        await store.send(.reinviteConfirmed)
    }

    @Test
    func test_reinviteCompleted_failure_setsError() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )
        state.isInviting = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        // When
        await store.send(.reinviteCompleted(.failure(TestError.networkError))) {
            // Then
            $0.isInviting = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Lazy Group Chat Creation Tests

    @Test
    func test_needsToCreateGroupChat_returnsTrueWhenPending() {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group,
            activeUserIds: ["current-user-123", "friend-1", "friend-2"],
            allFriends: TestData.allFriends,
            pendingGroupChatUserIds: ["current-user-123", "friend-1", "friend-2"]
        )

        // Then
        #expect(state.needsToCreateGroupChat == true)
    }

    @Test
    func test_needsToCreateGroupChat_returnsFalseWhenNotPending() {
        // Given
        let state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group
        )

        // Then
        #expect(state.needsToCreateGroupChat == false)
    }

    @Test
    func test_sendButtonTapped_createsGroupChatAndSendsMessage_whenPending() async {
        // Given
        var state = ChatRoomFeature.State(
            chatRoomId: "G_test123",
            currentUserId: "current-user-123",
            chatRoomType: .group,
            pendingGroupChatUserIds: ["current-user-123", "friend-1", "friend-2"]
        )
        state.inputText = "첫 메시지"

        var createdChatRoomId: String?
        var createdUserIds: [String]?
        var createdSenderId: String?
        var createdContent: String?

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.createGroupChatRoomAndSendMessage = { chatRoomId, userIds, senderId, content in
                createdChatRoomId = chatRoomId
                createdUserIds = userIds
                createdSenderId = senderId
                createdContent = content
            }
        }

        // When
        await store.send(.sendButtonTapped) {
            $0.isSending = true
            $0.inputText = ""
            $0.pendingGroupChatUserIds = nil  // Lazy 생성 완료
        }

        // Then
        await store.receive(\.messageSent) {
            $0.isSending = false
        }

        #expect(createdChatRoomId == "G_test123")
        #expect(createdUserIds?.contains("current-user-123") == true)
        #expect(createdUserIds?.contains("friend-1") == true)
        #expect(createdUserIds?.contains("friend-2") == true)
        #expect(createdSenderId == "current-user-123")
        #expect(createdContent == "첫 메시지")
    }
}
