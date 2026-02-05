//
//  ChatRoomRowItem.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct ChatRoomRowItem: View {
    let chatRoom: ChatRoom
    let profile: Profile?
    let displayName: String
    let onTap: () -> Void
    let onLeave: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 프로필 이미지
                chatRoomAvatar

                // 채팅방 정보
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        if let date = chatRoom.lastMessageAt {
                            Text(formatDate(date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(chatRoom.lastMessage ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
        .contextMenu {
            Button(role: .destructive, action: onLeave) {
                Label(Strings.Chat.leave, systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Subviews

    private var chatRoomAvatar: some View {
        Group {
            if let profilePhotoUrl = profile?.profilePhotoUrl,
               let url = URL(string: profilePhotoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        avatarPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 0.5)
                }
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: chatRoom.type == .direct ? "person.fill" : "person.2.fill")
                .font(.system(size: 20))
                .foregroundColor(.primary.opacity(0.7))
        }
        .frame(width: 50, height: 50)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 0.5)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "a h:mm"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

#Preview("기본") {
    VStack(spacing: 12) {
        ChatRoomRowItem(
            chatRoom: ChatRoom(
                id: "D_user1_user2",
                type: .direct,
                lastMessage: "안녕하세요! 오늘 시간 되세요?",
                lastMessageAt: Date(),
                index: 5
            ),
            profile: Profile(id: "user2", nickname: "홍길동"),
            displayName: "홍길동",
            onTap: {},
            onLeave: {}
        )

        ChatRoomRowItem(
            chatRoom: ChatRoom(
                id: "D_user1_user3",
                type: .direct,
                lastMessage: "네, 확인했습니다.",
                lastMessageAt: Date().addingTimeInterval(-3600),
                index: 10
            ),
            profile: nil,
            displayName: "알 수 없음",
            onTap: {},
            onLeave: {}
        )

        ChatRoomRowItem(
            chatRoom: ChatRoom(
                id: "G_group123",
                type: .group,
                lastMessage: "모임 시간 정해주세요~",
                lastMessageAt: Date().addingTimeInterval(-86400),
                index: 25,
                activeUsers: ["user1": Date(), "user2": Date(), "user3": Date()]
            ),
            profile: Profile(id: "user2", nickname: "김철수"),
            displayName: "김철수 외 1명",
            onTap: {},
            onLeave: {}
        )
    }
    .padding()
}
