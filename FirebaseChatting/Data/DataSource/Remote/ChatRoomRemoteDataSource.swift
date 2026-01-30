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

// MARK: - DependencyKey

extension ChatRoomRemoteDataSource: DependencyKey {
    nonisolated static let liveValue: ChatRoomRemoteDataSource = {
        let db = Firestore.firestore()

        return ChatRoomRemoteDataSource(
            getDirectChatRoom: { myUserId, otherUserId in
                let chatRoomId = ChatRoom.directChatRoomId(uid1: myUserId, uid2: otherUserId)
                let docRef = db.collection("chatRooms").document(chatRoomId)

                let snapshot = try await docRef.getDocument()

                guard snapshot.exists else {
                    return nil
                }

                return try ChatRoomResponseDTO.from(document: snapshot).toModel()
            },
            rejoinChatRoom: { chatRoomId, userId in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let userRef = db.collection("users").document(userId)
                let now = Timestamp()

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

                    guard chatRoomSnapshot.exists else {
                        let error = NSError(
                            domain: "ChatRoomRemoteDataSource",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "ChatRoom not found"]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    // 2. activeUsers에 유저 추가 (joinedAt: now)
                    transaction.updateData([
                        "activeUsers.\(userId)": now
                    ], forDocument: chatRoomRef)

                    // 3. 유저의 chatRooms 배열에 채팅방 ID 추가
                    transaction.updateData([
                        "chatRooms": FieldValue.arrayUnion([chatRoomId])
                    ], forDocument: userRef)

                    return nil
                }
            },
            observeMessages: { chatRoomId, limit in
                AsyncStream { continuation in
                    let listener = db.collection("chatRooms")
                        .document(chatRoomId)
                        .collection("messages")
                        .order(by: "index", descending: true)  // DESC: 최신 메시지부터
                        .limit(to: limit)
                        .addSnapshotListener { snapshot, error in
                            guard let documents = snapshot?.documents else {
                                return
                            }

                            let messages = documents.compactMap { doc -> Message? in
                                try? MessageResponseDTO.from(document: doc).toModel()
                            }
                            // index 오름차순 정렬 (UI 표시용: 오래된 메시지가 위)
                            let sortedMessages = messages.sorted { $0.index < $1.index }
                            continuation.yield(sortedMessages)
                        }

                    continuation.onTermination = { _ in
                        listener.remove()
                    }
                }
            },
            sendMessage: { chatRoomId, senderId, content in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let messagesRef = chatRoomRef.collection("messages")

                // 트랜잭션으로 index 증가 + 메시지 추가 + 나간 유저 자동 재입장
                _ = try await db.runTransaction { transaction, errorPointer in
                    let chatRoomSnapshot: DocumentSnapshot
                    do {
                        chatRoomSnapshot = try transaction.getDocument(chatRoomRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }

                    guard chatRoomSnapshot.exists,
                          let data = chatRoomSnapshot.data() else {
                        let error = NSError(
                            domain: "ChatRoomRemoteDataSource",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "ChatRoom not found"]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    let currentIndex = data["index"] as? Int ?? 0
                    let newIndex = currentIndex + 1
                    let now = Timestamp()

                    // userHistory에 있지만 activeUsers에 없는 유저들 찾기 (나간 유저들)
                    let userHistory = data["userHistory"] as? [String] ?? []
                    let activeUsers = data["activeUsers"] as? [String: Any] ?? [:]
                    let leftUsers = userHistory.filter { !activeUsers.keys.contains($0) }

                    // 나간 유저들을 다시 activeUsers에 추가하고 chatRooms 배열 업데이트
                    for leftUserId in leftUsers {
                        // activeUsers에 추가
                        transaction.updateData([
                            "activeUsers.\(leftUserId)": now
                        ], forDocument: chatRoomRef)

                        // 유저의 chatRooms 배열에 채팅방 ID 추가
                        let userRef = db.collection("users").document(leftUserId)
                        transaction.updateData([
                            "chatRooms": FieldValue.arrayUnion([chatRoomId])
                        ], forDocument: userRef)
                    }

                    // 새 메시지 문서 생성
                    let newMessageRef = messagesRef.document()
                    let messageData: [String: Any] = [
                        "index": newIndex,
                        "senderId": senderId,
                        "type": "text",
                        "content": content,
                        "mediaUrls": [],
                        "createdAt": now
                    ]

                    transaction.setData(messageData, forDocument: newMessageRef)

                    // chatRoom 문서 업데이트
                    transaction.updateData([
                        "index": newIndex,
                        "lastMessage": content,
                        "lastMessageAt": now
                    ], forDocument: chatRoomRef)

                    return nil
                }
            },
            createChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let messagesRef = chatRoomRef.collection("messages")
                let now = Timestamp()

                // Batch write로 채팅방 생성 + 첫 메시지 + 유저 문서 업데이트
                let batch = db.batch()

                // 1. 채팅방 문서 생성
                let chatRoomData: [String: Any] = [
                    "type": "direct",
                    "lastMessage": content,
                    "lastMessageAt": now,
                    "index": 1,
                    "userHistory": userIds,
                    "activeUsers": Dictionary(uniqueKeysWithValues: userIds.map { ($0, now) })
                ]
                batch.setData(chatRoomData, forDocument: chatRoomRef)

                // 2. 첫 메시지 생성
                let newMessageRef = messagesRef.document()
                let messageData: [String: Any] = [
                    "index": 1,
                    "senderId": senderId,
                    "type": "text",
                    "content": content,
                    "mediaUrls": [],
                    "createdAt": now
                ]
                batch.setData(messageData, forDocument: newMessageRef)

                // 3. 각 유저의 chatRooms 배열에 추가
                for userId in userIds {
                    let userRef = db.collection("users").document(userId)
                    batch.updateData([
                        "chatRooms": FieldValue.arrayUnion([chatRoomId])
                    ], forDocument: userRef)
                }

                try await batch.commit()
            },
            fetchMessages: { chatRoomId, beforeIndex, limit in
                var query = db.collection("chatRooms")
                    .document(chatRoomId)
                    .collection("messages")
                    .order(by: "index", descending: true)  // DESC: 최신 메시지부터
                    .limit(to: limit)

                if let beforeIndex = beforeIndex {
                    query = query.whereField("index", isLessThan: beforeIndex)  // 더 오래된 메시지
                }

                let snapshot = try await query.getDocuments()

                let messages = snapshot.documents.compactMap { doc -> Message? in
                    try? MessageResponseDTO.from(document: doc).toModel()
                }

                // index 오름차순 정렬 (UI 표시용)
                return messages.sorted { $0.index < $1.index }
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
