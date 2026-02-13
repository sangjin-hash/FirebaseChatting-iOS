//
//  FirebaseChattingApp.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Kingfisher
import SwiftUI
import ComposableArchitecture

@main
struct FirebaseChattingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let store: StoreOf<AppFeature>

    init() {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            store = Store(initialState: AppFeature.State()) {
                AppFeature()
            } withDependencies: {
                UITestingDependencies.configure(&$0)
            }
        } else {
            store = Store(initialState: AppFeature.State()) {
                AppFeature()
            }
            configureKingfisherCache()
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView(
                store: store.scope(state: \.auth, action: \.auth)
            )
        }
    }

    private func configureKingfisherCache() {
        // 메모리 캐시 설정: 100MB
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024

        // 디스크 캐시 설정: 500MB, 7일 만료
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(7)

        // 다운로더 타임아웃 설정
        let downloader = ImageDownloader.default
        downloader.downloadTimeout = 30
    }
}
