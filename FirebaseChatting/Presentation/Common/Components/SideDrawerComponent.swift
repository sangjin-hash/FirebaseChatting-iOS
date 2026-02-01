//
//  SideDrawerComponent.swift
//  FirebaseChatting
//
//  Created by Claude Code
//

import SwiftUI

struct SideDrawerComponent<Content: View>: View {
    @Binding var isOpen: Bool
    var widthRatio: CGFloat = 0.75
    var headerTitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // 반투명 배경 (탭하면 닫힘)
                if isOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isOpen = false }
                }

                // Drawer 컨텐츠
                HStack(spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 0) {
                        // 헤더
                        Text(headerTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()

                        Divider()

                        // 커스텀 컨텐츠
                        content()
                    }
                    .frame(width: geometry.size.width * widthRatio)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(.systemBackground))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
                    .offset(x: isOpen ? 0 : geometry.size.width * widthRatio)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOpen)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isOpen = true

        var body: some View {
            ZStack {
                Color.blue.opacity(0.3)
                    .ignoresSafeArea()

                VStack {
                    Button("Open Drawer") {
                        isOpen = true
                    }
                }

                SideDrawerComponent(
                    isOpen: $isOpen,
                    headerTitle: "참여 인원"
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(1...5, id: \.self) { index in
                            HStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                Text("사용자 \(index)")
                                Spacer()
                            }
                            .padding()
                            Divider()
                        }

                        Spacer()

                        Divider()

                        Button {
                            // 초대 액션
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("친구 초대하기")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
        }
    }

    return PreviewWrapper()
}
