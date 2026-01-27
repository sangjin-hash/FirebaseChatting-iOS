//
//  MainTabView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
            ForEach(MainTabType.allCases, id: \.self) { tab in
                Group {
                    switch tab {
                    case .home:
                        HomeView(store: store.scope(state: \.home, action: \.home))
                    case .chat:
                        ChatListView(store: store.scope(state: \.chatList, action: \.chatList))
                    }
                }.tabItem {
                    Label(tab.title, image: tab.imageName(selected: store.selectedTab == tab))
                }
                .tag(tab)
            }
        }
        .tint(.bkText)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.bkText)
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
