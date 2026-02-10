//
//  EmptyStateComponent.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct EmptyStateComponent: View {
    let systemImageName: String
    let title: String
    var description: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImageName)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(title)
                .foregroundColor(.secondary)
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateComponent(
        systemImageName: "bubble.left.and.bubble.right",
        title: "채팅방이 없습니다",
        description: "친구에게 메시지를 보내보세요"
    )
}
