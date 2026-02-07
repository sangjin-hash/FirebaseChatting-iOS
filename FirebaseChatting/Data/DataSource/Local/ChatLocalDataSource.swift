//
//  ChatLocalDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
@preconcurrency import ComposableArchitecture
import SwiftData

// MARK: - ChatLocalDataSource

@DependencyClient
nonisolated struct ChatLocalDataSource: Sendable {
    // MARK: - Message

    /// 메시지 배치 저장 (중복은 #Unique로 upsert)
    var saveMessages: @Sendable (_ messages: [Message], _ chatRoomId: String) async throws -> Void
    /// 최근 메시지 조회 (createdAt ASC 정렬로 반환)
    var fetchRecentMessages: @Sendable (_ chatRoomId: String, _ limit: Int) async throws -> [Message]
    /// 역방향 페이지네이션 (createdAt < beforeCreatedAt, ASC 정렬로 반환)
    var fetchOlderMessages: @Sendable (_ chatRoomId: String, _ beforeCreatedAt: Date, _ limit: Int) async throws -> [Message]
    // MARK: - ChatRoom Index

    /// lastReadIndex 조회 (없으면 0)
    var getLastReadIndex: @Sendable (_ chatRoomId: String) async throws -> Int
    /// lastCachedCreatedAt 조회 (없으면 nil)
    var getLastCachedCreatedAt: @Sendable (_ chatRoomId: String) async throws -> Date?
    /// lastReadIndex + lastCachedCreatedAt upsert
    var updateIndex: @Sendable (_ chatRoomId: String, _ lastReadIndex: Int, _ lastCachedCreatedAt: Date?) async throws -> Void
    /// 채팅방 관련 로컬 데이터 일괄 삭제 (메시지 + index)
    var deleteChatRoom: @Sendable (_ chatRoomId: String) async throws -> Void
}

// MARK: - DependencyKey

extension ChatLocalDataSource: DependencyKey {
    nonisolated static let liveValue: ChatLocalDataSource = {
        @Dependency(\.swiftDataClient) var swiftDataClient
        let container = try! swiftDataClient.modelContainer()

        return ChatLocalDataSource(
            saveMessages: { messages, chatRoomId in
                let context = ModelContext(container)
                for message in messages {
                    context.insert(CachedMessage(from: message, chatRoomId: chatRoomId))
                }
                try context.save()
            },
            fetchRecentMessages: { chatRoomId, limit in
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<CachedMessage>(
                    predicate: #Predicate { $0.chatRoomId == chatRoomId },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                descriptor.fetchLimit = limit
                let results = try context.fetch(descriptor)
                return results.reversed().map { $0.toMessage() }
            },
            fetchOlderMessages: { chatRoomId, beforeCreatedAt, limit in
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<CachedMessage>(
                    predicate: #Predicate {
                        $0.chatRoomId == chatRoomId && $0.createdAt < beforeCreatedAt
                    },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                descriptor.fetchLimit = limit
                let results = try context.fetch(descriptor)
                return results.reversed().map { $0.toMessage() }
            },
            getLastReadIndex: { chatRoomId in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<CachedChatRoomIndex>(
                    predicate: #Predicate { $0.chatRoomId == chatRoomId }
                )
                let results = try context.fetch(descriptor)
                return results.first?.lastReadIndex ?? 0
            },
            getLastCachedCreatedAt: { chatRoomId in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<CachedChatRoomIndex>(
                    predicate: #Predicate { $0.chatRoomId == chatRoomId }
                )
                let results = try context.fetch(descriptor)
                return results.first?.lastCachedCreatedAt
            },
            updateIndex: { chatRoomId, lastReadIndex, lastCachedCreatedAt in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<CachedChatRoomIndex>(
                    predicate: #Predicate { $0.chatRoomId == chatRoomId }
                )
                let results = try context.fetch(descriptor)

                if let existing = results.first {
                    existing.lastReadIndex = lastReadIndex
                    existing.lastCachedCreatedAt = lastCachedCreatedAt
                } else {
                    context.insert(CachedChatRoomIndex(
                        chatRoomId: chatRoomId,
                        lastReadIndex: lastReadIndex,
                        lastCachedCreatedAt: lastCachedCreatedAt
                    ))
                }
                try context.save()
            },
            deleteChatRoom: { chatRoomId in
                let context = ModelContext(container)
                try context.delete(
                    model: CachedMessage.self,
                    where: #Predicate { $0.chatRoomId == chatRoomId }
                )
                try context.delete(
                    model: CachedChatRoomIndex.self,
                    where: #Predicate { $0.chatRoomId == chatRoomId }
                )
                try context.save()
            }
        )
    }()
}

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var chatLocalDataSource: ChatLocalDataSource {
        get { self[ChatLocalDataSource.self] }
        set { self[ChatLocalDataSource.self] = newValue }
    }
}
