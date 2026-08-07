import SwiftUI

@main
struct CableformApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Cableform") {
            ContentView()
                .environmentObject(OpenBridge.shared)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .cableformSaveDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") {
                    NotificationCenter.default.post(name: .cableformSaveDocumentAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .importExport) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .cableformOpenPanel, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let cableformOpenPanel = Notification.Name("cableformOpenPanel")
    static let cableformSaveDocument = Notification.Name("cableformSaveDocument")
    static let cableformSaveDocumentAs = Notification.Name("cableformSaveDocumentAs")
}
