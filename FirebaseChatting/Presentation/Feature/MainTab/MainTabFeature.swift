//
//  HomeFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct MainTabFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var selectedTab: MainTabType = .home
        var home = HomeFeature.State()
        var chatList = ChatListFeature.State()
    }

    // MARK: - Action

    enum Action: Equatable {
        case selectedTabChanged(MainTabType)
        case home(HomeFeature.Action)
        case chatList(ChatListFeature.Action)
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.chatList, action: \.chatList) {
            ChatListFeature()
        }

        Reduce { state, action in
            switch action {
            case let .selectedTabChanged(tab):
                state.selectedTab = tab
                return .none

            case .home:
                return .none

            case .chatList:
                return .none
            }
        }
    }
}
