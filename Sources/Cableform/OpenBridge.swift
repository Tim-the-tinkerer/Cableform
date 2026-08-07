import AppKit
import Foundation
import Combine

/// Shared inbox for files opened from Finder, Dock, or the File menu.
final class OpenBridge: ObservableObject {
    static let shared = OpenBridge()

    @Published var pendingURL: URL?

    func open(_ url: URL) {
        DispatchQueue.main.async {
            self.pendingURL = url
        }
    }

    func open(_ urls: [URL]) {
        guard let first = urls.first else { return }
        open(first)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        OpenBridge.shared.open(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        OpenBridge.shared.open(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        OpenBridge.shared.open(filenames.map { URL(fileURLWithPath: $0) })
        // Required when implementing openFiles:
        sender.reply(toOpenOrPrint: .success)
    }
}
