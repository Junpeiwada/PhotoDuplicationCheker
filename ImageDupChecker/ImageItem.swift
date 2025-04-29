//
//  ImageItem.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//

import SwiftUI
import CoreGraphics
import Combine
import UniformTypeIdentifiers
import Vision

// 画像データを管理するモデル
struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let thumbnail: NSImage
    
    var fileName: String {
        return url.lastPathComponent
    }
    
    var fileSize: String {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = resourceValues.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        } catch {}
        return "不明"
    }
    
    var creationDate: String {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
            if let date = resourceValues.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                formatter.locale = Locale(identifier: "ja_JP")
                return formatter.string(from: date)
            }
        } catch {}
        return "不明"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        return lhs.id == rhs.id
    }
}
