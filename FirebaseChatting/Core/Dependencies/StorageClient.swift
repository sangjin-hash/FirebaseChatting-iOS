//
//  StorageClient.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import AVFoundation
@preconcurrency import ComposableArchitecture
import FirebaseStorage
import Foundation
import UIKit

// MARK: - Storage Error

enum StorageError: Error, Equatable {
    case uploadFailed(String)
    case downloadURLFailed
    case fileTooLarge(maxSizeBytes: Int)
    case unsupportedFormat
    case thumbnailGenerationFailed
    case cancelled
}

// MARK: - Upload Progress

struct UploadProgress: Equatable, Sendable {
    let itemId: String
    let progress: Double
    let bytesTransferred: Int64
    let totalBytes: Int64
}

// MARK: - Media Item

struct MediaItem: Equatable, Sendable, Identifiable {
    let id: String
    let data: Data
    let type: MediaType
    let mimeType: String

    var fileExtension: String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/heic": return "heic"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        default: return "dat"
        }
    }
}

enum MediaType: String, Sendable, Codable {
    case image
    case video
}

// MARK: - StorageClient

@DependencyClient
nonisolated struct StorageClient: Sendable {
    /// 단일 미디어 파일 업로드 (진행률 스트림 반환)
    var uploadMedia: @Sendable (
        _ chatRoomId: String,
        _ mediaItem: MediaItem
    ) -> AsyncThrowingStream<UploadProgress, Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }

    /// 업로드 완료 후 Download URL 획득
    var getDownloadURL: @Sendable (
        _ chatRoomId: String,
        _ fileName: String
    ) async throws -> URL

    /// 동영상에서 썸네일 추출
    var generateVideoThumbnail: @Sendable (_ videoData: Data) async throws -> Data

    /// 파일 크기 검증
    var validateFileSize: @Sendable (_ data: Data, _ maxSizeBytes: Int) -> Bool = { data, maxSize in
        data.count <= maxSize
    }
}

// MARK: - Dependency Key

extension StorageClient: DependencyKey {
    nonisolated static let liveValue: StorageClient = {
        let storage = Storage.storage()

        return StorageClient(
            uploadMedia: { chatRoomId, mediaItem in
                AsyncThrowingStream { continuation in
                    let path = "\(chatRoomId)/\(mediaItem.id).\(mediaItem.fileExtension)"
                    let ref = storage.reference().child(path)

                    let metadata = StorageMetadata()
                    metadata.contentType = mediaItem.mimeType

                    let uploadTask = ref.putData(mediaItem.data, metadata: metadata)

                    uploadTask.observe(.progress) { snapshot in
                        guard let progress = snapshot.progress else { return }
                        let uploadProgress = UploadProgress(
                            itemId: mediaItem.id,
                            progress: progress.fractionCompleted,
                            bytesTransferred: progress.completedUnitCount,
                            totalBytes: progress.totalUnitCount
                        )
                        continuation.yield(uploadProgress)
                    }

                    uploadTask.observe(.success) { _ in
                        // 최종 100% 진행률 전송
                        let finalProgress = UploadProgress(
                            itemId: mediaItem.id,
                            progress: 1.0,
                            bytesTransferred: Int64(mediaItem.data.count),
                            totalBytes: Int64(mediaItem.data.count)
                        )
                        continuation.yield(finalProgress)
                        continuation.finish()
                    }

                    uploadTask.observe(.failure) { snapshot in
                        let errorMessage = snapshot.error?.localizedDescription ?? "Unknown error"
                        continuation.finish(throwing: StorageError.uploadFailed(errorMessage))
                    }

                    continuation.onTermination = { @Sendable _ in
                        uploadTask.cancel()
                    }
                }
            },
            getDownloadURL: { chatRoomId, fileName in
                let path = "\(chatRoomId)/\(fileName)"
                let ref = storage.reference().child(path)
                return try await ref.downloadURL()
            },
            generateVideoThumbnail: { videoData in
                // 임시 파일로 저장
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")

                try videoData.write(to: tempURL)
                defer { try? FileManager.default.removeItem(at: tempURL) }

                let asset = AVAsset(url: tempURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 300, height: 300)

                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                let (cgImage, _) = try await generator.image(at: time)
                let uiImage = UIImage(cgImage: cgImage)

                guard let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
                    throw StorageError.thumbnailGenerationFailed
                }

                return jpegData
            },
            validateFileSize: { data, maxSizeBytes in
                data.count <= maxSizeBytes
            }
        )
    }()
}

// MARK: - Dependency Values

extension DependencyValues {
    nonisolated var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}

