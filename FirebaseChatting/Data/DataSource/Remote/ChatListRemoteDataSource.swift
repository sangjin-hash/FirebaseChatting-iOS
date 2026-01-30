//
//  ChatListRemoteDataSource.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import FirebaseFirestore
import ComposableArchitecture

// MARK: - ChatListRemoteDataSource

@DependencyClient
nonisolated struct ChatListRemoteDataSource: Sendable {
    /// 채팅방 목록 실시간 스트림 (chatRoomIds 기반)
    var observeChatRooms: @Sendable (_ chatRoomIds: [String]) -> AsyncStream<[ChatRoom]> = { _ in
        AsyncStream { $0.finish() }
    }
    /// 채팅방 나가기
    var leaveChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void
}

// MARK: - DependencyKey

extension ChatListRemoteDataSource: DependencyKey {
    nonisolated static let liveValue: ChatListRemoteDataSource = {
        let db = Firestore.firestore()

        return ChatListRemoteDataSource(
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
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let userRef = db.collection("users").document(userId)

                // 트랜잭션으로 처리
                _ = try await db.runTransaction { transaction, errorPointer in
                    // 1. 채팅방 문서 조회
                    let chatRoomSnapshot: DocumentSnapshot
                    do {
                        chatRoomSnapshot = try transaction.getDocument(chatRoomRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }

                    guard chatRoomSnapshot.exists,
                          let data = chatRoomSnapshot.data(),
                          let activeUsers = data["activeUsers"] as? [String: Any] else {
                        return nil
                    }

                    // 2. activeUsers에서 유저 제거
                    var updatedActiveUsers = activeUsers
                    updatedActiveUsers.removeValue(forKey: userId)

                    // 3. 유저의 chatRooms 배열에서 채팅방 ID 제거
                    transaction.updateData([
                        "chatRooms": FieldValue.arrayRemove([chatRoomId])
                    ], forDocument: userRef)

                    // 4. activeUsers가 비어있으면 채팅방 문서 삭제, 아니면 업데이트
                    if updatedActiveUsers.isEmpty {
                        transaction.deleteDocument(chatRoomRef)
                    } else {
                        transaction.updateData([
                            "activeUsers.\(userId)": FieldValue.delete()
                        ], forDocument: chatRoomRef)
                    }

                    return nil
                }
            }
        )
    }()
}

// MARK: - DependencyValues

extension DependencyValues {
    nonisolated var chatListRemoteDataSource: ChatListRemoteDataSource {
        get { self[ChatListRemoteDataSource.self] }
        set { self[ChatListRemoteDataSource.self] = newValue }
    }
}
