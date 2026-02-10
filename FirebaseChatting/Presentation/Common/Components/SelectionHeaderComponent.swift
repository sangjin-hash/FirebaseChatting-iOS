//
//  SelectionHeaderComponent.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI

struct SelectionHeaderComponent: View {
    let selectedCount: Int
    var emptyText: String = Strings.Chat.selectFriends
    var selectedSuffix: String = Strings.Chat.selected

    var body: some View {
        HStack {
            if selectedCount > 0 {
                Text("\(selectedCount)\(selectedSuffix)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            } else {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("선택 없음") {
    SelectionHeaderComponent(selectedCount: 0)
}

#Preview("2명 선택") {
    SelectionHeaderComponent(selectedCount: 2)
}
