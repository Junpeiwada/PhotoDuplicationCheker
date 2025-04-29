//
//  SimilarImagePair.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//
import SwiftUI
import CoreGraphics
import Combine
import UniformTypeIdentifiers
import Vision
// 類似画像ペアのモデル
struct SimilarImagePair: Identifiable, Hashable {
    let id = UUID()
    let image1: ImageItem
    let image2: ImageItem
    let similarity: Double
    
    var description: String {
        return String(format: "類似度: %.1f%%", similarity * 100)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SimilarImagePair, rhs: SimilarImagePair) -> Bool {
        return lhs.id == rhs.id
    }
}
