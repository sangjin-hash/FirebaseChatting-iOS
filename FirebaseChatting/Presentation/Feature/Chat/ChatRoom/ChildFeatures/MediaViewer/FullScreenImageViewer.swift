//
//  FullScreenImageViewer.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Kingfisher
import SwiftUI

// MARK: - FullScreenImageViewer

struct FullScreenImageViewer: View {
    let imageURLs: [String]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var verticalDragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    @State private var scale: CGFloat = 1.0

    // 원형 큐를 위한 가상 인덱스 (앞뒤로 1개씩 추가)
    private var virtualImageURLs: [String] {
        guard imageURLs.count > 1 else { return imageURLs }
        return [imageURLs[imageURLs.count - 1]] + imageURLs + [imageURLs[0]]
    }

    @State private var virtualIndex: Int = 1

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경
                Color.black
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)

                // 이미지 컨테이너
                if imageURLs.count > 1 {
                    circularImageContainer(geometry: geometry)
                } else {
                    singleImageView(geometry: geometry)
                }
            }
            .onAppear {
                virtualIndex = currentIndex + 1
            }
            .accessibilityIdentifier(AccessibilityID.ImageViewer.container)
        }
    }

    // MARK: - Single Image View

    @ViewBuilder
    private func singleImageView(geometry: GeometryProxy) -> some View {
        ZoomableImageView(url: imageURLs[0])
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(y: verticalDragOffset)
            .gesture(verticalDismissGesture)
    }

    // MARK: - Circular Image Container

    @ViewBuilder
    private func circularImageContainer(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(virtualImageURLs.enumerated()), id: \.offset) { _, url in
                ZoomableImageView(url: url)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .scaleEffect(scale)
        .offset(x: -CGFloat(virtualIndex) * geometry.size.width + dragOffset, y: verticalDragOffset)
        .gesture(
            horizontalSwipeGesture(geometry: geometry)
                .simultaneously(with: verticalDismissGesture)
        )
        .onChange(of: virtualIndex) { _, newValue in
            if newValue == 0 {
                Task {
                    try? await Task.sleep(for: .seconds(0.26))
                    virtualIndex = imageURLs.count
                    currentIndex = imageURLs.count - 1
                }
            } else if newValue == virtualImageURLs.count - 1 {
                Task {
                    try? await Task.sleep(for: .seconds(0.26))
                    virtualIndex = 1
                    currentIndex = 0
                }
            } else {
                currentIndex = newValue - 1
            }
        }
    }

    // MARK: - Horizontal Swipe Gesture

    private func horizontalSwipeGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                let threshold: CGFloat = geometry.size.width * 0.15
                let predictedEndOffset = value.predictedEndTranslation.width

                if abs(value.translation.width) > abs(value.translation.height) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        if predictedEndOffset < -threshold || value.translation.width < -threshold {
                            virtualIndex += 1
                        } else if predictedEndOffset > threshold || value.translation.width > threshold {
                            virtualIndex -= 1
                        }
                        dragOffset = 0
                    }
                } else {
                    withAnimation {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Vertical Dismiss Gesture

    private var verticalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                // 아래로 드래그할 때만 처리
                if abs(value.translation.height) > abs(value.translation.width) && value.translation.height > 0 {
                    verticalDragOffset = value.translation.height

                    // 배경 투명도 + 스케일 동시 조절
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

// MARK: - ZoomableImageView

struct ZoomableImageView: View {
    let url: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            KFImage(URL(string: url))
                .placeholder {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    scale > 1 ? DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        } : nil
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    FullScreenImageViewer(
        imageURLs: [
            "https://picsum.photos/800/600",
            "https://picsum.photos/801/600",
            "https://picsum.photos/802/600",
            "https://picsum.photos/803/600"
        ],
        currentIndex: .constant(0)
    ) {
        print("Dismissed")
    }
}
