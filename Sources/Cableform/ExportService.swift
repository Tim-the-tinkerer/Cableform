import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case plainText
    case png
    case cableform

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plainText: return "Plain Text (.txt)"
        case .png: return "Paper Form (.png)"
        case .cableform: return "Cableform (.cblf)"
        }
    }

    var ext: String {
        switch self {
        case .plainText: return "txt"
        case .png: return "png"
        case .cableform: return "cblf"
        }
    }

    var utType: UTType {
        switch self {
        case .plainText: return .plainText
        case .png: return .png
        case .cableform: return .cableformDocument
        }
    }
}

extension UTType {
    /// Declared in Info.plist as com.cableform.cblf
    static var cableformDocument: UTType {
        if let t = UTType("com.cableform.cblf") { return t }
        if let t = UTType(filenameExtension: "cblf") { return t }
        return .data
    }
}

enum ExportService {

    private static let managedExtensions: Set<String> = ["txt", "png", "cblf"]

    static func plainText(for model: TelegramModel) -> String {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short

        var lines: [String] = []
        lines.append(model.company.uppercased())
        lines.append(String(repeating: "=", count: max(24, model.company.count)))
        lines.append("DATE FILED:  \(df.string(from: model.filed))")
        lines.append("WORDS:       \(model.wordCount)")
        if let check = model.paidCollect {
            lines.append("CHECK:       \(check.rawValue)")
        }
        lines.append("TO:          \(model.toAddress.isEmpty ? "—" : model.toAddress)")
        lines.append("FROM:        \(model.fromName.isEmpty ? "—" : model.fromName)")
        lines.append("OFFICE:      \(model.office.isEmpty ? "—" : model.office)")
        lines.append("")
        lines.append("MESSAGE")
        lines.append(String(repeating: "-", count: 7))
        lines.append(model.bodyText.isEmpty ? "(empty)" : model.bodyText)
        if !model.notes.isEmpty {
            lines.append("")
            lines.append("NOTES")
            lines.append(model.notes)
        }
        lines.append("")
        lines.append("— end of telegram —")
        return lines.joined(separator: "\n")
    }

    /// Strip any trailing managed extensions so the save panel only adds one.
    static func baseFileName(from suggested: String) -> String {
        var parts = suggested
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)
        if parts.isEmpty { return "telegram" }
        while parts.count > 1, managedExtensions.contains(parts.last!.lowercased()) {
            parts.removeLast()
        }
        let base = parts.joined(separator: ".")
        return base.isEmpty ? "telegram" : base
    }

    /// Ensure exactly one correct extension (fixes `name.cblf.cblf` from the panel).
    static func normalizedURL(_ url: URL, ext: String) -> URL {
        var parts = url.lastPathComponent
            .split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)
        while parts.count > 1, managedExtensions.contains(parts.last!.lowercased()) {
            parts.removeLast()
        }
        let base = parts.isEmpty ? "telegram" : parts.joined(separator: ".")
        return url.deletingLastPathComponent()
            .appendingPathComponent(base)
            .appendingPathExtension(ext)
    }

    /// Encode and overwrite an existing `.cblf` path (no save panel).
    static func writeCableform(_ model: TelegramModel, to url: URL) throws {
        let data = try CableformDocument.encode(model)
        try data.write(to: url, options: .atomic)
    }

    @MainActor
    static func save(format: ExportFormat, model: TelegramModel, suggested: String = "telegram") throws -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        // Name only — do NOT put the extension here; allowedContentTypes appends it.
        panel.nameFieldStringValue = baseFileName(from: suggested)
        panel.allowedContentTypes = [format.utType]
        panel.allowsOtherFileTypes = false
        panel.title = format == .cableform ? "Save Cableform Document" : "Export Paper Telegram"
        panel.message = format.title
        guard panel.runModal() == .OK, let chosen = panel.url else { return nil }

        let url = normalizedURL(chosen, ext: format.ext)

        let data: Data
        switch format {
        case .plainText:
            guard let d = plainText(for: model).data(using: .utf8) else { throw CableformError.exportFailed }
            data = d
        case .png:
            guard let d = PaperRenderer.pngData(for: model) else { throw CableformError.exportFailed }
            data = d
        case .cableform:
            data = try CableformDocument.encode(model)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    static func openPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // Do not filter by UTI — unregistered .cblf files often appear as public.data
        // and were invisible when the panel required com.cableform.cblf.
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.title = "Open Text or Cableform File"
        panel.message = "Load a text file or a .cblf telegram."
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        // Legacy API still most reliable for “show every file”.
        panel.allowedFileTypes = nil
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
