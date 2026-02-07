//
//  SwiftDataClient.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

@preconcurrency import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - SwiftDataClient

@DependencyClient
struct SwiftDataClient: Sendable {
    var modelContainer: @Sendable () throws -> ModelContainer
}

// MARK: - Dependency Key

extension SwiftDataClient: DependencyKey {
    static let liveValue: SwiftDataClient = {
        let container = try! ModelContainer(
            for: CachedMessage.self,
            CachedChatRoomIndex.self
        )
        return SwiftDataClient(modelContainer: { container })
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    var swiftDataClient: SwiftDataClient {
        get { self[SwiftDataClient.self] }
        set { self[SwiftDataClient.self] = newValue }
    }
}
