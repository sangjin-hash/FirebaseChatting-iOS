//
//  MockChatRoomRepository.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import Foundation

enum MockChatRoomRepository {
    static func make(scenario: UITestScenario) -> ChatRoomRepository {
        switch scenario {
        case .chatRoomPagination:
            return makePagination()
        case .chatRoomSend:
            return makeSend()
        case .chatRoomGroup:
            return makeGroup()
        case .chatRoomUnreadDivider:
            return makeUnreadDivider()
        case .chatRoomMediaSend:
            return makeMediaSend()
        case .chatRoomMediaViewer:
            return makeMediaViewer()
        default:
            return makeDefault()
        }
    }

    // MARK: - Base (all closures with default no-op)

    private static func base() -> ChatRoomRepository {
        ChatRoomRepository(
            getGroupChatRoom: { _ in nil },
            getDirectChatRoom: { _, _ in nil },
            rejoinChatRoom: { _, _ in },
            loadCachedMessages: { _, _ in [] },
            observeMessages: { _ in AsyncStream { $0.finish() } },
            fetchOlderMessages: { _, _, _, _ in [] },
            fetchNewerMessages: { _, _, _ in [] },
            sendMessage: { _, _, _ in },
            createChatRoomAndSendMessage: { _, _, _, _ in },
            createGroupChatRoomAndSendMessage: { _, _, _, _ in },
            inviteToGroupChat: { _, _ in },
            sendSystemMessage: { _, _ in },
            sendSystemMessageWithLeftUser: { _, _, _, _ in },
            sendMediaMessage: { _, _, _, _ in },
            createChatRoomAndSendMediaMessage: { _, _, _, _, _ in },
            createGroupChatRoomAndSendMediaMessage: { _, _, _, _, _ in }
        )
    }

    // MARK: - Scenario 4: Pagination

    private static func makePagination() -> ChatRoomRepository {
        let cachedMessages = MockDataFactory.makeMessages(count: 30, chatRoomId: "D_current-user-123_friend-1")
        let olderMessages = MockDataFactory.makeYesterdayMessages(count: 30, chatRoomId: "D_current-user-123_friend-1")

        var repo = base()
        repo.getDirectChatRoom = { _, _ in MockDataFactory.directRoom }
        repo.loadCachedMessages = { _, _ in cachedMessages }
        repo.fetchOlderMessages = { _, _, _, _ in olderMessages }
        return repo
    }

    // MARK: - Scenario 5: Send (SharedSendState 패턴)

    private static func makeSend() -> ChatRoomRepository {
        let existingMessages = MockDataFactory.makeMessages(count: 10, chatRoomId: "D_current-user-123_friend-1")

        var repo = base()
        repo.getDirectChatRoom = { _, _ in MockDataFactory.directRoom }
        repo.loadCachedMessages = { _, _ in existingMessages }
        repo.observeMessages = { _ in
            AsyncStream<[Message]> { continuation in
                UITestTrigger.shared.messageContinuation = continuation
            }
        }
        repo.sendMessage = { chatRoomId, senderId, content in
            UITestTrigger.shared.lastSentMessage = content
            let sentMessage = Message(
                id: "\(chatRoomId)_sent_\(UUID().uuidString.prefix(8))",
                index: 11,
                senderId: senderId,
                type: .text,
                content: content,
                createdAt: Date()
            )
            UITestTrigger.shared.messageContinuation?.yield([sentMessage])
            // ChatList에도 업데이트 반영
            UITestTrigger.shared.yieldUpdatedChatList()
        }
        return repo
    }

    // MARK: - Scenario 6: Group (chatRoomId별 분기)

    private static func makeGroup() -> ChatRoomRepository {
        var repo = base()
        repo.getGroupChatRoom = { chatRoomId in
            if chatRoomId == "G_test-group-1" {
                return MockDataFactory.groupRoom
            }
            return nil  // 새로 생성되는 그룹방은 nil
        }
        repo.getDirectChatRoom = { _, _ in nil }
        repo.loadCachedMessages = { chatRoomId, _ in
            if chatRoomId == "G_test-group-1" {
                return MockDataFactory.makeMessages(count: 10, chatRoomId: "G_test-group-1")
            }
            return []
        }
        repo.observeMessages = { _ in
            AsyncStream { _ in }
        }
        repo.createGroupChatRoomAndSendMessage = { _, _, _, _ in }
        return repo
    }

    // MARK: - Scenario: Unread Divider (FetchCounter 페이지네이션)

    private final class FetchCounter: @unchecked Sendable {
        var count = 0
    }

    private static func makeUnreadDivider() -> ChatRoomRepository {
        let chatRoomId = "D_current-user-123_friend-1"
        let cachedMessages = MockDataFactory.makeMessages(count: 10, chatRoomId: chatRoomId, startIndex: 1)
        let fetchCounter = FetchCounter()

        var repo = base()
        repo.getDirectChatRoom = { _, _ in
            // cachedMessagesLoaded가 먼저 처리되도록 딜레이 (UI 테스트 안정성)
            try? await Task.sleep(for: .seconds(1))
            return MockDataFactory.directRoom
        }
        repo.loadCachedMessages = { _, _ in cachedMessages }
        repo.fetchNewerMessages = { _, _, _ in
            fetchCounter.count += 1
            switch fetchCounter.count {
            case 1:
                // 1차: 30개 반환 (index 11~40) → hasMoreNewerMessages = true
                return MockDataFactory.makeNewerMessages(count: 30, chatRoomId: chatRoomId, startIndex: 11)
            default:
                // 2차: 20개 반환 (index 41~60) → hasMoreNewerMessages = false → observer 시작
                return MockDataFactory.makeNewerMessages(count: 20, chatRoomId: chatRoomId, startIndex: 41)
            }
        }
        repo.observeMessages = { _ in
            AsyncStream { _ in }
        }
        return repo
    }

    // MARK: - Scenario 7: Media Send (SharedSendState 패턴)

    private static func makeMediaSend() -> ChatRoomRepository {
        var repo = base()
        repo.getDirectChatRoom = { _, _ in MockDataFactory.directRoom }
        repo.loadCachedMessages = { _, _ in
            MockDataFactory.makeMessages(count: 5, chatRoomId: "D_current-user-123_friend-1")
        }
        repo.observeMessages = { _ in
            AsyncStream<[Message]> { continuation in
                UITestTrigger.shared.messageContinuation = continuation
            }
        }
        repo.sendMediaMessage = { chatRoomId, senderId, type, urls in
            let message = Message(
                id: "\(chatRoomId)_media_\(UUID().uuidString.prefix(8))",
                index: 6,
                senderId: senderId,
                type: type,
                content: nil,
                mediaUrls: urls,
                createdAt: Date()
            )
            UITestTrigger.shared.messageContinuation?.yield([message])
        }
        return repo
    }

    // MARK: - Scenario 8: Media Viewer

    private static func makeMediaViewer() -> ChatRoomRepository {
        var repo = base()
        repo.getDirectChatRoom = { _, _ in MockDataFactory.directRoom }
        repo.loadCachedMessages = { _, _ in
            [MockDataFactory.imageMessage, MockDataFactory.videoMessage]
        }
        repo.observeMessages = { _ in
            AsyncStream { _ in }
        }
        return repo
    }

    // MARK: - Default

    private static func makeDefault() -> ChatRoomRepository {
        var repo = base()
        repo.getDirectChatRoom = { _, _ in MockDataFactory.directRoom }
        repo.loadCachedMessages = { _, _ in
            MockDataFactory.makeMessages(count: 10, chatRoomId: "D_current-user-123_friend-1")
        }
        return repo
    }
}
