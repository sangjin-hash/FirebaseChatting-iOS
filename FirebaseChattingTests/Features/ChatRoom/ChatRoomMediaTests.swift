//
//  ChatRoomMediaTests.swift
//  FirebaseChattingTests
//
//  Created by Claude Code
//

import Foundation
import Testing
import ComposableArchitecture
@testable import FirebaseChatting

@MainActor
struct ChatRoomMediaTests {

    // MARK: - Media Picker Tests (MediaUploadFeature)

    @Test
    func test_mediaButtonTapped_presentsMediaPicker() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.mediaButtonTapped)) {
            $0.mediaUpload.isMediaPickerPresented = true
        }
    }

    @Test
    func test_setMediaPickerPresented_false_dismissesPicker() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.isMediaPickerPresented = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.setMediaPickerPresented(false))) {
            $0.mediaUpload.isMediaPickerPresented = false
        }
    }

    // MARK: - Media Selection Tests (MediaUploadFeature)

    @Test
    func test_mediaSelected_addsToSelectedItems() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        let mediaItems = [TestData.imageMediaItem1, TestData.imageMediaItem2]

        await store.send(.mediaUpload(.mediaSelected(mediaItems))) {
            $0.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)
            $0.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem2)
        }
    }

    @Test
    func test_removeSelectedMedia_removesItem() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem2)

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.removeSelectedMedia("media-1"))) {
            $0.mediaUpload.selectedMediaItems.remove(id: "media-1")
        }
    }

    @Test
    func test_clearSelectedMedia_removesAllItems() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem2)

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.clearSelectedMedia)) {
            $0.mediaUpload.selectedMediaItems.removeAll()
        }
    }

    @Test
    func test_fileSizeExceeded_setsError() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.fileSizeExceeded("large_video.mp4"))) {
            $0.mediaUpload.fileSizeExceededFileName = "large_video.mp4"
        }
    }

    // MARK: - Upload Tests

    @Test
    func test_sendMediaButtonTapped_withNoMedia_doesNothing() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaUpload(.sendMediaButtonTapped))
    }

    @Test
    func test_uploadProgress_updatesProgress() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.uploadingItems = [
            UploadingMediaItem(
                id: "media-1",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 0,
                isCompleted: false
            )
        ]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.uploadProgress(itemId: "media-1", progress: 0.5)) {
            $0.mediaUpload.uploadingItems[id: "media-1"]?.progress = 0.5
        }
    }

    @Test
    func test_uploadCompleted_updatesState() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.uploadingItems = [
            UploadingMediaItem(
                id: "media-1",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 0.9,
                isCompleted: false
            )
        ]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.uploadCompleted(itemId: "media-1", downloadURL: "https://example.com/image1.jpg")) {
            $0.mediaUpload.uploadingItems[id: "media-1"]?.isCompleted = true
            $0.mediaUpload.uploadingItems[id: "media-1"]?.downloadURL = "https://example.com/image1.jpg"
        }
    }

    @Test
    func test_uploadFailed_setsError() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.isUploading = true
        state.mediaUpload.uploadingItems = [
            UploadingMediaItem(
                id: "media-1",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 0.5,
                isCompleted: false
            )
        ]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.uploadFailed(itemId: "media-1", TestError.networkError)) {
            $0.mediaUpload.uploadingItems[id: "media-1"]?.error = TestError.networkError.localizedDescription
            $0.mediaUpload.isUploading = false
            $0.error = "업로드 실패: \(TestError.networkError.localizedDescription)"
        }
    }

    // MARK: - Media Message Separation Tests

    @Test
    func test_allUploadsCompleted_separatesImagesAndVideos() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = [TestData.message1]  // 기존 채팅방 시뮬레이션
        state.mediaUpload.isUploading = true
        state.mediaUpload.uploadingItems = [
            UploadingMediaItem(
                id: "media-1",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/image1.jpg"
            ),
            UploadingMediaItem(
                id: "media-2",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/image2.jpg"
            ),
            UploadingMediaItem(
                id: "media-3",
                type: .video,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/video1.mp4"
            )
        ]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMediaMessage = { _, _, type, urls in
                // 호출만 추적
            }
        }

        await store.send(.allUploadsCompleted) {
            $0.mediaUpload.uploadingItems.removeAll()
        }

        // 이미지 1개 메시지 (2장) + 동영상 1개 메시지로 분리
        let expectedPayloads = [
            MediaMessagePayload(type: .image, urls: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]),
            MediaMessagePayload(type: .video, urls: ["https://example.com/video1.mp4"])
        ]
        await store.receive(.sendMediaMessages(expectedPayloads))

        // exhaustivity off로 UUID 변경 무시
        store.exhaustivity = .off
        await store.receive(.mediaMessageSent(.success(()))) {
            $0.mediaUpload.isUploading = false
        }
    }

    @Test
    func test_mixedMedia_separatesIntoMultipleMessages() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = [TestData.message1]  // 기존 채팅방 시뮬레이션
        state.mediaUpload.isUploading = true
        state.mediaUpload.uploadingItems = [
            UploadingMediaItem(
                id: "media-1",
                type: .image,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/image1.jpg"
            ),
            UploadingMediaItem(
                id: "media-2",
                type: .video,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/video1.mp4"
            ),
            UploadingMediaItem(
                id: "media-3",
                type: .video,
                thumbnail: nil,
                originalData: nil,
                mimeType: nil,
                progress: 1.0,
                isCompleted: true,
                downloadURL: "https://example.com/video2.mp4"
            )
        ]

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMediaMessage = { _, _, _, _ in
                // 호출만 추적
            }
        }

        await store.send(.allUploadsCompleted) {
            $0.mediaUpload.uploadingItems.removeAll()
        }

        // 이미지 1개 메시지 + 동영상 2개 메시지 = 총 3개 메시지 payload
        let expectedPayloads = [
            MediaMessagePayload(type: .image, urls: ["https://example.com/image1.jpg"]),
            MediaMessagePayload(type: .video, urls: ["https://example.com/video1.mp4"]),
            MediaMessagePayload(type: .video, urls: ["https://example.com/video2.mp4"])
        ]
        await store.receive(.sendMediaMessages(expectedPayloads))

        // exhaustivity off로 UUID 변경 무시
        store.exhaustivity = .off
        await store.receive(.mediaMessageSent(.success(()))) {
            $0.mediaUpload.isUploading = false
        }
    }

    // MARK: - Send Media Message Tests

    @Test
    func test_sendMediaMessages_sendsMediaToExistingChatRoom() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = [TestData.message1]
        state.mediaUpload.isUploading = true

        var sentMediaTypes: [MessageType] = []
        var sentMediaUrls: [[String]] = []

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMediaMessage = { _, _, type, urls in
                sentMediaTypes.append(type)
                sentMediaUrls.append(urls)
            }
        }

        let payloads = [
            MediaMessagePayload(type: .image, urls: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]),
            MediaMessagePayload(type: .video, urls: ["https://example.com/video1.mp4"])
        ]

        await store.send(.sendMediaMessages(payloads))

        // exhaustivity off로 UUID 변경 무시
        store.exhaustivity = .off
        await store.receive(.mediaMessageSent(.success(()))) {
            $0.mediaUpload.isUploading = false
        }

        #expect(sentMediaTypes.count == 2)
        #expect(sentMediaTypes[0] == .image)
        #expect(sentMediaTypes[1] == .video)
        #expect(sentMediaUrls[0] == ["https://example.com/image1.jpg", "https://example.com/image2.jpg"])
        #expect(sentMediaUrls[1] == ["https://example.com/video1.mp4"])
    }

    @Test
    func test_sendMediaMessages_failure_setsError() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.messages = [TestData.message1]
        state.mediaUpload.isUploading = true

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        } withDependencies: {
            $0.chatRoomRepository.sendMediaMessage = { _, _, _, _ in
                throw TestError.networkError
            }
        }

        let payloads = [
            MediaMessagePayload(type: .image, urls: ["https://example.com/image1.jpg"])
        ]

        await store.send(.sendMediaMessages(payloads))

        await store.receive(.mediaMessageSent(.failure(TestError.networkError))) {
            $0.mediaUpload.isUploading = false
            $0.error = TestError.networkError.localizedDescription
        }
    }

    // MARK: - Image Viewer Tests (MediaViewerFeature)

    @Test
    func test_imageTapped_presentsFullScreenViewer() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        let imageURLs = ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]

        await store.send(.mediaViewer(.imageTapped(imageURLs: imageURLs, index: 1))) {
            $0.mediaViewer.fullScreenImageViewerState = FullScreenImageViewerState(
                imageURLs: imageURLs,
                currentIndex: 1
            )
        }
    }

    @Test
    func test_dismissImageViewer_closesViewer() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaViewer.fullScreenImageViewerState = FullScreenImageViewerState(
            imageURLs: ["https://example.com/image1.jpg"],
            currentIndex: 0
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaViewer(.dismissImageViewer)) {
            $0.mediaViewer.fullScreenImageViewerState = nil
        }
    }

    @Test
    func test_imageViewerIndexChanged_updatesIndex() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaViewer.fullScreenImageViewerState = FullScreenImageViewerState(
            imageURLs: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
            currentIndex: 0
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaViewer(.imageViewerIndexChanged(1))) {
            $0.mediaViewer.fullScreenImageViewerState?.currentIndex = 1
        }
    }

    // MARK: - Video Player Tests (MediaViewerFeature)

    @Test
    func test_videoTapped_presentsVideoPlayer() async {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        let videoURL = URL(string: "https://example.com/video1.mp4")!

        await store.send(.mediaViewer(.videoTapped(videoURL))) {
            $0.mediaViewer.videoPlayerURL = videoURL
        }
    }

    @Test
    func test_dismissVideoPlayer_closesPlayer() async {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaViewer.videoPlayerURL = URL(string: "https://example.com/video1.mp4")

        let store = TestStore(initialState: state) {
            ChatRoomFeature()
        }

        await store.send(.mediaViewer(.dismissVideoPlayer)) {
            $0.mediaViewer.videoPlayerURL = nil
        }
    }

    // MARK: - Computed Properties Tests

    @Test
    func test_hasSelectedMedia_returnsTrueWhenMediaSelected() {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)

        #expect(state.mediaUpload.hasSelectedMedia == true)
    }

    @Test
    func test_hasSelectedMedia_returnsFalseWhenEmpty() {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        #expect(state.mediaUpload.hasSelectedMedia == false)
    }

    @Test
    func test_remainingMediaCount_calculatesCorrectly() {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem2)

        // 최대 10개 중 2개 선택 -> 8개 남음
        #expect(state.mediaUpload.remainingMediaCount == 8)
    }

    @Test
    func test_canSendAny_returnsTrueWithText() {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.inputText = "Hello"

        #expect(state.canSendAny == true)
    }

    @Test
    func test_canSendAny_returnsTrueWithMedia() {
        var state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )
        state.mediaUpload.selectedMediaItems.append(TestData.imageMediaItem1)

        #expect(state.canSendAny == true)
    }

    @Test
    func test_canSendAny_returnsFalseWhenEmpty() {
        let state = ChatRoomFeature.State(
            chatRoomId: "chatroom-1",
            currentUserId: "current-user-123"
        )

        #expect(state.canSendAny == false)
    }
}
