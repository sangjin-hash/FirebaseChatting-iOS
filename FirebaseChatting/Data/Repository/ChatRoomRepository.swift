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

    // MARK: - Cache Methods

    /// 캐시된 메시지 로드 (채팅방 진입 시 즉시 렌더링용)
    var loadCachedMessages: @Sendable (_ chatRoomId: String, _ limit: Int) async throws -> [Message]
    /// 메시지 실시간 관찰 + 자동 캐싱 + index 갱신
    var observeMessages: @Sendable (_ chatRoomId: String) -> AsyncStream<[Message]> = { _ in
        AsyncStream { $0.finish() }
    }
    /// 위로 스크롤 페이지네이션 (로컬 우선 → 서버 fallback → 캐싱)
    var fetchOlderMessages: @Sendable (_ chatRoomId: String, _ beforeCreatedAt: Date, _ joinedAt: Date?, _ limit: Int) async throws -> [Message]
    /// 순방향 페이지네이션 (서버 → 캐싱 + index 갱신)
    var fetchNewerMessages: @Sendable (_ chatRoomId: String, _ afterCreatedAt: Date, _ limit: Int) async throws -> [Message]

    // MARK: - Message Send Methods

    /// 메시지 전송 (기존 채팅방)
    var sendMessage: @Sendable (_ chatRoomId: String, _ senderId: String, _ content: String) async throws -> Void
    /// 채팅방 생성 + 첫 메시지 전송 (트랜잭션)
    var createChatRoomAndSendMessage: @Sendable (
        _ chatRoomId: String,
        _ userIds: [String],
        _ senderId: String,
        _ content: String
    ) async throws -> Void

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

    // MARK: - Media Message Methods

    /// 미디어 메시지 전송 (기존 채팅방)
    var sendMediaMessage: @Sendable (
        _ chatRoomId: String,
        _ senderId: String,
        _ type: MessageType,
        _ mediaUrls: [String]
    ) async throws -> Void

    /// 채팅방 생성 + 첫 미디어 메시지 전송 (1:1)
    var createChatRoomAndSendMediaMessage: @Sendable (
        _ chatRoomId: String,
        _ userIds: [String],
        _ senderId: String,
        _ type: MessageType,
        _ mediaUrls: [String]
    ) async throws -> Void

    /// 그룹 채팅방 생성 + 첫 미디어 메시지 전송
    var createGroupChatRoomAndSendMediaMessage: @Sendable (
        _ chatRoomId: String,
        _ userIds: [String],
        _ senderId: String,
        _ type: MessageType,
        _ mediaUrls: [String]
    ) async throws -> Void
}

// MARK: - Dependency Key

extension ChatRoomRepository: DependencyKey {
    nonisolated static let liveValue: ChatRoomRepository = {
        @Dependency(\.chatRoomRemoteDataSource) var remoteDataSource
        @Dependency(\.chatLocalDataSource) var localDataSource

        return ChatRoomRepository(
            getGroupChatRoom: { chatRoomId in
                try await remoteDataSource.getGroupChatRoom(chatRoomId)
            },
            getDirectChatRoom: { myUserId, otherUserId in
                try await remoteDataSource.getDirectChatRoom(myUserId, otherUserId)
            },
            rejoinChatRoom: { chatRoomId, userId in
                try await remoteDataSource.rejoinChatRoom(chatRoomId, userId)
            },
            loadCachedMessages: { chatRoomId, limit in
                try await localDataSource.fetchRecentMessages(chatRoomId, limit)
            },
            observeMessages: { chatRoomId in
                AsyncStream { continuation in
                    let task = Task {
                        let afterCreatedAt = try? await localDataSource.getLastCachedCreatedAt(chatRoomId)

                        for await messages in remoteDataSource.observeMessages(chatRoomId, afterCreatedAt, 30) {
                            if !messages.isEmpty {
                                try? await localDataSource.saveMessages(messages, chatRoomId)

                                if let maxIndex = messages.compactMap(\.index).max(),
                                   let lastCreatedAt = messages.map(\.createdAt).max() {
                                    try? await localDataSource.updateIndex(chatRoomId, maxIndex, lastCreatedAt)
                                }
                            }
                            continuation.yield(messages)
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            fetchOlderMessages: { chatRoomId, beforeCreatedAt, joinedAt, limit in
                let localMessages = try await localDataSource.fetchOlderMessages(chatRoomId, beforeCreatedAt, limit)

                if localMessages.count >= limit {
                    return localMessages
                }

                // 로컬 캐시가 부족 → joinedAt 경계까지 도달했는지 확인
                if let joinedAt = joinedAt, let oldestLocal = localMessages.first {
                    // 가장 오래된 로컬 메시지가 joinedAt 이하이면 더 이상 가져올 메시지 없음
                    if oldestLocal.createdAt <= joinedAt {
                        return localMessages
                    }
                }

                // 서버 fallback (joinedAt ~ beforeCreatedAt 사이 메시지 가져오기)
                let remoteMessages = try await remoteDataSource.fetchMessages(chatRoomId, beforeCreatedAt, false, joinedAt, limit)

                if !remoteMessages.isEmpty {
                    try? await localDataSource.saveMessages(remoteMessages, chatRoomId)
                }

                return remoteMessages
            },
            fetchNewerMessages: { chatRoomId, afterCreatedAt, limit in
                let remoteMessages = try await remoteDataSource.fetchMessages(chatRoomId, afterCreatedAt, true, nil, limit)

                if !remoteMessages.isEmpty {
                    try? await localDataSource.saveMessages(remoteMessages, chatRoomId)

                    if let maxIndex = remoteMessages.compactMap(\.index).max(),
                       let lastCreatedAt = remoteMessages.map(\.createdAt).max() {
                        try? await localDataSource.updateIndex(chatRoomId, maxIndex, lastCreatedAt)
                    }
                }

                return remoteMessages
            },
            sendMessage: { chatRoomId, senderId, content in
                try await remoteDataSource.sendMessage(chatRoomId, senderId, content)
            },
            createChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                try await remoteDataSource.createChatRoomAndSendMessage(chatRoomId, userIds, senderId, content)
            },
            createGroupChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                try await remoteDataSource.createGroupChatRoomAndSendMessage(chatRoomId, userIds, senderId, content)
            },
            inviteToGroupChat: { chatRoomId, invitedUserIds in
                try await remoteDataSource.inviteToGroupChat(chatRoomId, invitedUserIds)
            },
            sendSystemMessage: { chatRoomId, content in
                try await remoteDataSource.sendSystemMessage(chatRoomId, content)
            },
            sendSystemMessageWithLeftUser: { chatRoomId, content, leftUserId, leftUserNickname in
                try await remoteDataSource.sendSystemMessageWithLeftUser(chatRoomId, content, leftUserId, leftUserNickname)
            },
            sendMediaMessage: { chatRoomId, senderId, type, mediaUrls in
                try await remoteDataSource.sendMediaMessage(chatRoomId, senderId, type, mediaUrls)
            },
            createChatRoomAndSendMediaMessage: { chatRoomId, userIds, senderId, type, mediaUrls in
                try await remoteDataSource.createChatRoomAndSendMediaMessage(chatRoomId, userIds, senderId, type, mediaUrls)
            },
            createGroupChatRoomAndSendMediaMessage: { chatRoomId, userIds, senderId, type, mediaUrls in
                try await remoteDataSource.createGroupChatRoomAndSendMediaMessage(chatRoomId, userIds, senderId, type, mediaUrls)
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
