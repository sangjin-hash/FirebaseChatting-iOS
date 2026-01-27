//
//  ChatRoomRemoteDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import FirebaseFirestore
import ComposableArchitecture

// MARK: - ChatRoomRemoteDataSource

@DependencyClient
nonisolated struct ChatRoomRemoteDataSource: Sendable {
    /// 채팅방 목록 실시간 스트림 (chatRoomIds 기반)
    var observeChatRooms: @Sendable (_ chatRoomIds: [String]) -> AsyncStream<[ChatRoom]> = { _ in
        AsyncStream { $0.finish() }
    }
    /// 채팅방 나가기
    var leaveChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void
    /// 1:1 채팅방 조회 (없으면 nil)
    var getDirectChatRoom: @Sendable (_ myUserId: String, _ otherUserId: String) async throws -> ChatRoom?
}

// MARK: - DependencyKey

extension ChatRoomRemoteDataSource: DependencyKey {
    nonisolated static let liveValue: ChatRoomRemoteDataSource = {
        let db = Firestore.firestore()

        return ChatRoomRemoteDataSource(
            observeChatRooms: { chatRoomIds in
                AsyncStream { continuation in
                    guard !chatRoomIds.isEmpty else {
                        continuation.yield([])
                        continuation.finish()
                        return
                    }

                    var listeners: [ListenerRegistration] = []
                    var currentRooms: [String: ChatRoom] = [:]

                    for chatRoomId in chatRoomIds {
                        let listener = db.collection("chatRooms")
                            .document(chatRoomId)
                            .addSnapshotListener { snapshot, error in
                                if let snapshot = snapshot,
                                   let dto = try? ChatRoomResponseDTO.from(document: snapshot) {
                                    currentRooms[chatRoomId] = dto.toModel()
                                } else {
                                    currentRooms.removeValue(forKey: chatRoomId)
                                }

                                // lastMessageAt 기준 내림차순 정렬 후 yield
                                let sortedRooms = currentRooms.values
                                    .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
                                continuation.yield(Array(sortedRooms))
                            }
                        listeners.append(listener)
                    }

                    continuation.onTermination = { _ in
                        listeners.forEach { $0.remove() }
                    }
                }
            },
            leaveChatRoom: { chatRoomId, userId in
                let docRef = db.collection("chatRooms").document(chatRoomId)

                try await docRef.updateData([
                    "activeUsers.\(userId)": FieldValue.delete()
                ])
            },
            getDirectChatRoom: { myUserId, otherUserId in
                let chatRoomId = ChatRoom.directChatRoomId(uid1: myUserId, uid2: otherUserId)
                let docRef = db.collection("chatRooms").document(chatRoomId)

                let snapshot = try await docRef.getDocument()

                guard snapshot.exists else {
                    return nil
                }

                return try ChatRoomResponseDTO.from(document: snapshot).toModel()
            }
        )
    }()
}

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var chatRoomRemoteDataSource: ChatRoomRemoteDataSource {
        get { self[ChatRoomRemoteDataSource.self] }
        set { self[ChatRoomRemoteDataSource.self] = newValue }
    }
}
