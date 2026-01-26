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

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isDisabled ? .secondary : .primary)
                .frame(width: 40, height: 40)
                .background(
                    isDisabled
                        ? AnyShapeStyle(.ultraThinMaterial.opacity(0.5))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: isDisabled
                                    ? [.white.opacity(0.1), .white.opacity(0.05)]
                                    : [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: isDisabled ? .clear : .black.opacity(0.12),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
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
