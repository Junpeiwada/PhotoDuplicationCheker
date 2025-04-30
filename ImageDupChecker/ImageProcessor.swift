import Combine
import CoreGraphics
//
//  ImageProcessor.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//
import SwiftUI
import UniformTypeIdentifiers
import Vision

// 画像処理と検出を行うクラス
class ImageProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var imageItems: [ImageItem] = []
    @Published var similarPairs: [SimilarImagePair] = []

    private var cancellables = Set<AnyCancellable>()
    private let similarityThreshold: Double = 0.85  // 類似度のしきい値 (0-1)

    // ディレクトリから画像を読み込む
    func loadImages(from directoryURL: URL) {
        isProcessing = true
        progress = 0
        imageItems = []
        similarPairs = []

        let fileManager = FileManager.default

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // セキュリティスコープを開始
            let gotAccess = directoryURL.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // サポートする画像形式
                let imageExtensions = [
                    "jpg", "jpeg", "png", "heic", "tiff", "gif", "bmp",
                ]

                // ディレクトリ内のすべてのファイルを取得
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: nil
                )

                // 画像ファイルのみをフィルタリング
                let imageURLs = fileURLs.filter { url in
                    return imageExtensions.contains(
                        url.pathExtension.lowercased()
                    )
                }

                // 画像の総数
                let totalImages = imageURLs.count
                var processedCount = 0

                // 各画像を処理
                for imageURL in imageURLs {
                    // 各画像ファイルにもセキュリティスコープが必要な場合
                    let imageAccess =
                        imageURL.startAccessingSecurityScopedResource()
                    defer {
                        if imageAccess {
                            imageURL.stopAccessingSecurityScopedResource()
                        }
                    }

                    if let image = NSImage(contentsOf: imageURL) {
                        let thumbnail = self.createThumbnail(from: image)

                        let imageItem = ImageItem(
                            url: imageURL,
                            thumbnail: thumbnail,
                            size: image.size
                        )

                        DispatchQueue.main.async {
                            self.imageItems.append(imageItem)
                            processedCount += 1
                            self.progress =
                                Double(processedCount) / Double(totalImages) / 2  // 50%までは画像読み込み
                        }
                    }
                }

                // 類似画像の検出
                self.detectSimilarImages()

//                DispatchQueue.main.async {
//                    self.isProcessing = false
//                }

            } catch {
                print("ディレクトリの読み込みエラー: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }

    // サムネイル作成
    private func createThumbnail(from image: NSImage) -> NSImage {
        let thumbnailSize = NSSize(width: 200, height: 200)
        let thumbnailImage = NSImage(size: thumbnailSize)

        thumbnailImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        // アスペクト比を維持してサムネイルを作成
        let imageSize = image.size
        var drawRect = NSRect(
            x: 0,
            y: 0,
            width: thumbnailSize.width,
            height: thumbnailSize.height
        )

        let widthRatio = thumbnailSize.width / imageSize.width
        let heightRatio = thumbnailSize.height / imageSize.height

        if widthRatio < heightRatio {
            drawRect.size.height = imageSize.height * widthRatio
            drawRect.origin.y =
                (thumbnailSize.height - drawRect.size.height) / 2
        } else {
            drawRect.size.width = imageSize.width * heightRatio
            drawRect.origin.x = (thumbnailSize.width - drawRect.size.width) / 2
        }

        image.draw(in: drawRect)
        thumbnailImage.unlockFocus()

        return thumbnailImage
    }

    // 画像の特徴ベクトルを取得
    private func getImageFeatures(for imageItem: ImageItem) -> [Float]? {
        guard
            let cgImage = imageItem.thumbnail.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
            )
        else {
            return nil
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNGenerateImageFeaturePrintRequest()

        do {
            try requestHandler.perform([request])
            if let featurePrint = request.results?.first
                as? VNFeaturePrintObservation
            {
                // 特徴ベクトルのサイズを取得
                let featureCount = featurePrint.elementCount

                // 特徴ベクトルを格納する配列を初期化
                var featureVector = [Float](repeating: 0, count: featureCount)

                // UnsafeMutableRawBufferPointerに変換して特徴ベクトルを取得
                featureVector.withUnsafeMutableBytes { rawBufferPointer in
                    featurePrint.data.copyBytes(to: rawBufferPointer)
                }

                return featureVector
            }
        } catch {
            print("特徴抽出エラー: \(error)")
        }

        return nil
    }

    // 特徴ベクトル間の類似度を計算
    private func calculateSimilarity(features1: [Float], features2: [Float])
        -> Double
    {
        var dotProduct: Float = 0
        var magnitude1: Float = 0
        var magnitude2: Float = 0

        for i in 0..<features1.count {
            dotProduct += features1[i] * features2[i]
            magnitude1 += features1[i] * features1[i]
            magnitude2 += features2[i] * features2[i]
        }

        magnitude1 = sqrt(magnitude1)
        magnitude2 = sqrt(magnitude2)

        if magnitude1 > 0 && magnitude2 > 0 {
            let similarity = Double(dotProduct / (magnitude1 * magnitude2))
            return max(0, min(1, similarity))  // 0-1の範囲に制限
        }

        return 0
    }

    // 類似画像を検出
    private func detectSimilarImages() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 全ての画像から特徴ベクトルを抽出
            var imageFeatures: [UUID: [Float]] = [:]

            for imageItem in self.imageItems {
                if let features = self.getImageFeatures(for: imageItem) {
                    imageFeatures[imageItem.id] = features
                }
            }

            let totalComparisons =
                (self.imageItems.count * (self.imageItems.count - 1)) / 2
            var processedComparisons = 0
            var newSimilarPairs: [SimilarImagePair] = []

            // すべての画像ペアを比較
            for i in 0..<self.imageItems.count {
                for j in (i + 1)..<self.imageItems.count {
                    let image1 = self.imageItems[i]
                    let image2 = self.imageItems[j]

                    if let features1 = imageFeatures[image1.id],
                        let features2 = imageFeatures[image2.id]
                    {

                        let similarity = self.calculateSimilarity(
                            features1: features1,
                            features2: features2
                        )

                        // しきい値以上の類似度を持つペアを保存
                        if similarity >= self.similarityThreshold {
                            let pair = SimilarImagePair(
                                image1: image1,
                                image2: image2,
                                similarity: similarity
                            )
                            newSimilarPairs.append(pair)
                        }
                    }

                    processedComparisons += 1
                    let totalProgress =
                        0.5
                        + (Double(processedComparisons)
                            / Double(totalComparisons) * 0.5)

                    DispatchQueue.main.async {
                        self.progress = totalProgress
                    }
                }
            }

            // 類似度が高い順にソート
            newSimilarPairs.sort { $0.similarity > $1.similarity }

            DispatchQueue.main.async {
                self.similarPairs = newSimilarPairs
                self.isProcessing = false
                self.progress = 1.0
            }
        }
    }

    // 画像ファイルを削除
    func deleteImage(_ imageItem: ImageItem) -> Bool {
        do {

            //            try FileManager.default.removeItem(at: imageItem.url)
            openInFinder(path: imageItem.url.path)

//            // 削除した画像を含むペアを除去
//            similarPairs.removeAll { pair in
//                return pair.image1.id == imageItem.id
//                    || pair.image2.id == imageItem.id
//            }
//
//            // 画像リストからも削除
//            imageItems.removeAll { item in
//                return item.id == imageItem.id
//            }

            return true
        } catch {
            print("削除エラー: \(error)")
            return false
        }
    }
    func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        guard
            let bookmark = UserDefaults.standard.data(
                forKey: "SelectedFolderBookmark"
            )
        else {
            print("❌ ブックマークが存在しません")
            return
        }

        var isStale = false
        do {
            let folderURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard folderURL.startAccessingSecurityScopedResource() else {
                print("❌ アクセス権限が得られません")
                return
            }
            defer { folderURL.stopAccessingSecurityScopedResource() }

            NSWorkspace.shared.activateFileViewerSelecting([url])

            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                print("❌ ファイルが存在しません: \(path)")
            }


        } catch {
            print("❌ 削除エラー: \(error.localizedDescription)")
        }
        
    }
}
