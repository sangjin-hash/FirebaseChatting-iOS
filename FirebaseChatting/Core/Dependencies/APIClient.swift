//
//  APIClient.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Foundation
@preconcurrency import ComposableArchitecture
import FirebaseAuth

// MARK: - Network Error

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case alreadyExists
    case serverError(String)
    case networkError(String)
}

// MARK: - APIClient

// Note: @DependencyClient 매크로 사용 시 클로저 파라미터 "uninitialized" 문제 해결
// - 문제: @DependencyClient 매크로 사용 시 liveValue의 클로저 파라미터가 초기화되지 않아 EXC_BAD_ACCESS 크래시 발생
// - 원인: @MainActor로 격리된 타입의 @Sendable 클로저가 백그라운드 스레드에서 실행될 때,
//         Swift 컴파일러가 클로저 파라미터를 전달하는 과정에서 메모리 바인딩 실패.
//         (Swift 매크로/동시성 시스템의 버그로 추정)
// - 해결방법: struct, liveValue, DependencyValues에 nonisolated 키워드 추가하여 @MainActor 격리 해제
// - 관련 링크:
//   - https://github.com/pointfreeco/swift-dependencies/discussions/404
//   - https://github.com/pointfreeco/swift-dependencies/discussions/409

@DependencyClient
nonisolated struct APIClient: Sendable {
    var get: @Sendable (_ endpoint: String) async throws -> Data
    var post: @Sendable (_ endpoint: String, _ body: Data) async throws -> Data
    var put: @Sendable (_ endpoint: String, _ body: Data) async throws -> Data
    var delete: @Sendable (_ endpoint: String) async throws -> Void
    var patch: @Sendable (_ endpoint: String, _ body: Data) async throws -> Data
}

// MARK: - Dependency Key

extension APIClient: DependencyKey {
    nonisolated static let liveValue: APIClient = {
        let client = HTTPClient()

        return APIClient(
            get: { endpoint in
                try await client.request(endpoint: endpoint, method: "GET", body: nil)
            },
            post: { endpoint, body in
                try await client.request(endpoint: endpoint, method: "POST", body: body)
            },
            put: { endpoint, body in
                try await client.request(endpoint: endpoint, method: "PUT", body: body)
            },
            delete: { endpoint in
                _ = try await client.request(endpoint: endpoint, method: "DELETE", body: nil)
            },
            patch: { endpoint, body in
                try await client.request(endpoint: endpoint, method: "PATCH", body: body)
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    nonisolated var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}


// MARK: - HTTP Client

private final class HTTPClient: @unchecked Sendable {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func request(
        endpoint: String,
        method: String,
        body: Data?
    ) async throws -> Data {
        // 1. Build URL
        let urlString = Secrets.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        // 2. Get Firebase Auth Token
        let token = try await getAuthToken()

        // 3. Build Request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // 4. Set Body
        if let body {
            request.httpBody = body
        }

        // 5. Execute Request
        let (data, response) = try await session.data(for: request)

        // 6. Validate Response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 409:
            throw NetworkError.alreadyExists
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError(message)
        }

        return data
    }

    private func getAuthToken() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NetworkError.unauthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            currentUser.getIDToken { token, error in
                if let error {
                    continuation.resume(throwing: NetworkError.networkError(error.localizedDescription))
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: NetworkError.unauthorized)
                }
            }
        }
    }
}
