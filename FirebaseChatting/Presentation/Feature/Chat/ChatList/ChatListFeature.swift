//
//  ChatListFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct ChatListFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // TODO: Phase 4에서 구현 예정
        // - 채팅방 목록
        // - 안읽은 메시지 수
        // - 실시간 업데이트
        var placeholder: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable {
        // TODO: Phase 4에서 구현 예정
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
