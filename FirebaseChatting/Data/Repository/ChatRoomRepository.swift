//
//  ChatRoomRepository.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

// MARK: - ChatRoomRepository

// Note: @DependencyClient 매크로 사용 시 클로저 파라미터 "uninitialized" 문제 해결
// - 해결방법: struct, liveValue, DependencyValues에 nonisolated 키워드 추가
// - 관련 링크: https://github.com/pointfreeco/swift-dependencies/discussions/404

@DependencyClient
nonisolated struct ChatRoomRepository: Sendable {
    /// 채팅방 목록 실시간 스트림 (chatRoomIds 기반)
    var observeChatRooms: @Sendable (_ chatRoomIds: [String]) -> AsyncStream<[ChatRoom]> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    /// 채팅방 나가기
    var leaveChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void
    /// 1:1 채팅방 조회 (없으면 nil)
    var getDirectChatRoom: @Sendable (_ myUserId: String, _ otherUserId: String) async throws -> ChatRoom?
}

// MARK: - Dependency Key

extension ChatRoomRepository: DependencyKey {
    nonisolated static let liveValue: ChatRoomRepository = {
        @Dependency(\.chatRoomRemoteDataSource) var dataSource

        return ChatRoomRepository(
            observeChatRooms: { chatRoomIds in
                dataSource.observeChatRooms(chatRoomIds)
            },
            leaveChatRoom: { chatRoomId, userId in
                try await dataSource.leaveChatRoom(chatRoomId, userId)
            },
            getDirectChatRoom: { myUserId, otherUserId in
                try await dataSource.getDirectChatRoom(myUserId, otherUserId)
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
