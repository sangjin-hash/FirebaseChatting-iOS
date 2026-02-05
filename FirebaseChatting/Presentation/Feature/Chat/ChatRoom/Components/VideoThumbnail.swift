//
//  VideoThumbnail.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import AVFoundation
import SwiftUI

// MARK: - VideoThumbnail

struct VideoThumbnail: View {
    let url: String
    let maxWidth: CGFloat
    let onTap: () -> Void

    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    @State private var fileSizeText: String?

    var body: some View {
        ZStack {
            // 썸네일 이미지
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: maxWidth)
                    .frame(height: maxWidth * 0.75)  // 4:3 비율
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: maxWidth)
                    .frame(height: maxWidth * 0.75)
                    .overlay {
                        ProgressView()
                    }
            } else {
                // 썸네일 로딩 실패
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: maxWidth)
                    .frame(height: maxWidth * 0.75)
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
            }

            // 재생 버튼 오버레이
            Image(systemName: "play.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)

            // 파일 크기 표시 (선택적)
            if let fileSizeText {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(fileSizeText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let videoURL = URL(string: url) else {
            isLoading = false
            return
        }

        let asset = AVURLAsset(url: videoURL)

        // 썸네일 생성
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            await MainActor.run {
                self.thumbnail = UIImage(cgImage: cgImage)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        VideoThumbnail(
            url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            maxWidth: 220
        ) {
            print("Video tapped")
        }

        VideoThumbnail(
            url: "invalid-url",
            maxWidth: 220
        ) {
            print("Video tapped")
        }
    }
    .padding()
}
