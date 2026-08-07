import Foundation

/// Optional wire-desk prose for the paper body (not Morse — wording only).
enum WireStyle {

    private static let phrases: [(String, String)] = [
        ("as soon as possible", "ASAP"),
        ("for your information", "FYI"),
        ("please", "PLS"),
        ("thanks", "TKS"),
        ("thank you", "TU"),
        ("tomorrow", "TMW"),
        ("today", "TDY"),
        ("yesterday", "YDAY"),
        ("arrive", "ARR"),
        ("depart", "DEP"),
        ("confirm", "CFM"),
        ("received", "RCVD"),
        ("message", "MSG"),
        ("number", "NR"),
        ("your", "YR"),
        ("from", "FM"),
        ("with", "W"),
        ("without", "WO"),
        ("immediately", "IMMED"),
        ("attention", "ATTN"),
        ("reference", "REF"),
        ("information", "INFO"),
    ]

    static func rewrite(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }

        s = s
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        for (phrase, abbr) in phrases.sorted(by: { $0.0.count > $1.0.count }) {
            s = replaceWhole(s, phrase: phrase, with: abbr)
        }

        s = applyStop(s)
        s = s.replacingOccurrences(of: "?", with: " QUERY")
        s = s.replacingOccurrences(of: "!", with: " STOP")
        s = s.replacingOccurrences(of: ",", with: "")
        s = s.replacingOccurrences(of: ";", with: " STOP")
        s = s.replacingOccurrences(of: ":", with: "")

        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        s = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if !s.isEmpty, !s.hasSuffix("STOP"), !s.hasSuffix("QUERY") {
            s += " STOP"
        }
        return s
    }

    private static func applyStop(_ input: String) -> String {
        var out = ""
        let chars = Array(input)
        for i in chars.indices {
            let c = chars[i]
            if c == "." {
                let prevDigit = i > 0 && chars[i - 1].isNumber
                let nextDigit = i + 1 < chars.count && chars[i + 1].isNumber
                out += (prevDigit && nextDigit) ? "." : " STOP"
            } else {
                out.append(c)
            }
        }
        return out
    }

    private static func replaceWhole(_ text: String, phrase: String, with replacement: String) -> String {
        var result = text
        var start = result.startIndex
        while start < result.endIndex {
            let slice = result[start...]
            guard let range = slice.range(of: phrase, options: .caseInsensitive) else { break }
            let beforeOK = range.lowerBound == result.startIndex
                || !result[result.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == result.endIndex
                || !result[range.upperBound].isLetter
            if beforeOK && afterOK {
                result.replaceSubrange(range, with: replacement)
                start = result.index(range.lowerBound, offsetBy: replacement.count, limitedBy: result.endIndex)
                    ?? result.endIndex
            } else {
                start = range.upperBound
            }
        }
        return result
    }
}
