import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var openBridge: OpenBridge

    @State private var model = TelegramModel()
    /// Last loaded / saved / cleared baseline used to detect edits.
    @State private var cleanSnapshot = TelegramModel()
    @State private var status: String = "Compose a message, then save as text, paper PNG, or .cblf"
    @State private var isTargeted = false
    @State private var showImporter = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    /// Bumps after load so TextEditor / form bindings fully refresh.
    @State private var formIdentity = UUID()
    /// Skip onChange rewrite while applying a loaded document (body already set).
    @State private var suppressBodyRecompute = false
    /// Opened `.cblf` path for in-place Save (nil for new / text-only sessions).
    @State private var documentURL: URL?
    /// Whether we hold a security-scoped access grant for `documentURL`.
    @State private var documentScopedAccess = false

    @State private var pendingDiscard: PendingAction?
    @State private var showDiscardConfirm = false

    private var hasOpenDocument: Bool { documentURL != nil }

    private var isDirty: Bool {
        model != cleanSnapshot
    }

    private var documentDisplayName: String {
        documentURL?.lastPathComponent ?? "Untitled"
    }

    private var windowTitle: String {
        let mark = isDirty ? "• " : ""
        return "\(mark)\(documentDisplayName) — Cableform"
    }

    private enum PendingAction: Equatable {
        case clear
        case openPanel
        case load(URL)
    }

    var body: some View {
        NavigationSplitView {
            formPanel
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
                .id(formIdentity)
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ScrollView {
                    PaperPreview(model: model)
                        .padding()
                }
            }
            .overlay(alignment: .bottom) {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .padding(8)
                        .background(Color.accentColor.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(WindowTitleUpdater(title: windowTitle, isDocumentEdited: isDirty))
        .onAppear {
            if model.sourceText.isEmpty && model.bodyText.isEmpty {
                model.recomputeBody()
                markClean()
            }
            refreshWindowTitle()
        }
        .onDisappear {
            releaseDocumentAccess()
        }
        .onChange(of: model) { _ in
            refreshWindowTitle()
            updateDirtyStatusHint()
        }
        .onReceive(openBridge.$pendingURL.compactMap { $0 }) { url in
            openBridge.pendingURL = nil
            requestAction(.load(url))
        }
        .onReceive(NotificationCenter.default.publisher(for: .cableformOpenPanel)) { _ in
            presentOpen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cableformSaveDocument)) { _ in
            saveOpenDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cableformSaveDocumentAs)) { _ in
            exportAs(.cableform)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data, .item, .content, .plainText, .text, .utf8PlainText, .cableformDocument],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    requestAction(.load(url))
                }
            case .failure(let error):
                fail(error.localizedDescription)
            }
        }
        .alert("Cableform", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog(
            "Unsaved Changes",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Save") {
                handleDiscardSave()
            }
            Button("Don’t Save", role: .destructive) {
                if let action = pendingDiscard {
                    pendingDiscard = nil
                    perform(action)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDiscard = nil
            }
        } message: {
            Text(discardMessage)
        }
    }

    private var discardMessage: String {
        let name = documentDisplayName
        if hasOpenDocument {
            return "“\(name)” has unsaved changes. Save before continuing?"
        }
        return "This telegram has unsaved changes. Save before continuing?"
    }

    // MARK: - Form

    private var formPanel: some View {
        Form {
            Section("Paper header") {
                TextField("Company line", text: $model.company)
                TextField("To", text: $model.toAddress, prompt: Text("Recipient / address"))
                TextField("From", text: $model.fromName, prompt: Text("Sender"))
                TextField("Office", text: $model.office, prompt: Text("Filing office"))
                Toggle("Include paid / collect check", isOn: Binding(
                    get: { model.paidCollect != nil },
                    set: { on in
                        model.paidCollect = on ? (model.paidCollect ?? .paid) : nil
                    }
                ))
                if model.paidCollect != nil {
                    Picker("Check", selection: Binding(
                        get: { model.paidCollect ?? .paid },
                        set: { model.paidCollect = $0 }
                    )) {
                        ForEach(TelegramModel.PaidCollect.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                DatePicker("Filed", selection: $model.filed)
            }

            Section("Message") {
                Picker("Wire style", selection: $model.wireMode) {
                    ForEach(WireMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: model.wireMode) { _ in
                    if !suppressBodyRecompute { model.recomputeBody() }
                }

                Text(model.wireMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $model.sourceText)
                    .font(.system(.body, design: .default))
                    .frame(minHeight: 140)
                    .onChange(of: model.sourceText) { _ in
                        if !suppressBodyRecompute { model.recomputeBody() }
                    }

                if model.wireMode != .plain {
                    LabeledContent("On paper") {
                        Text(model.bodyText.isEmpty ? "—" : model.bodyText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                LabeledContent("Words") {
                    Text("\(model.wordCount)")
                }

                if isDirty {
                    Text(hasOpenDocument ? "Unsaved changes — ⌘S to save" : "Unsaved changes — Save As… to keep a .cblf")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Document") {
                if let url = documentURL {
                    LabeledContent("Open file") {
                        HStack(spacing: 4) {
                            if isDirty {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.orange)
                            }
                            Text(url.lastPathComponent)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .help(url.path)
                    }
                    Button {
                        saveOpenDocument()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!isDirty)
                    .help("Overwrite \(url.lastPathComponent) with your edits (⌘S)")

                    Button {
                        exportAs(.cableform)
                    } label: {
                        Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                    }
                    .help("Save a copy as a new .cblf file")
                } else {
                    Text("No .cblf document open. Save As… creates one; exports below write other formats.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        exportAs(.cableform)
                    } label: {
                        Label("Save As Cableform (.cblf)…", systemImage: "doc.badge.gearshape")
                    }
                }

                HStack {
                    Button("Open File…") { presentOpen() }
                    Button("Clear") { requestAction(.clear) }
                }
            }

            Section("Export") {
                Button {
                    exportAs(.plainText)
                } label: {
                    Label("Plain Text (.txt)", systemImage: "doc.plaintext")
                }
                Button {
                    exportAs(.png)
                } label: {
                    Label("Paper Form (.png)", systemImage: "doc.richtext")
                }
                if hasOpenDocument {
                    Button {
                        exportAs(.cableform)
                    } label: {
                        Label("Export Copy (.cblf)…", systemImage: "doc.on.doc")
                    }
                    .help("Write a separate .cblf without replacing the open file")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    // MARK: - Dirty state

    private func markClean() {
        cleanSnapshot = model
        refreshWindowTitle()
    }

    private func updateDirtyStatusHint() {
        // Keep quiet if we already have a more specific status, but surface dirty lightly.
        if isDirty, status.hasPrefix("Saved ") || status.hasPrefix("Opened ") || status == "Cleared" {
            // leave last action message
        }
    }

    private func refreshWindowTitle() {
        // Also pushed via WindowTitleUpdater; keep NSApp in sync for multi-window edge cases.
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            window.title = windowTitle
            window.isDocumentEdited = isDirty
        }
    }

    private func requestAction(_ action: PendingAction) {
        if isDirty {
            pendingDiscard = action
            showDiscardConfirm = true
        } else {
            perform(action)
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .clear:
            clearDocumentNow()
        case .openPanel:
            if let url = ExportService.openPanel() {
                loadNow(url: url)
            }
        case .load(let url):
            loadNow(url: url)
        }
    }

    private func handleDiscardSave() {
        let action = pendingDiscard
        // Save first; only continue if save succeeded.
        let saved: Bool
        if documentURL != nil {
            saved = saveOpenDocumentReturningSuccess()
        } else {
            saved = exportAsReturningSuccess(.cableform)
        }
        guard saved else {
            // User cancelled Save As or write failed — stay put.
            pendingDiscard = nil
            return
        }
        pendingDiscard = nil
        if let action {
            perform(action)
        }
    }

    // MARK: - Actions

    private func presentOpen() {
        requestAction(.openPanel)
    }

    private func clearDocumentNow() {
        releaseDocumentAccess()
        documentURL = nil
        suppressBodyRecompute = true
        model = TelegramModel()
        model.recomputeBody()
        formIdentity = UUID()
        suppressBodyRecompute = false
        markClean()
        status = "Cleared"
    }

    private func load(url: URL) {
        requestAction(.load(url))
    }

    private func loadNow(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            let data = try Data(contentsOf: resolved, options: [.mappedIfSafe])

            if CableformDocument.isCableform(data) {
                let loaded = try CableformDocument.decode(data)
                adoptDocumentURL(resolved)
                apply(loaded, statusText: "Opened \(resolved.lastPathComponent) — ⌘S saves edits")
                return
            }

            let name = resolved.lastPathComponent.lowercased()
            if resolved.pathExtension.lowercased() == "cblf" || name.contains(".cblf") {
                throw CableformError.badDocument
            }

            releaseDocumentAccess()
            documentURL = nil

            suppressBodyRecompute = true
            var next = model
            if let text = textFromData(data) {
                next.sourceText = text
            } else {
                next.sourceText = try TelegramModel.loadTextFile(from: resolved)
            }
            next.recomputeBody()
            if next.toAddress.isEmpty {
                next.toAddress = ExportService.baseFileName(from: resolved.lastPathComponent)
            }
            apply(next, statusText: "Loaded text from \(resolved.lastPathComponent)")
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func textFromData(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        if let s = String(data: data, encoding: .ascii) { return s }
        return nil
    }

    private func adoptDocumentURL(_ url: URL) {
        releaseDocumentAccess()
        documentURL = url
        documentScopedAccess = url.startAccessingSecurityScopedResource()
    }

    private func releaseDocumentAccess() {
        if documentScopedAccess, let url = documentURL {
            url.stopAccessingSecurityScopedResource()
        }
        documentScopedAccess = false
    }

    private func apply(_ loaded: TelegramModel, statusText: String) {
        suppressBodyRecompute = true
        model = loaded
        formIdentity = UUID()
        status = statusText
        markClean()
        DispatchQueue.main.async {
            suppressBodyRecompute = false
            markClean()
            refreshWindowTitle()
        }
    }

    private func fail(_ message: String) {
        status = message
        alertMessage = message
        showAlert = true
    }

    /// Overwrite the open `.cblf` in place.
    private func saveOpenDocument() {
        _ = saveOpenDocumentReturningSuccess()
    }

    @discardableResult
    private func saveOpenDocumentReturningSuccess() -> Bool {
        guard let url = documentURL else {
            return exportAsReturningSuccess(.cableform)
        }
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try ExportService.writeCableform(model, to: url)
            markClean()
            status = "Saved \(url.lastPathComponent)"
            return true
        } catch {
            fail(error.localizedDescription)
            return false
        }
    }

    private func exportAs(_ format: ExportFormat) {
        _ = exportAsReturningSuccess(format)
    }

    @discardableResult
    private func exportAsReturningSuccess(_ format: ExportFormat) -> Bool {
        do {
            let name: String = {
                if let url = documentURL {
                    return ExportService.baseFileName(from: url.lastPathComponent)
                }
                if !model.toAddress.isEmpty {
                    let cleaned = model.toAddress
                        .replacingOccurrences(of: "/", with: "-")
                        .prefix(40)
                    return "telegram-\(cleaned)"
                }
                return "telegram"
            }()
            if let url = try ExportService.save(format: format, model: model, suggested: String(name)) {
                if format == .cableform {
                    adoptDocumentURL(url)
                    markClean()
                    status = "Saved \(url.lastPathComponent) — ⌘S will update this file"
                } else {
                    status = "Exported \(url.lastPathComponent)"
                    // Exports of txt/png do not clear dirty — the .cblf document is still unsaved.
                }
                return true
            } else {
                status = "Save cancelled"
                return false
            }
        } catch {
            fail(error.localizedDescription)
            return false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        let typeId = UTType.fileURL.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeId) else { return false }

        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
            if let error {
                DispatchQueue.main.async { self.fail(error.localizedDescription) }
                return
            }
            let url = Self.url(fromDropItem: item)
            guard let url else {
                DispatchQueue.main.async { self.fail("Could not read the dropped file.") }
                return
            }
            DispatchQueue.main.async { self.requestAction(.load(url)) }
        }
        return true
    }

    private static func url(fromDropItem item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let str = item as? String {
            if let u = URL(string: str), u.isFileURL { return u }
            return URL(fileURLWithPath: str)
        }
        if let ns = item as? NSString {
            let str = ns as String
            if let u = URL(string: str), u.isFileURL { return u }
            return URL(fileURLWithPath: str)
        }
        return nil
    }
}

// MARK: - Window chrome

/// Keeps the host NSWindow title and document-edited (dot) indicator in sync.
private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String
    let isDocumentEdited: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        if window.title != title {
            window.title = title
        }
        window.isDocumentEdited = isDocumentEdited
    }
}
