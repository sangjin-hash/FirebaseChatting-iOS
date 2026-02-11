//
//  ChatRoomCreateInviteIntegrationTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

/// 3.4 ~ 3.6: 채팅방 생성 & 초대 통합 테스트
@Suite(.serialized)
@MainActor
struct ChatRoomCreateInviteIntegrationTests {

    // MARK: - 3.4 신규 1:1 채팅방: 첫 메시지 → 채팅방 생성 + 전송

    @Test
    func test_newDirectChat_createAndSendThenObserve() async {
        var createCalled = false
        var createRoomId: String?
        var createUserIds: [String]?
        var createContent: String?

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "D_current-user-123_friend-1",
                currentUserId: "current-user-123",
                otherUser: TestData.friend1Profile
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in [] }
            $0.chatRoomRepository.getDirectChatRoom = { _, _ in nil }
            $0.chatRoomRepository.createChatRoomAndSendMessage = { roomId, userIds, _, content in
                createCalled = true
                createRoomId = roomId
                createUserIds = userIds
                createContent = content
            }
            $0.chatRoomRepository.observeMessages = { _ in AsyncStream { $0.finish() } }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.cachedMessagesLoaded)
        await store.receive(\.chatRoomLoaded)
        await store.receive(\.startObserving)

        await store.send(.inputTextChanged("첫 메시지"))
        await store.send(.sendButtonTapped)

        await store.receive(\.messageSent)

        #expect(createCalled == true)
        #expect(createRoomId == "D_current-user-123_friend-1")
        #expect(createUserIds?.sorted() == ["current-user-123", "friend-1"])
        #expect(createContent == "첫 메시지")
    }

    // MARK: - 3.5 신규 그룹 채팅방 Lazy 생성

    @Test
    func test_lazyGroupChatCreation_pendingToCreated() async {
        let pendingUserIds = ["current-user-123", "friend-1", "friend-2"]

        var createGroupChatCalled = false
        var sentUserIds: [String]?
        var sentContent: String?

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "G_newgroup123",
                currentUserId: "current-user-123",
                chatRoomType: .group,
                activeUserIds: pendingUserIds,
                pendingGroupChatUserIds: pendingUserIds
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.loadCachedMessages = { _, _ in [] }
            $0.chatRoomRepository.getGroupChatRoom = { _ in nil }
            $0.chatRoomRepository.createGroupChatRoomAndSendMessage = { _, userIds, _, content in
                createGroupChatCalled = true
                sentUserIds = userIds
                sentContent = content
            }
            $0.chatRoomRepository.observeMessages = { _ in AsyncStream { $0.finish() } }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.cachedMessagesLoaded)
        await store.receive(\.chatRoomLoaded)
        await store.receive(\.startObserving)

        await store.send(.inputTextChanged("그룹 첫 메시지"))
        await store.send(.sendButtonTapped)

        #expect(store.state.pendingGroupChatUserIds == nil)

        await store.receive(\.messageSent)

        #expect(createGroupChatCalled == true)
        #expect(sentUserIds == pendingUserIds)
        #expect(sentContent == "그룹 첫 메시지")
    }

    // MARK: - 3.6 그룹 친구 초대: Drawer → InviteFriends → invite API + 시스템 메시지

    @Test
    func test_groupInvite_drawerToInviteFriendsToApiCalls() async {
        let activeUserIds = ["current-user-123", "friend-1", "friend-2"]

        var invitedUserIds: [String]?
        var systemMessageCount = 0
        var systemMessages: [String] = []

        let store = TestStore(
            initialState: ChatRoomFeature.State(
                chatRoomId: "G_group123",
                currentUserId: "current-user-123",
                chatRoomType: .group,
                activeUserIds: activeUserIds,
                allFriends: TestData.allFriends
            )
        ) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.inviteToGroupChat = { _, userIds in
                invitedUserIds = userIds
            }
            $0.chatRoomRepository.sendSystemMessage = { _, content in
                systemMessageCount += 1
                systemMessages.append(content)
            }
        }

        let expectedInvitableFriends = TestData.allFriends.filter { !activeUserIds.contains($0.id) }

        await store.send(.drawer(.delegate(.inviteTapped))) {
            $0.inviteFriendsDestination = InviteFriendsFeature.State(
                friends: expectedInvitableFriends
            )
        }

        await store.send(.inviteFriendsDestination(.presented(
            .delegate(.friendsInvited(["friend-3", "friend-4"]))
        ))) {
            $0.inviteFriendsDestination = nil
            $0.isInviting = true
        }

        await store.receive(\.inviteCompleted) {
            $0.isInviting = false
            $0.activeUserIds.append(contentsOf: ["friend-3", "friend-4"])
        }

        #expect(invitedUserIds == ["friend-3", "friend-4"])
        #expect(systemMessageCount == 2)
        #expect(systemMessages.contains(Strings.Chat.userJoinedMessage("Friend Three")))
        #expect(systemMessages.contains(Strings.Chat.userJoinedMessage("Friend Four")))
        #expect(store.state.activeUserIds.count == 5)
    }
}
