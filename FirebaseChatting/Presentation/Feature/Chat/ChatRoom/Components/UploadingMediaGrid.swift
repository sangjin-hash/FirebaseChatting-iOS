//
//  UploadingMediaGrid.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import UIKit

// MARK: - UploadingMediaGrid

struct UploadingMediaGrid: View {
    let items: [UploadingMediaItem]
    let onRetry: (String) -> Void
    let onDelete: (String) -> Void

    private var imageItems: [UploadingMediaItem] {
        items.filter { $0.type == .image }
    }

    private var videoItems: [UploadingMediaItem] {
        items.filter { $0.type == .video }
    }

    private var hasFailedItem: Bool {
        items.contains { $0.isFailed }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Spacer(minLength: 60)

            // 실패 시 재전송/삭제 버튼
            if hasFailedItem {
                failedItemActions
            }

            VStack(spacing: 8) {
                // 이미지 그리드
                if !imageItems.isEmpty {
                    UploadingImageGrid(items: imageItems)
                }

                // 동영상은 개별 표시
                ForEach(videoItems) { item in
                    UploadingVideoCell(item: item)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.ChatRoom.uploadingGrid)
    }

    private var failedItemActions: some View {
        VStack(spacing: 4) {
            ForEach(items.filter { $0.isFailed }) { item in
                HStack(spacing: 8) {
                    Button {
                        onRetry(item.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }

                    Button {
                        onDelete(item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - UploadingImageGrid

struct UploadingImageGrid: View {
    let items: [UploadingMediaItem]

    private let maxWidth: CGFloat = 220
    private let spacing: CGFloat = 2

    private var totalProgress: Double {
        items.map { $0.progress }.reduce(0, +) / Double(items.count)
    }

    private var allCompleted: Bool {
        items.allSatisfy { $0.isCompleted }
    }

    private var anyFailed: Bool {
        items.contains { $0.isFailed }
    }

    var body: some View {
        let layout = GridLayout.calculate(count: items.count)

        ZStack {
            VStack(spacing: spacing) {
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { rowIndex, rowCount in
                    HStack(spacing: spacing) {
                        ForEach(0..<rowCount, id: \.self) { itemIndex in
                            let globalIndex = layout.globalIndex(row: rowIndex, item: itemIndex)
                            if globalIndex < items.count {
                                UploadingImageCell(
                                    item: items[globalIndex],
                                    cellWidth: (maxWidth - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: maxWidth)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 중앙 오버레이 (업로드 중일 때)
            if !allCompleted && !anyFailed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(maxWidth: maxWidth)

                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("\(Int(totalProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }

            // 실패 오버레이
            if anyFailed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(maxWidth: maxWidth)

                Image(systemName: "exclamationmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - UploadingImageCell

struct UploadingImageCell: View {
    let item: UploadingMediaItem
    let cellWidth: CGFloat

    var body: some View {
        ZStack {
            if let thumbnail = item.thumbnail, let uiImage = UIImage(data: thumbnail) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellWidth, height: cellWidth)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: cellWidth, height: cellWidth)
            }
        }
    }
}

// MARK: - UploadingVideoCell

struct UploadingVideoCell: View {
    let item: UploadingMediaItem

    var body: some View {
        ZStack {
            // 썸네일 또는 플레이스홀더
            if let thumbnail = item.thumbnail, let uiImage = UIImage(data: thumbnail) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray4))
                    .frame(width: 160, height: 160)
            }

            // 업로드 중일 때 회색 오버레이 + 프로그래스바
            if !item.isCompleted && !item.isFailed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 160, height: 160)

                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("\(Int(item.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }

            // 동영상 아이콘
            if item.isCompleted {
                Image(systemName: "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }

            // 실패 아이콘
            if item.isFailed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 160, height: 160)

                Image(systemName: "exclamationmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
            }
        }
    }
}
