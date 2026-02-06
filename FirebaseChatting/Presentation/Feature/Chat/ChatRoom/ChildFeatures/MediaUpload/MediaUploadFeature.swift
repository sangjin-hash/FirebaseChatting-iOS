//
//  MediaUploadFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import ComposableArchitecture
import Foundation

// MARK: - SelectedMediaItem

struct SelectedMediaItem: Equatable, Identifiable, Sendable {
    let id: String
    let type: MediaType
    let data: Data
    let thumbnail: Data?  // 동영상인 경우 썸네일
    let fileName: String
    let mimeType: String

    var fileExtension: String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/heic": return "heic"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        default: return "dat"
        }
    }
}

// MARK: - UploadingMediaItem

struct UploadingMediaItem: Equatable, Identifiable, Sendable {
    let id: String
    let type: MediaType
    let thumbnail: Data?
    let originalData: Data?  // 재전송용 원본 데이터
    let mimeType: String?  // 재전송용 MIME 타입
    var progress: Double
    var isCompleted: Bool
    var downloadURL: String?
    var error: String?
    var isFailed: Bool { error != nil }
}

@Reducer
struct MediaUploadFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // 미디어 선택
        var isMediaPickerPresented: Bool = false
        var selectedMediaItems: IdentifiedArrayOf<SelectedMediaItem> = []
        let mediaSelectionLimit: Int = 10
        let maxFileSizeBytes: Int = 10 * 1024 * 1024

        // 업로드 상태
        var uploadingItems: IdentifiedArrayOf<UploadingMediaItem> = []
        var isUploading: Bool = false

        // UI 상태
        /// 파일 크기 초과 에러
        var fileSizeExceededFileName: String?

        /// 실패한 업로드 삭제 확인
        var deleteConfirmationItemId: String?

        /// 스크롤 트리거 (미디어 전송 완료 시 스크롤용)
        var scrollToBottomTrigger: UUID?

        // Computed
        /// 미디어가 선택되었는지 여부
        var hasSelectedMedia: Bool { !selectedMediaItems.isEmpty }

        /// 더 선택할 수 있는 미디어 개수
        var remainingMediaCount: Int {
            mediaSelectionLimit - selectedMediaItems.count
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        // 미디어 선택
        case mediaButtonTapped
        case setMediaPickerPresented(Bool)
        case mediaSelected([SelectedMediaItem])
        case removeSelectedMedia(String)  // itemId
        case clearSelectedMedia
        case fileSizeExceeded(String)  // fileName
        case dismissFileSizeError

        // 업로드 시작
        case sendMediaButtonTapped

        // 업로드 실패 UI
        case showDeleteConfirmation(itemId: String)
        case dismissDeleteConfirmation
        case deleteFailedUpload(itemId: String)

        // Delegate
        case delegate(Delegate)
        enum Delegate: Equatable {
            case uploadRequested(items: [SelectedMediaItem])
        }
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .mediaButtonTapped:
                state.isMediaPickerPresented = true
                return .none

            case let .setMediaPickerPresented(isPresented):
                state.isMediaPickerPresented = isPresented
                return .none

            case let .mediaSelected(items):
                for item in items { state.selectedMediaItems.append(item) }
                return .none

            case let .removeSelectedMedia(itemId):
                state.selectedMediaItems.remove(id: itemId)
                return .none

            case .clearSelectedMedia:
                state.selectedMediaItems.removeAll()
                return .none

            case let .fileSizeExceeded(fileName):
                state.fileSizeExceededFileName = fileName
                return .none

            case .dismissFileSizeError:
                state.fileSizeExceededFileName = nil
                return .none

            case .sendMediaButtonTapped:
                guard !state.selectedMediaItems.isEmpty else { return .none }

                state.isUploading = true
                state.uploadingItems = IdentifiedArrayOf(
                    uniqueElements:
                        state.selectedMediaItems.map { item in
                            UploadingMediaItem(
                                id: item.id,
                                type: item.type,
                                thumbnail: item.thumbnail
                                    ?? (item.type == .image ? item.data : nil),
                                originalData: item.data,
                                mimeType: item.mimeType,
                                progress: 0,
                                isCompleted: false
                            )
                        }
                )
                
                let items = Array(state.selectedMediaItems)
                state.selectedMediaItems.removeAll()
                return .send(.delegate(.uploadRequested(items: items)))
                
            case let .showDeleteConfirmation(itemId):
                state.deleteConfirmationItemId = itemId
                return .none
                
            case .dismissDeleteConfirmation:
                state.deleteConfirmationItemId = nil
                return .none
                
            case let .deleteFailedUpload(itemId):
                state.uploadingItems.remove(id: itemId)
                state.deleteConfirmationItemId = nil
                if state.uploadingItems.isEmpty { state.isUploading = false }
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
