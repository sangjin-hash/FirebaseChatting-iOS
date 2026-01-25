//
//  CircleIconButtonComponent.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct CircleIconButtonComponent: View {
    let systemName: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundColor(isDisabled ? .gray : .accentColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.gray.opacity(0.2) : Color.accentColor.opacity(0.1))
                )
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

#Preview("채팅 버튼") {
    CircleIconButtonComponent(
        systemName: "bubble.right",
        action: {}
    )
}

#Preview("친구 추가 버튼") {
    CircleIconButtonComponent(
        systemName: "person.badge.plus",
        action: {}
    )
}

#Preview("비활성화") {
    CircleIconButtonComponent(
        systemName: "person.badge.plus",
        isDisabled: true,
        action: {}
    )
}
