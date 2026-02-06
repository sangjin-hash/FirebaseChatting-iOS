//
//  DrawerFeature.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
import ComposableArchitecture

@Reducer
struct DrawerFeature {
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var isOpen: Bool = false
    }
    
    // MARK: - Action
    
    enum Action: Equatable {
        // UI Actions
        case openButtonTapped
        case setOpen(Bool)
        
        // Menu Actions
        case inviteButtonTapped
        case leaveButtonTapped
        
        // Delegate
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case inviteTapped
            case leaveTapped
        }
    }
    
    // MARK: - Reducer
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .openButtonTapped:
                state.isOpen.toggle()
                return .none
            
            case let .setOpen(isOpen):
                state.isOpen = isOpen
                return .none
                
            case .inviteButtonTapped:
                state.isOpen = false
                // 0.3초 후 delegate 전송 (drawer 닫힘 애니메이션 대기)
                return .run { send in
                    try await Task.sleep(nanoseconds: 300_000_000)
                    await send(.delegate(.inviteTapped))
                }
            
            case .leaveButtonTapped:
                state.isOpen = false
                return .send(.delegate(.leaveTapped))
                
            case .delegate:
                return .none
            }
        }
    }
}
