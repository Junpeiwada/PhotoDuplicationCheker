//
//  ImageDupCheckerApp.swift
//  ImageDupChecker
//
//  Created by Junpei on 2025/04/29.
//

import SwiftUI

@main
struct ImageDupCheckerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // ウィンドウのタイトルを設定
                    NSWindow.allowsAutomaticWindowTabbing = false
                    if let window = NSApplication.shared.windows.first {
                        window.title = "類似画像検出ツール"
                        window.setContentSize(NSSize(width: 1000, height: 700))
                    }
                }
        }
    }
}
