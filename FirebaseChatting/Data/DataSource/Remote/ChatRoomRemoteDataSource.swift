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
    /// 채팅방 ID로 직접 조회 (없으면 nil)
    var getGroupChatRoom: @Sendable (_ chatRoomId: String) async throws -> ChatRoom?
    /// 1:1 채팅방 조회 (없으면 nil)
    var getDirectChatRoom: @Sendable (_ myUserId: String, _ otherUserId: String) async throws -> ChatRoom?
    /// 채팅방 재입장 (나갔다가 다시 들어오는 경우)
    var rejoinChatRoom: @Sendable (_ chatRoomId: String, _ userId: String) async throws -> Void

    // MARK: - Message Methods

    /// 메시지 실시간 스트림 (afterCreatedAt 이후 메시지, nil이면 최신 limit개)
    var observeMessages: @Sendable (_ chatRoomId: String, _ afterCreatedAt: Date?, _ limit: Int) -> AsyncStream<[Message]> = { _, _, _ in
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
    /// 메시지 페이지네이션 (isNewer: true → baseCreatedAt 이후, false → 이전)
    var fetchMessages: @Sendable (_ chatRoomId: String, _ baseCreatedAt: Date, _ isNewer: Bool, _ limit: Int) async throws -> [Message]

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

// MARK: - DependencyKey

extension ChatRoomRemoteDataSource: DependencyKey {
    nonisolated static let liveValue: ChatRoomRemoteDataSource = {
        let db = Firestore.firestore()

        return ChatRoomRemoteDataSource(
            getGroupChatRoom: { chatRoomId in
                let docRef = db.collection("chatRooms").document(chatRoomId)
                let snapshot = try await docRef.getDocument()

                guard snapshot.exists else {
                    return nil
                }

                return try ChatRoomResponseDTO.from(document: snapshot).toModel()
            },
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
            observeMessages: { chatRoomId, afterCreatedAt, limit in
                AsyncStream { continuation in
                    let messagesRef = db.collection("chatRooms")
                        .document(chatRoomId)
                        .collection("messages")

                    let query: Query
                    if let afterCreatedAt {
                        query = messagesRef
                            .whereField("createdAt", isGreaterThan: Timestamp(date: afterCreatedAt))
                            .order(by: "createdAt")
                    } else {
                        query = messagesRef
                            .order(by: "createdAt", descending: true)
                            .limit(to: limit)
                    }

                    let listener = query.addSnapshotListener { snapshot, error in
                        guard let documents = snapshot?.documents else {
                            return
                        }

                        let messages = documents.compactMap { doc -> Message? in
                            try? MessageResponseDTO.from(document: doc).toModel()
                        }
                        let sortedMessages = messages.sorted { $0.createdAt < $1.createdAt }
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
            fetchMessages: { chatRoomId, baseCreatedAt, isNewer, limit in
                let messagesRef = db.collection("chatRooms")
                    .document(chatRoomId)
                    .collection("messages")

                let query: Query
                if isNewer {
                    query = messagesRef
                        .whereField("createdAt", isGreaterThan: Timestamp(date: baseCreatedAt))
                        .order(by: "createdAt")
                        .limit(to: limit)
                } else {
                    query = messagesRef
                        .whereField("createdAt", isLessThan: Timestamp(date: baseCreatedAt))
                        .order(by: "createdAt", descending: true)
                        .limit(to: limit)
                }

                let snapshot = try await query.getDocuments()

                let messages = snapshot.documents.compactMap { doc -> Message? in
                    try? MessageResponseDTO.from(document: doc).toModel()
                }

                return messages.sorted { $0.createdAt < $1.createdAt }
            },
            createGroupChatRoomAndSendMessage: { chatRoomId, userIds, senderId, content in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let messagesRef = chatRoomRef.collection("messages")
                let now = Timestamp()

                // Batch write로 채팅방 생성 + 첫 메시지 + 유저 문서 업데이트
                let batch = db.batch()

                // 1. 채팅방 문서 생성
                let chatRoomData: [String: Any] = [
                    "type": "group",
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
            inviteToGroupChat: { chatRoomId, invitedUserIds in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
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

                    // 2. userHistory 업데이트
                    var userHistory = data["userHistory"] as? [String] ?? []
                    for userId in invitedUserIds {
                        if !userHistory.contains(userId) {
                            userHistory.append(userId)
                        }
                    }

                    // 3. activeUsers에 초대된 유저 추가 + userHistory 업데이트
                    var updateData: [String: Any] = ["userHistory": userHistory]
                    for userId in invitedUserIds {
                        updateData["activeUsers.\(userId)"] = now
                    }
                    transaction.updateData(updateData, forDocument: chatRoomRef)

                    // 4. 각 초대된 유저의 chatRooms 배열에 추가
                    for userId in invitedUserIds {
                        let userRef = db.collection("users").document(userId)
                        transaction.updateData([
                            "chatRooms": FieldValue.arrayUnion([chatRoomId])
                        ], forDocument: userRef)
                    }

                    return nil
                }
            },
            sendSystemMessage: { chatRoomId, content in
                let messagesRef = db.collection("chatRooms").document(chatRoomId).collection("messages")

                // 시스템 메시지 생성 (index 없음, chatRoom 업데이트 없음)
                let messageData: [String: Any] = [
                    "senderId": "system",
                    "type": "system",
                    "content": content,
                    "mediaUrls": [],
                    "createdAt": Timestamp()
                ]

                try await messagesRef.addDocument(data: messageData)
            },
            sendSystemMessageWithLeftUser: { chatRoomId, content, leftUserId, leftUserNickname in
                let messagesRef = db.collection("chatRooms").document(chatRoomId).collection("messages")

                // 시스템 메시지 생성 (index 없음, chatRoom 업데이트 없음)
                let messageData: [String: Any] = [
                    "senderId": "system",
                    "type": "system",
                    "content": content,
                    "mediaUrls": [],
                    "createdAt": Timestamp(),
                    "leftUserId": leftUserId,
                    "leftUserNickname": leftUserNickname
                ]

                try await messagesRef.addDocument(data: messageData)
            },
            sendMediaMessage: { chatRoomId, senderId, type, mediaUrls in
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
                        transaction.updateData([
                            "activeUsers.\(leftUserId)": now
                        ], forDocument: chatRoomRef)

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
                        "type": type.rawValue,
                        "content": NSNull(),
                        "mediaUrls": mediaUrls,
                        "createdAt": now
                    ]

                    transaction.setData(messageData, forDocument: newMessageRef)

                    // chatRoom 문서 업데이트 (lastMessage는 미디어 타입에 따라 표시)
                    let lastMessage = type == .image ? "사진" : "동영상"
                    transaction.updateData([
                        "index": newIndex,
                        "lastMessage": lastMessage,
                        "lastMessageAt": now
                    ], forDocument: chatRoomRef)

                    return nil
                }
            },
            createChatRoomAndSendMediaMessage: { chatRoomId, userIds, senderId, type, mediaUrls in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let messagesRef = chatRoomRef.collection("messages")
                let now = Timestamp()
                let lastMessage = type == .image ? "사진" : "동영상"

                // Batch write로 채팅방 생성 + 첫 메시지 + 유저 문서 업데이트
                let batch = db.batch()

                // 1. 채팅방 문서 생성
                let chatRoomData: [String: Any] = [
                    "type": "direct",
                    "lastMessage": lastMessage,
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
                    "type": type.rawValue,
                    "content": NSNull(),
                    "mediaUrls": mediaUrls,
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
            createGroupChatRoomAndSendMediaMessage: { chatRoomId, userIds, senderId, type, mediaUrls in
                let chatRoomRef = db.collection("chatRooms").document(chatRoomId)
                let messagesRef = chatRoomRef.collection("messages")
                let now = Timestamp()
                let lastMessage = type == .image ? "사진" : "동영상"

                // Batch write로 채팅방 생성 + 첫 메시지 + 유저 문서 업데이트
                let batch = db.batch()

                // 1. 채팅방 문서 생성
                let chatRoomData: [String: Any] = [
                    "type": "group",
                    "lastMessage": lastMessage,
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
                    "type": type.rawValue,
                    "content": NSNull(),
                    "mediaUrls": mediaUrls,
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
