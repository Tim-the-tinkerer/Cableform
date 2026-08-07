import Foundation

/// Everything that appears on a paper telegram blank.
struct TelegramModel: Equatable {
    var company: String = "CABLEFORM TELEGRAPH COMPANY"
    var toAddress: String = ""
    var fromName: String = ""
    var office: String = ""
    /// When `nil`, the CHECK (PAID/COLLECT) line is omitted from paper and exports.
    var paidCollect: PaidCollect? = nil
    var filed: Date = Date()
    /// Original input (typed or loaded from a file).
    var sourceText: String = ""
    /// Text drawn on the paper form.
    var bodyText: String = ""
    var useWireStyle: Bool = true
    var notes: String = ""

    enum PaidCollect: String, CaseIterable, Identifiable {
        case paid = "PAID"
        case collect = "COLLECT"
        var id: String { rawValue }
    }

    /// Words on the paper body (rough telegraphic count).
    var wordCount: Int {
        bodyText
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
            .count
    }

    mutating func recomputeBody() {
        if useWireStyle {
            bodyText = WireStyle.rewrite(sourceText)
        } else {
            bodyText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func loadTextFile(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        if let s = String(data: data, encoding: .ascii) { return s }
        throw CableformError.unreadableFile
    }
}

enum CableformError: LocalizedError {
    case unreadableFile
    case exportFailed
    case badDocument
    case invalidUTF8(field: String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "Could not read that file as text."
        case .exportFailed: return "Export failed."
        case .badDocument: return "Not a valid Cableform (.cblf) document."
        case .invalidUTF8(let field):
            return "Cableform document has invalid UTF-8 in the “\(field)” field."
        }
    }
}
