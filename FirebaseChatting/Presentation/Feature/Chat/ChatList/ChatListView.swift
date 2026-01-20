//
//  ChatListView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct ChatListView: View {
    let store: StoreOf<ChatListFeature>

    var body: some View {
        Text("채팅")
            .font(.largeTitle)
    }
}

#Preview {
    ChatListView(
        store: Store(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }
    )
}
