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
    var fetchMessages: @Sendable (_ chatRoomId: String, _ beforeIndex: Int?, _ limit: Int) async throws -> [Message]
}

// MARK: - Dependency Key

extension ChatRoomRepository: DependencyKey {
    nonisolated static let liveValue: ChatRoomRepository = {
        @Dependency(\.chatRoomRemoteDataSource) var dataSource

        return ChatRoomRepository(
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
            fetchMessages: { chatRoomId, beforeIndex, limit in
                try await dataSource.fetchMessages(chatRoomId, beforeIndex, limit)
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
