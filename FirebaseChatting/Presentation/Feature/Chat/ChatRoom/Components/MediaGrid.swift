//
//  MediaGrid.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import Kingfisher
import SwiftUI

// MARK: - MediaGrid

struct MediaGrid: View {
    let mediaUrls: [String]
    let maxWidth: CGFloat
    let onImageTapped: (Int) -> Void

    private let spacing: CGFloat = 2

    var body: some View {
        let layout = GridLayout.calculate(count: mediaUrls.count)

        VStack(spacing: spacing) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { rowIndex, rowCount in
                HStack(spacing: spacing) {
                    ForEach(0..<rowCount, id: \.self) { itemIndex in
                        let globalIndex = layout.globalIndex(row: rowIndex, item: itemIndex)
                        if globalIndex < mediaUrls.count {
                            mediaCell(url: mediaUrls[globalIndex], index: globalIndex, rowCount: rowCount)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: maxWidth)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func mediaCell(url: String, index: Int, rowCount: Int) -> some View {
        let cellWidth = (maxWidth - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
        let cellHeight = cellWidth  // 정사각형 셀

        KFImage(URL(string: url))
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cellWidth, height: cellHeight)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                onImageTapped(index)
            }
            .accessibilityIdentifier("media_grid_cell_\(index)")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - GridLayout

struct GridLayout: Equatable {
    let rows: [Int]  // 각 행에 들어갈 아이템 개수

    func globalIndex(row: Int, item: Int) -> Int {
        var index = 0
        for r in 0..<row {
            index += rows[r]
        }
        return index + item
    }

    static func calculate(count: Int) -> GridLayout {
        switch count {
        case 1:
            return GridLayout(rows: [1])
        case 2:
            return GridLayout(rows: [2])
        case 3:
            return GridLayout(rows: [3])
        case 4:
            return GridLayout(rows: [2, 2])
        case 5:
            return GridLayout(rows: [2, 3])
        case 6:
            return GridLayout(rows: [3, 3])
        case 7:
            return GridLayout(rows: [3, 2, 2])
        case 8:
            return GridLayout(rows: [3, 3, 2])
        case 9:
            return GridLayout(rows: [3, 3, 3])
        case 10:
            return GridLayout(rows: [3, 3, 4])
        default:
            return GridLayout(rows: [1])
        }
    }
}

// MARK: - Preview

#Preview("1 Image") {
    MediaGrid(
        mediaUrls: ["https://picsum.photos/200"],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("2 Image") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("3 Image") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("4 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("5 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("6 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204",
            "https://picsum.photos/205"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("7 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204",
            "https://picsum.photos/205",
            "https://picsum.photos/206",
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("8 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204",
            "https://picsum.photos/205",
            "https://picsum.photos/206",
            "https://picsum.photos/207",
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("9 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204",
            "https://picsum.photos/205",
            "https://picsum.photos/206",
            "https://picsum.photos/207",
            "https://picsum.photos/208"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}

#Preview("10 Images") {
    MediaGrid(
        mediaUrls: [
            "https://picsum.photos/200",
            "https://picsum.photos/201",
            "https://picsum.photos/202",
            "https://picsum.photos/203",
            "https://picsum.photos/204",
            "https://picsum.photos/205",
            "https://picsum.photos/206",
            "https://picsum.photos/207",
            "https://picsum.photos/208",
            "https://picsum.photos/209"
        ],
        maxWidth: 220
    ) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}
