//
//  ChatListRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
@preconcurrency import ComposableArchitecture

// MARK: - ChatListRepository

@DependencyClient
nonisolated struct ChatListRepository: Sendable {
    /// 채팅방 목록 + 안읽은 메시지 수 실시간 스트림
    var observeChatRooms: @Sendable (_ chatRoomIds: [String]) -> AsyncStream<([ChatRoom], [String: Int])> = { _ in
        AsyncStream { $0.finish() }
    }
    /// 채팅방 나가기 (서버 처리 + 로컬 캐시 정리)
    var leaveChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void
}

// MARK: - Dependency Key

extension ChatListRepository: DependencyKey {
    nonisolated static let liveValue: ChatListRepository = {
        @Dependency(\.chatListRemoteDataSource) var remoteDataSource
        @Dependency(\.chatLocalDataSource) var localDataSource

        return ChatListRepository(
            observeChatRooms: { chatRoomIds in
                AsyncStream { continuation in
                    let task = Task {
                        for await chatRooms in remoteDataSource.observeChatRooms(chatRoomIds) {
                            var unreadCounts: [String: Int] = [:]
                            for chatRoom in chatRooms {
                                let localIndex = (try? await localDataSource.getLastReadIndex(chatRoom.id)) ?? 0
                                let unread = max(0, chatRoom.index - localIndex)
                                if unread > 0 {
                                    unreadCounts[chatRoom.id] = unread
                                }
                            }
                            continuation.yield((chatRooms, unreadCounts))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            leaveChatRoom: { chatRoomId, userId in
                try await remoteDataSource.leaveChatRoom(chatRoomId, userId)
                try? await localDataSource.deleteChatRoom(chatRoomId)
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    nonisolated var chatListRepository: ChatListRepository {
        get { self[ChatListRepository.self] }
        set { self[ChatListRepository.self] = newValue }
    }
}
