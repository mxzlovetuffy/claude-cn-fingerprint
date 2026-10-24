//
//  App.swift
//  入口 + 窗口外观
//
//  用 SwiftUI 的 WindowGroup 起窗，窗口本身交给 AppKit 调一下：
//  隐藏标题栏、透明、可拖动整个背景。其余都归 SwiftUI 管。
//

import SwiftUI
import AppKit

@main
struct CNDetectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Claude 中国用户检测器") {
            RootView()
                .frame(minWidth: 1040, minHeight: 720)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // 不要恢复上次的窗口状态，每次打开都从干净的一页开始
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveState(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreState(_ sender: NSApplication) -> Bool {
        false
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isRestorable = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
            window.title = Lang.shared.t("Claude 中国用户检测器", "Claude CN Fingerprint Detector")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
