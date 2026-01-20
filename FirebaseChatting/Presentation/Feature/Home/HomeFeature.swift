//
//  HomeFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct HomeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // - 내 프로필 정보
        // - 친구 목록
        // - 검색 화면 네비게이션
        var placeholder: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable {
        case onAppear
    }

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}
