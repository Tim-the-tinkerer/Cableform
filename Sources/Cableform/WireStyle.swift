import Foundation

/// How source prose is rendered onto the paper body.
enum WireMode: String, CaseIterable, Identifiable, Equatable {
    /// Leave source text as typed (trimmed only).
    case plain = "plain"
    /// Light modern wire-desk: caps, STOP, common abbreviations.
    case desk = "desk"
    /// Period commercial telegram: word economy a real operator / public would send.
    case period = "period"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "As written"
        case .desk: return "Wire desk"
        case .period: return "Period telegram"
        }
    }

    var detail: String {
        switch self {
        case .plain:
            return "Paper shows your text unchanged."
        case .desk:
            return "ALL CAPS, STOP/QUERY, light abbreviations."
        case .period:
            return "Commercial wire style: drop fillers, STOP/QUERY/COMMA, era abbreviations."
        }
    }
}

/// Rewrites prose for the paper body (not Morse — wording only).
enum WireStyle {

    static func rewrite(_ text: String, mode: WireMode) -> String {
        switch mode {
        case .plain:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .desk:
            return deskRewrite(text)
        case .period:
            return periodRewrite(text)
        }
    }

    // MARK: - Wire desk (light)

    private static let deskPhrases: [(String, String)] = [
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

    private static func deskRewrite(_ text: String) -> String {
        var s = collapseProse(text)
        guard !s.isEmpty else { return "" }

        for (phrase, abbr) in deskPhrases.sorted(by: { $0.0.count > $1.0.count }) {
            s = replaceWhole(s, phrase: phrase, with: abbr)
        }

        s = applySentenceStops(s)
        s = s.replacingOccurrences(of: "?", with: " QUERY")
        s = s.replacingOccurrences(of: "!", with: " STOP")
        s = s.replacingOccurrences(of: ",", with: "")
        s = s.replacingOccurrences(of: ";", with: " STOP")
        s = s.replacingOccurrences(of: ":", with: "")
        s = finalizeWire(s)
        return s
    }

    // MARK: - Period commercial telegram

    /// Multi-word commercial / public phrases first (longest match wins).
    private static let periodPhrases: [(String, String)] = [
        ("as soon as possible", "SOONEST"),
        ("as soon as you can", "SOONEST"),
        ("at the earliest opportunity", "SOONEST"),
        ("at your earliest convenience", "SOONEST"),
        ("for your information", "FYI"),
        ("in regard to", "RE"),
        ("with regard to", "RE"),
        ("with reference to", "RE"),
        ("in reference to", "RE"),
        ("referring to", "RE"),
        ("on account of", "ACCT"),
        ("in accordance with", "PER"),
        ("by return wire", "WIRE REPLY"),
        ("by return mail", "MAIL REPLY"),
        ("will advise", "WADV"),
        ("please advise", "ADV"),
        ("please confirm", "CFM"),
        ("please reply", "RPLY"),
        ("please rush", "RUSH"),
        ("best regards", "B RGS"),
        ("kind regards", "RGS"),
        ("many thanks", "TKS"),
        ("thank you very much", "TKS"),
        ("thank you", "TKS"),
        ("do not", "DONT"),
        ("does not", "DOESNT"),
        ("did not", "DIDNT"),
        ("will not", "WONT"),
        ("would not", "WDNT"),
        ("cannot", "CANT"),
        ("could not", "COULDNT"),
        ("should not", "SHOULDNT"),
        ("have not", "HAVENT"),
        ("has not", "HASNT"),
        ("is not", "ISNT"),
        ("are not", "ARENT"),
        ("was not", "WASNT"),
        ("were not", "WERENT"),
        ("I am", "AM"),
        ("I will", "WILL"),
        ("I shall", "WILL"),
        ("I have", "HAVE"),
        ("we are", "WE"),
        ("we will", "WE WILL"),
        ("we shall", "WE WILL"),
        ("you are", "UR"),
        ("you will", "U WILL"),
        ("they are", "THEY"),
        ("it is", "ITS"),
        ("that is", "THATS"),
        ("there is", "THERES"),
        ("there are", "THERE"),
        ("going to", "GOING"),
        ("about to", "ABOUT"),
        ("in order to", "TO"),
        ("so that", "SO"),
        ("as well as", "AND"),
        ("in the event that", "IF"),
        ("in case of", "IF"),
        ("per cent", "PCT"),
        ("percent", "PCT"),
        ("dollars and cents", "DOLS"),
        ("united states", "US"),
        ("new york", "NY"),
        ("los angeles", "LA"),
        ("san francisco", "SF"),
        ("washington dc", "WASH DC"),
        ("washington d.c.", "WASH DC"),
        ("railroad", "RR"),
        ("steamship", "SS"),
        ("post office", "PO"),
        ("money order", "MO"),
        ("bill of lading", "BL"),
        ("care of", "C/O"),
        ("in care of", "C/O"),
    ]

    /// Single-token commercial abbreviations (case-insensitive whole word).
    private static let periodWords: [(String, String)] = [
        ("please", "PLS"),
        ("thanks", "TKS"),
        ("thank", "TKS"),
        ("tomorrow", "TMW"),
        ("today", "TDAY"),
        ("yesterday", "YDAY"),
        ("tonight", "TNITE"),
        ("morning", "AM"),
        ("afternoon", "PM"),
        ("evening", "EVE"),
        ("night", "NITE"),
        ("arrive", "ARR"),
        ("arrives", "ARR"),
        ("arrived", "ARR"),
        ("arriving", "ARR"),
        ("arrival", "ARR"),
        ("depart", "DEP"),
        ("departs", "DEP"),
        ("departed", "DEP"),
        ("departing", "DEP"),
        ("departure", "DEP"),
        ("confirm", "CFM"),
        ("confirms", "CFM"),
        ("confirmed", "CFM"),
        ("confirmation", "CFM"),
        ("acknowledge", "ACK"),
        ("acknowledged", "ACK"),
        ("acknowledgment", "ACK"),
        ("acknowledgement", "ACK"),
        ("received", "RCVD"),
        ("receive", "RCV"),
        ("receiving", "RCVG"),
        ("message", "MSG"),
        ("messages", "MSGS"),
        ("number", "NR"),
        ("numbers", "NRS"),
        ("your", "YR"),
        ("yours", "YRS"),
        ("from", "FM"),
        ("without", "WO"),
        ("with", "W"),
        ("immediately", "IMMED"),
        ("immediate", "IMMED"),
        ("attention", "ATTN"),
        ("reference", "REF"),
        ("regarding", "RE"),
        ("information", "INFO"),
        ("important", "IMPT"),
        ("urgent", "URGENT"),
        ("advise", "ADV"),
        ("advised", "ADVD"),
        ("advising", "ADVG"),
        ("request", "RQST"),
        ("requested", "RQSTD"),
        ("reply", "RPLY"),
        ("replied", "RPLD"),
        ("answer", "ANS"),
        ("answered", "ANSD"),
        ("question", "QSTN"),
        ("account", "ACCT"),
        ("accounts", "ACCTS"),
        ("balance", "BAL"),
        ("shipment", "SHIPT"),
        ("shipments", "SHIPTS"),
        ("merchandise", "MDSE"),
        ("order", "ORD"),
        ("orders", "ORDS"),
        ("ordered", "ORDD"),
        ("cancel", "CNCL"),
        ("canceled", "CNCLD"),
        ("cancelled", "CNCLD"),
        ("cancellation", "CNCLN"),
        ("forward", "FWD"),
        ("forwarded", "FWDD"),
        ("return", "RTN"),
        ("returned", "RTND"),
        ("about", "ABT"),
        ("between", "BTWN"),
        ("before", "BFR"),
        ("because", "BEC"),
        ("business", "BUS"),
        ("company", "CO"),
        ("corporation", "CORP"),
        ("incorporated", "INC"),
        ("limited", "LTD"),
        ("street", "ST"),
        ("avenue", "AVE"),
        ("boulevard", "BLVD"),
        ("building", "BLDG"),
        ("apartment", "APT"),
        ("telephone", "TEL"),
        ("telegram", "WIRE"),
        ("telegraph", "WIRE"),
        ("dollars", "DOLS"),
        ("dollar", "DOL"),
        ("cents", "CTS"),
        ("percent", "PCT"),
        ("week", "WK"),
        ("weeks", "WKS"),
        ("month", "MO"),
        ("months", "MOS"),
        ("year", "YR"),
        ("years", "YRS"),
        ("hour", "HR"),
        ("hours", "HRS"),
        ("minute", "MIN"),
        ("minutes", "MINS"),
        ("monday", "MON"),
        ("tuesday", "TUE"),
        ("wednesday", "WED"),
        ("thursday", "THU"),
        ("friday", "FRI"),
        ("saturday", "SAT"),
        ("sunday", "SUN"),
        ("january", "JAN"),
        ("february", "FEB"),
        ("march", "MAR"),
        ("april", "APR"),
        ("june", "JUN"),
        ("july", "JUL"),
        ("august", "AUG"),
        ("september", "SEP"),
        ("october", "OCT"),
        ("november", "NOV"),
        ("december", "DEC"),
        ("doctor", "DR"),
        ("professor", "PROF"),
        ("superintendent", "SUPT"),
        ("manager", "MGR"),
        ("president", "PRES"),
        ("secretary", "SECY"),
        ("treasurer", "TREAS"),
        ("government", "GOVT"),
        ("department", "DEPT"),
        ("association", "ASSN"),
        ("meeting", "MTG"),
        ("meetings", "MTGS"),
        ("reservation", "RESVN"),
        ("reservations", "RESVNS"),
        ("accommodation", "ACCN"),
        ("accommodations", "ACCNS"),
        ("transportation", "TRANSP"),
        ("necessary", "NECY"),
        ("unnecessary", "UNNECY"),
        ("possible", "POSS"),
        ("impossible", "IMPOSS"),
        ("available", "AVAIL"),
        ("approximately", "APPROX"),
        ("additional", "ADDL"),
        ("regarding", "RE"),
        ("regards", "RGS"),
        ("respectfully", "RESPY"),
        ("sincerely", "SNCLY"),
        ("and", "AND"), // kept; cable often used AND not &
        ("okay", "OK"),
        ("ok", "OK"),
        ("will", "WILL"),
        ("shall", "WILL"),
        ("would", "WD"),
        ("could", "CD"),
        ("should", "SHD"),
        ("through", "THRU"),
        ("though", "THO"),
        ("although", "ALTHO"),
        ("because", "BEC"),
        ("however", "HWEVER"),
        ("therefore", "THEREF"),
        ("otherwise", "OTHERW"),
        ("something", "SOMETHG"),
        ("nothing", "NOTHG"),
        ("everything", "EVERYTHG"),
        ("anything", "ANYTHG"),
        ("someone", "SOMEONE"),
        ("everyone", "EVERYONE"),
        ("anybody", "ANYBODY"),
        ("nobody", "NOBODY"),
    ]

    /// Articles and mild fillers public messages dropped to save words.
    private static let dropWords: Set<String> = [
        "a", "an", "the",
        "that", "which", "who", "whom", // relative fillers often omitted on the wire
        "just", "really", "very", "quite", "rather", "somewhat",
        "actually", "basically", "literally",
    ]

    private static func periodRewrite(_ text: String) -> String {
        var s = collapseProse(text)
        guard !s.isEmpty else { return "" }

        // Normalize fancy punctuation toward ASCII wire tokens.
        s = s
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2014}", with: " - ")
            .replacingOccurrences(of: "\u{2013}", with: " - ")
            .replacingOccurrences(of: "…", with: "...")
            .replacingOccurrences(of: "...", with: ".")

        s = encodeQuotes(s)
        s = encodeParens(s)

        for (phrase, abbr) in periodPhrases.sorted(by: { $0.0.count > $1.0.count }) {
            s = replaceWhole(s, phrase: phrase, with: abbr)
        }

        // Token-level: abbreviations + drop articles/fillers.
        // Preserve terminal ? ! so they can become QUERY / STOP after mapping.
        s = mapTokens(s) { token in
            var lead = ""
            var trail = ""
            var core = token
            while let first = core.first, "\"'([{".contains(first) {
                lead.append(first)
                core.removeFirst()
            }
            while let last = core.last, ".,;:!?)]}\"'".contains(last) {
                trail.insert(last, at: trail.startIndex)
                core.removeLast()
            }
            guard !core.isEmpty else {
                // Pure punctuation token
                return token
            }

            let lower = core.lowercased()

            // Keep STOP/QUERY/etc already injected.
            let reserved = ["STOP", "QUERY", "COMMA", "DASH", "QUOTE", "UNQUOTE", "PAREN", "UNPAREN", "OK"]
            if reserved.contains(core.uppercased()) {
                return core.uppercased() + trail
            }

            let mappedCore: String
            if let mapped = periodWords.first(where: { $0.0 == lower })?.1 {
                mappedCore = mapped.uppercased()
            } else if dropWords.contains(lower) {
                return trail.contains("?") ? "?" : (trail.contains("!") ? "!" : "")
            } else if ["is", "are", "was", "were", "be", "been", "being", "am"].contains(lower) {
                return trail.contains("?") ? "?" : (trail.contains("!") ? "!" : "")
            } else {
                mappedCore = core.uppercased()
            }

            // Rebuild trail as space-separated marks so QUERY/STOP substitution works.
            var marks = ""
            if trail.contains("?") { marks += " ?" }
            else if trail.contains("!") { marks += " !" }
            if trail.contains(".") { marks += " ." }
            if trail.contains(",") { marks += " ," }
            if trail.contains(";") { marks += " ;" }
            if trail.contains(":") { marks += " :" }

            return mappedCore + marks
        }

        s = applySentenceStops(s)
        s = s.replacingOccurrences(of: "?", with: " QUERY")
        s = s.replacingOccurrences(of: "!", with: " STOP")
        // Commas became rare on the wire; when kept they were spelled.
        s = s.replacingOccurrences(of: ",", with: " COMMA ")
        s = s.replacingOccurrences(of: ";", with: " STOP ")
        s = s.replacingOccurrences(of: ":", with: " STOP ")
        s = s.replacingOccurrences(of: " - ", with: " DASH ")
        s = s.replacingOccurrences(of: "—", with: " DASH ")
        s = s.replacingOccurrences(of: "/", with: " ")
        s = s.replacingOccurrences(of: "&", with: " AND ")
        s = s.replacingOccurrences(of: "@", with: " AT ")
        s = s.replacingOccurrences(of: "#", with: " NR ")
        s = s.replacingOccurrences(of: "$", with: " DOLS ")
        s = s.replacingOccurrences(of: "%", with: " PCT ")

        // Strip leftover non-wire punctuation except we already handled.
        s = s.unicodeScalars.map { sc -> String in
            let c = Character(sc)
            if c.isLetter || c.isNumber || c.isWhitespace { return String(c) }
            if ".'".contains(c) { return "" } // apostrophes out; decimals already handled in STOP pass
            return " "
        }.joined()

        s = finalizeWire(s)

        // Collapse repeated STOP / QUERY
        while s.contains("STOP STOP") {
            s = s.replacingOccurrences(of: "STOP STOP", with: "STOP")
        }
        while s.contains("QUERY QUERY") {
            s = s.replacingOccurrences(of: "QUERY QUERY", with: "QUERY")
        }
        while s.contains("COMMA COMMA") {
            s = s.replacingOccurrences(of: "COMMA COMMA", with: "COMMA")
        }

        return s
    }

    // MARK: - Shared helpers

    private static func collapseProse(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return s
    }

    private static func finalizeWire(_ input: String) -> String {
        var s = input
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        if !s.isEmpty, !s.hasSuffix("STOP"), !s.hasSuffix("QUERY") {
            s += " STOP"
        }
        return s
    }

    private static func applySentenceStops(_ input: String) -> String {
        var out = ""
        let chars = Array(input)
        for i in chars.indices {
            let c = chars[i]
            if c == "." {
                let prevDigit = i > 0 && chars[i - 1].isNumber
                let nextDigit = i + 1 < chars.count && chars[i + 1].isNumber
                out += (prevDigit && nextDigit) ? "." : " STOP "
            } else {
                out.append(c)
            }
        }
        return out
    }

    private static func encodeQuotes(_ text: String) -> String {
        var result = ""
        var inQuote = false
        for c in text {
            if c == "\"" {
                result += inQuote ? " UNQUOTE " : " QUOTE "
                inQuote.toggle()
            } else {
                result.append(c)
            }
        }
        if inQuote { result += " UNQUOTE " }
        return result
    }

    private static func encodeParens(_ text: String) -> String {
        text
            .replacingOccurrences(of: "(", with: " PAREN ")
            .replacingOccurrences(of: ")", with: " UNPAREN ")
            .replacingOccurrences(of: "[", with: " PAREN ")
            .replacingOccurrences(of: "]", with: " UNPAREN ")
    }

    private static func mapTokens(_ text: String, transform: (String) -> String) -> String {
        // Split on whitespace; punctuation sticks to tokens lightly via separate pass.
        let parts = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return parts.map(transform).filter { !$0.isEmpty }.joined(separator: " ")
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
