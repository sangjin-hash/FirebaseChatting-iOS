//
//  VideoTransferable.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// MARK: - VideoTransferable

struct VideoTransferable: Transferable {
    let url: URL?
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            // 임시 파일로 저장
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try data.write(to: tempURL)
            return VideoTransferable(url: tempURL, data: data)
        }
    }
}
