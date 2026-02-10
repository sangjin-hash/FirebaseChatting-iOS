//
//  MessageBubbles.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

// MARK: - SystemMessageBubble

struct SystemMessageBubble: View {
    let message: Message
    let onReinvite: (String, String) -> Void

    var body: some View {
        if let leftUserId = message.leftUserId, let leftNickname = message.leftUserNickname {
            // 나감 메시지 + 초대하기 링크
            VStack(spacing: 4) {
                Text(message.content ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    onReinvite(leftUserId, leftNickname)
                } label: {
                    Text(Strings.Chat.inviteUserLink(leftNickname))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
        } else {
            // 일반 시스템 메시지
            Text(message.content ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - MyMessageBubble

struct MyMessageBubble: View {
    let message: Message
    let formattedTime: String
    let onImageTapped: ([String], Int) -> Void
    let onVideoTapped: (URL) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Spacer(minLength: 60)

            Text(formattedTime)
                .font(.caption2)
                .foregroundColor(.secondary)

            if message.isMediaMessage {
                MyMediaMessageContent(
                    message: message,
                    onImageTapped: onImageTapped,
                    onVideoTapped: onVideoTapped
                )
            } else {
                Text(message.content ?? "")
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - MyMediaMessageContent

struct MyMediaMessageContent: View {
    let message: Message
    let onImageTapped: ([String], Int) -> Void
    let onVideoTapped: (URL) -> Void

    var body: some View {
        if message.type == .image {
            MediaGrid(
                mediaUrls: message.mediaUrls,
                maxWidth: 220
            ) { index in
                onImageTapped(message.mediaUrls, index)
            }
        } else if message.type == .video, let urlString = message.mediaUrls.first {
            VideoThumbnail(
                url: urlString,
                maxWidth: 220
            ) {
                if let url = URL(string: urlString) {
                    onVideoTapped(url)
                }
            }
        }
    }
}

// MARK: - OtherMessageBubble

struct OtherMessageBubble: View {
    let message: Message
    let formattedTime: String
    let onImageTapped: ([String], Int) -> Void
    let onVideoTapped: (URL) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.isMediaMessage {
                OtherMediaMessageContent(
                    message: message,
                    onImageTapped: onImageTapped,
                    onVideoTapped: onVideoTapped
                )
            } else {
                Text(message.content ?? "")
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(formattedTime)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 60)
        }
    }
}

// MARK: - OtherMediaMessageContent

struct OtherMediaMessageContent: View {
    let message: Message
    let onImageTapped: ([String], Int) -> Void
    let onVideoTapped: (URL) -> Void

    var body: some View {
        if message.type == .image {
            MediaGrid(
                mediaUrls: message.mediaUrls,
                maxWidth: 220
            ) { index in
                onImageTapped(message.mediaUrls, index)
            }
        } else if message.type == .video, let urlString = message.mediaUrls.first {
            VideoThumbnail(
                url: urlString,
                maxWidth: 220
            ) {
                if let url = URL(string: urlString) {
                    onVideoTapped(url)
                }
            }
        }
    }
}

// MARK: - DateSeparator

struct DateSeparator: View {
    let formattedDate: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text(formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - UnreadDivider

struct UnreadDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(height: 1)

            Text(Strings.Chat.unreadDivider)
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}
