//
//  AuthenticatedView.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

struct AuthenticatedView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        VStack {
            switch store.authenticationState {
            case .unauthenticated:
                LoginView(store: store)
            case .authenticated:
                if let mainTabStore = store.scope(state: \.mainTab, action: \.mainTab) {
                    MainTabView(store: mainTabStore)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    AuthenticatedView(
        store: Store(initialState: AuthFeature.State()) {
            AuthFeature()
        }
    )
}
