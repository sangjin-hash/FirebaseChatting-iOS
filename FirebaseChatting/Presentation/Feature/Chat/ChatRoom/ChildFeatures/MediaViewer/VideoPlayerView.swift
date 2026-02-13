//
//  VideoPlayerView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import AVKit
import SwiftUI

// MARK: - VideoPlayerView

struct VideoPlayerView: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var verticalDragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

            VideoPlayer(player: player)
                .ignoresSafeArea()
                .scaleEffect(scale)
                .offset(y: verticalDragOffset)
        }
        .gesture(verticalDismissGesture)
        .accessibilityIdentifier(AccessibilityID.VideoPlayer.container)
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Vertical Dismiss Gesture

    private var verticalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                // 아래로 드래그할 때만 처리
                if abs(value.translation.height) > abs(value.translation.width) && value.translation.height > 0 {
                    verticalDragOffset = value.translation.height

                    // 배경 투명도 + 스케일 동시 조절 (더 자연스러운 효과)
                    let progress = min(value.translation.height / 250, 1.0)
                    backgroundOpacity = 1.0 - progress * 0.6
                    scale = 1.0 - progress * 0.15
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                let velocity = value.predictedEndTranslation.height - value.translation.height

                // 빠른 스와이프 또는 충분한 거리 이동 시 즉시 닫기
                if value.translation.height > threshold || velocity > 300 {
                    onDismiss()
                } else {
                    // 원위치 복귀 애니메이션
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
                        verticalDragOffset = 0
                        backgroundOpacity = 1.0
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerView(
        url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
    ) {
        print("Dismissed")
    }
}
