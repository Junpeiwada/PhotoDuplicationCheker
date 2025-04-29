//
//  ContentView.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//

import SwiftUI

// メインビュー
struct ContentView: View {
    @StateObject private var imageProcessor = ImageProcessor()
    @State private var selectedPair: SimilarImagePair?
    @State private var isDirectoryPickerShowing = false
    @State private var showingDeleteAlert = false
    @State private var imageToDelete: ImageItem?
    @State private var accessError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationSplitView {
            VStack {
                if imageProcessor.isProcessing {
                    ProgressView(
                        "処理中...",
                        value: imageProcessor.progress,
                        total: 1.0
                    )
                    .padding()
                }

                List(
                    imageProcessor.similarPairs,
                    id: \.id,
                    selection: $selectedPair
                ) {
                    pair in
                    HStack {
                        Image(nsImage: pair.image1.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)

                        Image(nsImage: pair.image2.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)

                        VStack(alignment: .leading) {
                            Text(pair.description)
                                .font(.headline)
                            Text(
                                "\(pair.image1.fileName)"
                            )
                            .font(.caption)
                            .lineLimit(1)
                            Text(
                                "\(pair.image2.fileName)"
                            )
                            .font(.caption)
                            .lineLimit(1)
                        }
                    }
                    .onChange(of: selectedPair) { newValue in
                        print("Selected pair: \(String(describing: newValue))")
                    }
                    .onTapGesture {
                        selectedPair = pair
                        print("Selected pair: \(pair)")
                    }
                    .listStyle(.sidebar)
                    .background(
                        selectedPair == pair
                            ? Color.gray.opacity(0.2) : Color.clear
                    )
                    .padding(.vertical, 4)
                }

                Button("ディレクトリを選択") {
                    isDirectoryPickerShowing = true
                }
                .padding()
            }
            .frame(minWidth: 250)
            .navigationTitle("類似画像")

        } detail: {
            if let pair = selectedPair {
                HStack {
                    VStack {
                        ImageDetailView(imageItem: pair.image1) {
                            imageToDelete = pair.image1
                            showingDeleteAlert = true
                        }
                    }

                    VStack {
                        ImageDetailView(imageItem: pair.image2) {
                            imageToDelete = pair.image2
                            showingDeleteAlert = true
                        }
                    }
                }
                .padding()
                .navigationTitle(
                    "類似度: \(String(format: "%.1f%%", pair.similarity * 100))"
                )
            } else {
                Text("左側のリストから類似画像を選択してください")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $isDirectoryPickerShowing,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // セキュリティスコープを開始
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if gotAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // ディレクトリが読み込めるか確認
                    do {
                        // セキュアブックマークの保存
                        let bookmark = try url.bookmarkData(
                            options: [.withSecurityScope],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        UserDefaults.standard.set(bookmark, forKey: "SelectedFolderBookmark")
                        
                        
                        let contents = try FileManager.default
                            .contentsOfDirectory(atPath: url.path)
                        let selectedFolder = url  // URLを保存
                        let folderContents = contents
                        // imageProcessorにURLを渡す
                        imageProcessor.loadImages(from: url)
                    } catch {
                        errorMessage =
                            "選択したフォルダにアクセスできません: \(error.localizedDescription)"
                        accessError = true
                    }
                }
            case .failure(let error):
                errorMessage = "フォルダの選択に失敗しました: \(error.localizedDescription)"
                accessError = true
            }
        }
        .alert("エラー", isPresented: $accessError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("確認", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let imageItem = imageToDelete {
                    let success = imageProcessor.deleteImage(imageItem)
                    if !success {
                        errorMessage = "ファイルの削除に失敗しました"
                        accessError = true
                    }
                    // 選択しているペアが削除された画像を含む場合は選択解除
                    if selectedPair?.image1.id == imageItem.id
                        || selectedPair?.image2.id == imageItem.id
                    {
                        selectedPair = nil
                    }
                }
            }
        } message: {
            Text("ファイル「\(imageToDelete?.fileName ?? "")」を開きます。よろしいですか？")
        }
    }
}
