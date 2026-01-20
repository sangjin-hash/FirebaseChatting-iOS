//
//  AppFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct AppFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var auth = AuthFeature.State()
        var mainTab = MainTabFeature.State()
    }

    // MARK: - Action

    enum Action {
        case auth(AuthFeature.Action)
        case mainTab(MainTabFeature.Action)
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }

        Scope(state: \.mainTab, action: \.mainTab) {
            MainTabFeature()
        }

        Reduce { state, action in
            switch action {
            case .auth:
                return .none

            case .mainTab:
                return .none
            }
        }
    }
}
