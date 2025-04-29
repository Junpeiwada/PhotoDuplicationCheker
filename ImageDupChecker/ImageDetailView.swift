//
//  ImageDetailView.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//
import SwiftUI

// 画像詳細表示ビュー
struct ImageDetailView: View {
    let imageItem: ImageItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack {
            Image(nsImage: imageItem.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 2000)
                .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ファイル名: \(imageItem.fileName)")
                Text("サイズ: \(imageItem.fileSize)")
                Text("作成日時: \(imageItem.creationDate)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Button("開く") {
                onDelete()
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}
