//
//  ChatRoomRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

// MARK: - ChatRoomRepository

@DependencyClient
nonisolated struct ChatRoomRepository: Sendable {
    /// 채팅방 ID로 직접 조회 (없으면 nil)
    var getGroupChatRoom: @Sendable (_ chatRoomId: String) async throws -> ChatRoom?
    /// 1:1 채팅방 조회 (없으면 nil)
    var getDirectChatRoom: @Sendable (_ myUserId: String, _ otherUserId: String) async throws -> ChatRoom?
    /// 채팅방 재입장 (나갔다가 다시 들어오는 경우)
    var rejoinChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void

    // MARK: - Message Methods

    /// 메시지 실시간 스트림 (최신 메시지 limit개)
    var observeMessages: @Sendable (_ chatRoomId: String, _ limit: Int) -> AsyncStream<[Message]> = { _, _ in
        AsyncStream { $0.finish() }
    }
    /// 메시지 전송 (기존 채팅방)
    var sendMessage: @Sendable (_ chatRoomId: String, _ senderId: String, _ content: String) async throws -> Void
    /// 채팅방 생성 + 첫 메시지 전송 (트랜잭션)
    var createChatRoomAndSendMessage: @Sendable (
        _ chatRoomId: String,
        _ userIds: [String],
        _ senderId: String,
        _ content: String
    ) async throws -> Void
    /// 이전 메시지 로드 (페이지네이션)
    var fetchMessages: @Sendable (_ chatRoomId: String, _ beforeCreatedAt: Date?, _ limit: Int) async throws -> [Message]

    // MARK: - Group Chat Methods

    /// 그룹 채팅방 생성 + 첫 메시지 전송 (Lazy 생성)
    var createGroupChatRoomAndSendMessage: @Sendable (
        _ chatRoomId: String,
        _ userIds: [String],
        _ senderId: String,
        _ content: String
    ) async throws -> Void
    /// 그룹 채팅방에 친구 초대
    var inviteToGroupChat: @Sendable (_ chatRoomId: String, _ invitedUserIds: [String]) async throws -> Void
    /// 시스템 메시지 전송 (일반)
    var sendSystemMessage: @Sendable (_ chatRoomId: String, _ content: String) async throws -> Void
    /// 시스템 메시지 전송 (나간 사용자 정보 포함)
    var sendSystemMessageWithLeftUser: @Sendable (
        _ chatRoomId: String,
        _ content: String,
        _ leftUserId: String,
        _ leftUserNickname: String
    ) async throws -> Void
}

// MARK: - Dependency Key

extension ChatRoomRepository: DependencyKey {
    nonisolated static let testValue = ChatRoomRepository()

    nonisolated static let liveValue: ChatRoomRepository = {
        @Dependency(\.chatRoomRemoteDataSource) var dataSource

        return ChatRoomRepository(
            getGroupChatRoom: { chatRoomId in
                try await dataSource.getGroupChatRoom(chatRoomId)
            },
            getDirectChatRoom: { myUserId, otherUserId in
                try await dataSource.getDirectChatRoom(myUserId, otherUserId)
            },
            rejoinChatRoom: { chatRoomId, userId in
                try await dataSource.rejoinChatRoom(chatRoomId, userId)
            },
            observeMessages: { chatRoomId, limit in
                dataSource.observeMessages(chatRoomId, limit)
            },
            sendMessage: { chatRoomId, senderId, content in
                try await dataSource.sendMessage(chatRoomId, senderId, content)
            },
            createChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                try await dataSource.createChatRoomAndSendMessage(chatRoomId, userIds, senderId, content)
            },
            fetchMessages: { chatRoomId, beforeCreatedAt, limit in
                try await dataSource.fetchMessages(chatRoomId, beforeCreatedAt, limit)
            },
            createGroupChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                try await dataSource.createGroupChatRoomAndSendMessage(chatRoomId, userIds, senderId, content)
            },
            inviteToGroupChat: { chatRoomId, invitedUserIds in
                try await dataSource.inviteToGroupChat(chatRoomId, invitedUserIds)
            },
            sendSystemMessage: { chatRoomId, content in
                try await dataSource.sendSystemMessage(chatRoomId, content)
            },
            sendSystemMessageWithLeftUser: { chatRoomId, content, leftUserId, leftUserNickname in
                try await dataSource.sendSystemMessageWithLeftUser(chatRoomId, content, leftUserId, leftUserNickname)
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    nonisolated var chatRoomRepository: ChatRoomRepository {
        get { self[ChatRoomRepository.self] }
        set { self[ChatRoomRepository.self] = newValue }
    }
}
