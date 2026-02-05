//
//  ChatRoomView.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import AVKit
import PhotosUI
import SwiftUI
import ComposableArchitecture

struct ChatRoomView: View {
    @Bindable var store: StoreOf<ChatRoomFeature>
    @State private var selectedPhotosItems: [PhotosPickerItem] = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var initialScrollDone = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                messageList
                messageInput
            }

            // ChatRoomDrawer (그룹 채팅일 때만)
            if store.isGroupChat {
                ChatRoomDrawer(store: store)
            }
        }
        .navigationTitle(store.otherUser?.nickname ?? Strings.Common.noName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if store.isGroupChat {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.drawerButtonTapped)
                    } label: {
                        if store.isInviting {
                            ProgressView()
                        } else {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
            }
        }
        .sheet(item: $store.scope(state: \.inviteFriendsDestination, action: \.inviteFriendsDestination)) { inviteFriendsStore in
            InviteFriendsView(store: inviteFriendsStore)
        }
        .confirmDialog(
            isPresented: Binding(
                get: { store.reinviteConfirmTarget != nil },
                set: { if !$0 { store.send(.reinviteConfirmDismissed) } }
            ),
            message: store.reinviteConfirmTarget.map { Strings.Chat.reinviteConfirmMessage($0.nickname) } ?? "",
            onConfirm: {
                store.send(.reinviteConfirmed)
            }
        )
        .overlay {
            uploadProgressOverlay
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.fullScreenImageViewerState != nil },
                set: { if !$0 { store.send(.dismissImageViewer) } }
            )
        ) {
            if let viewerState = store.fullScreenImageViewerState {
                FullScreenImageViewer(
                    imageURLs: viewerState.imageURLs,
                    currentIndex: Binding(
                        get: { viewerState.currentIndex },
                        set: { store.send(.imageViewerIndexChanged($0)) }
                    )
                ) {
                    store.send(.dismissImageViewer)
                }
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { store.videoPlayerURL != nil },
                set: { if !$0 { store.send(.dismissVideoPlayer) } }
            )
        ) {
            if let url = store.videoPlayerURL {
                VideoPlayerView(url: url) {
                    store.send(.dismissVideoPlayer)
                }
            }
        }
        .alert(
            Strings.Chat.fileSizeExceededTitle,
            isPresented: Binding(
                get: { store.fileSizeExceededFileName != nil },
                set: { if !$0 { store.send(.dismissFileSizeError) } }
            )
        ) {
            Button(Strings.Common.confirm) {
                store.send(.dismissFileSizeError)
            }
        } message: {
            if let fileName = store.fileSizeExceededFileName {
                Text(Strings.Chat.fileSizeExceededMessage(fileName))
            }
        }
        .alert(
            Strings.Chat.uploadFailedTitle,
            isPresented: Binding(
                get: { store.deleteConfirmationItemId != nil },
                set: { if !$0 { store.send(.dismissDeleteConfirmation) } }
            )
        ) {
            Button(Strings.Chat.delete, role: .destructive) {
                if let itemId = store.deleteConfirmationItemId {
                    store.send(.deleteFailedUpload(itemId: itemId))
                }
            }
            Button(Strings.Common.cancel, role: .cancel) {
                store.send(.dismissDeleteConfirmation)
            }
        } message: {
            Text(Strings.Chat.uploadFailedDeleteMessage)
        }
    }
}

// MARK: - Message List

private extension ChatRoomView {
    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.hasMoreMessages && !store.filteredMessages.isEmpty {
                        loadMoreTrigger
                    }

                    ForEach(groupedMessages, id: \.date) { group in
                        DateSeparator(formattedDate: formatDate(group.date))

                        ForEach(group.messages) { message in
                            messageRow(message: message)
                                .id(message.id)
                        }
                    }

                    if !store.uploadingItems.isEmpty {
                        UploadingMediaGrid(
                            items: Array(store.uploadingItems),
                            onRetry: { store.send(.retryUpload(itemId: $0)) },
                            onDelete: { store.send(.showDeleteConfirmation(itemId: $0)) }
                        )
                        .id("uploading-grid")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: store.filteredMessages.count) { oldCount, newCount in
                if oldCount == 0 && newCount > 0, !initialScrollDone {
                    initialScrollDone = true
                    if let lastId = store.filteredMessages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.filteredMessages.last?.id) { oldValue, newValue in
                if let id = newValue, oldValue != nil {
                    Task {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.uploadingItems.isEmpty) { wasEmpty, isEmpty in
                if wasEmpty && !isEmpty {
                    Task {
                        proxy.scrollTo("uploading-grid", anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.scrollToBottomTrigger) { _, newValue in
                if newValue != nil {
                    for delay in [0.3, 0.6, 1.0] {
                        Task {
                            try? await Task.sleep(for: .seconds(delay))
                            if let lastId = store.filteredMessages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if store.isLoading && store.filteredMessages.isEmpty {
                ProgressView()
            }
        }
    }

    var loadMoreTrigger: some View {
        Group {
            if store.isLoadingMore {
                ProgressView()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        store.send(.loadMoreMessages)
                    }
            }
        }
    }

    @ViewBuilder
    func messageRow(message: Message) -> some View {
        if message.isSystemMessage {
            SystemMessageBubble(message: message) { userId, nickname in
                store.send(.reinviteUserTapped(userId: userId, nickname: nickname))
            }
        } else if message.isMine(myUserId: store.currentUserId) {
            MyMessageBubble(
                message: message,
                formattedTime: formatTime(message.createdAt),
                onImageTapped: { urls, index in
                    store.send(.imageTapped(imageURLs: urls, index: index))
                },
                onVideoTapped: { url in
                    store.send(.videoTapped(url))
                }
            )
        } else {
            OtherMessageBubble(
                message: message,
                formattedTime: formatTime(message.createdAt),
                onImageTapped: { urls, index in
                    store.send(.imageTapped(imageURLs: urls, index: index))
                },
                onVideoTapped: { url in
                    store.send(.videoTapped(url))
                }
            )
        }
    }
}

// MARK: - Message Input

private extension ChatRoomView {
    var messageInput: some View {
        VStack(spacing: 0) {
            if !store.selectedMediaItems.isEmpty {
                selectedMediaPreview
            }

            HStack(spacing: 8) {
                Button {
                    store.send(.mediaButtonTapped)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(store.isUploading ? .gray : .blue)
                }
                .disabled(store.isUploading)

                TextField(
                    store.hasSelectedMedia ? Strings.Chat.mediaSelectedCount(store.selectedMediaItems.count) : Strings.Chat.messageInputPlaceholder,
                    text: $store.inputText.sending(\.inputTextChanged)
                )
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if store.hasSelectedMedia {
                        store.send(.sendMediaButtonTapped)
                    } else {
                        store.send(.sendButtonTapped)
                    }
                }
                .disabled(store.hasSelectedMedia)

                Button {
                    if store.hasSelectedMedia {
                        store.send(.sendMediaButtonTapped)
                    } else {
                        store.send(.sendButtonTapped)
                    }
                } label: {
                    if store.isUploading {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(store.canSendAny ? Color.blue : Color.blue.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .disabled(!store.canSendAny || store.isUploading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .photosPicker(
            isPresented: $store.isMediaPickerPresented.sending(\.setMediaPickerPresented),
            selection: $selectedPhotosItems,
            maxSelectionCount: store.remainingMediaCount,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotosItems) { _, newItems in
            Task {
                await loadSelectedMedia(from: newItems)
            }
        }
    }

    var selectedMediaPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.selectedMediaItems) { item in
                    ZStack(alignment: .topTrailing) {
                        if item.type == .image, let uiImage = UIImage(data: item.data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let thumbnail = item.thumbnail, let uiImage = UIImage(data: thumbnail) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                        .shadow(radius: 2)
                                }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.white)
                                }
                        }

                        Button {
                            store.send(.removeSelectedMedia(item.id))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 76)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    var uploadProgressOverlay: some View {
        EmptyView()
    }
}

// MARK: - Media Loading

private extension ChatRoomView {
    func loadSelectedMedia(from items: [PhotosPickerItem]) async {
        var selectedItems: [SelectedMediaItem] = []

        for item in items {
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })

            if isVideo {
                if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                    let data = movie.data

                    if data.count > store.maxFileSizeBytes {
                        await MainActor.run {
                            store.send(.fileSizeExceeded(item.itemIdentifier ?? "동영상"))
                        }
                        continue
                    }

                    var thumbnail: Data?
                    if let tempURL = movie.url {
                        thumbnail = try? await generateThumbnail(from: tempURL)
                    }

                    let selectedItem = SelectedMediaItem(
                        id: UUID().uuidString,
                        type: .video,
                        data: data,
                        thumbnail: thumbnail,
                        fileName: "\(UUID().uuidString).mp4",
                        mimeType: "video/mp4"
                    )
                    selectedItems.append(selectedItem)
                }
            } else {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if data.count > store.maxFileSizeBytes {
                        await MainActor.run {
                            store.send(.fileSizeExceeded(item.itemIdentifier ?? "이미지"))
                        }
                        continue
                    }

                    let selectedItem = SelectedMediaItem(
                        id: UUID().uuidString,
                        type: .image,
                        data: data,
                        thumbnail: nil,
                        fileName: "\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg"
                    )
                    selectedItems.append(selectedItem)
                }
            }
        }

        await MainActor.run {
            if !selectedItems.isEmpty {
                store.send(.mediaSelected(selectedItems))
                store.send(.sendMediaButtonTapped)
            }
            selectedPhotosItems = []
        }
    }

    func generateThumbnail(from url: URL) async throws -> Data {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: time)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7) ?? Data()
    }
}

// MARK: - Helpers

private extension ChatRoomView {
    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [Message] = []

        for message in store.filteredMessages {
            let messageDate = calendar.startOfDay(for: message.createdAt)

            if currentDate == nil {
                currentDate = messageDate
                currentMessages = [message]
            } else if currentDate == messageDate {
                currentMessages.append(message)
            } else {
                groups.append(MessageGroup(date: currentDate!, messages: currentMessages))
                currentDate = messageDate
                currentMessages = [message]
            }
        }

        if let date = currentDate, !currentMessages.isEmpty {
            groups.append(MessageGroup(date: date, messages: currentMessages))
        }

        return groups
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if Calendar.current.isDateInToday(date) {
            return Strings.Chat.today
        } else if Calendar.current.isDateInYesterday(date) {
            return Strings.Chat.yesterday
        } else {
            formatter.dateFormat = "yyyy년 M월 d일"
            return formatter.string(from: date)
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

// MARK: - MessageGroup

struct MessageGroup: Equatable {
    let date: Date
    let messages: [Message]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatRoomView(
            store: Store(initialState: ChatRoomFeature.State(
                chatRoomId: "D_user-1_user-2",
                currentUserId: "user-1",
                otherUser: Profile(id: "user-2", nickname: "친구")
            )) {
                ChatRoomFeature()
            } withDependencies: {
                $0.chatRoomRepository.observeMessages = { _, _ in
                    AsyncStream { continuation in
                        let messages = [
                            Message(id: "1", index: 1, senderId: "user-1", type: .text, content: "안녕하세요!", createdAt: Date().addingTimeInterval(-3600)),
                            Message(id: "2", index: 2, senderId: "user-2", type: .text, content: "반갑습니다!", createdAt: Date().addingTimeInterval(-1800)),
                            Message(id: "3", index: 3, senderId: "user-1", type: .text, content: "오늘 날씨가 좋네요", createdAt: Date())
                        ]
                        continuation.yield(messages)
                        continuation.finish()
                    }
                }
            }
        )
    }
}
