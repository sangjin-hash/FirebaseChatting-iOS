//
//  FirebaseChattingApp.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import SwiftUI
import ComposableArchitecture

@main
struct FirebaseChattingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView(
                store: store.scope(state: \.auth, action: \.auth)
            )
        }
    }
}
