//
//  ChatListRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

// MARK: - ChatListRepository

@DependencyClient
nonisolated struct ChatListRepository: Sendable {
    /// 채팅방 목록 실시간 스트림 (chatRoomIds 기반)
    var observeChatRooms: @Sendable (_ chatRoomIds: [String]) -> AsyncStream<[ChatRoom]> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    /// 채팅방 나가기
    var leaveChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void
}

// MARK: - Dependency Key

extension ChatListRepository: DependencyKey {
    nonisolated static let liveValue: ChatListRepository = {
        @Dependency(\.chatListRemoteDataSource) var dataSource

        return ChatListRepository(
            observeChatRooms: { chatRoomIds in
                dataSource.observeChatRooms(chatRoomIds)
            },
            leaveChatRoom: { chatRoomId, userId in
                try await dataSource.leaveChatRoom(chatRoomId, userId)
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
