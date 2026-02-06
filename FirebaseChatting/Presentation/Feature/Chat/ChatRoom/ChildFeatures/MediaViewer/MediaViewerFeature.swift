//
//  MediaViewerFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import ComposableArchitecture
import Foundation

// MARK: - FullScreenImageViewerState

struct FullScreenImageViewerState: Equatable, Sendable {
    let imageURLs: [String]
    var currentIndex: Int
}

@Reducer
struct MediaViewerFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var fullScreenImageViewerState: FullScreenImageViewerState?
        var videoPlayerURL: URL?
    }

    // MARK: - Action

    enum Action: Equatable {
        // 이미지 전체화면 뷰어
        case imageTapped(imageURLs: [String], index: Int)
        case dismissImageViewer
        case imageViewerIndexChanged(Int)

        // 동영상 플레이어
        case videoTapped(URL)
        case dismissVideoPlayer
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .imageTapped(imageURLs, index):
                state.fullScreenImageViewerState = FullScreenImageViewerState(
                    imageURLs: imageURLs,
                    currentIndex: index
                )
                return .none

            case .dismissImageViewer:
                state.fullScreenImageViewerState = nil
                return .none

            case let .imageViewerIndexChanged(index):
                state.fullScreenImageViewerState?.currentIndex = index
                return .none

            case let .videoTapped(url):
                state.videoPlayerURL = url
                return .none

            case .dismissVideoPlayer:
                state.videoPlayerURL = nil
                return .none
            }
        }
    }

}
