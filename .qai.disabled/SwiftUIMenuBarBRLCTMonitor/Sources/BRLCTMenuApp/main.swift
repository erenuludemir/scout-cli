import SwiftUI

@main
struct BRLCTMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "BRLCT"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Başlat", action: #selector(runScript), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Yenile", action: #selector(runScript), keyEquivalent: "R"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        runScript()
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(runScript), userInfo: nil, repeats: true)
    }

    @objc func runScript() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    let appRoot = ProcessInfo.processInfo.environment["APP_ROOT"] ?? FileManager.default.currentDirectoryPath
    let scriptPath = appRoot + "/.qai/brlct_monitor.py"
    task.arguments = ["python3", scriptPath]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()

        DispatchQueue.global(qos: .background).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let firstLine = output.components(separatedBy: "\n").first ?? "BRLCT"
                DispatchQueue.main.async {
                    self.statusItem?.button?.title = firstLine
                }
            }
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}