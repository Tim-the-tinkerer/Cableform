import Foundation

/// Binary `.cblf` paper-telegram document.
enum CableformDocument {
    static let magic = Data("CBLF".utf8)
    static let version: UInt16 = 1
    /// Fixed header size: magic(4) + ver(2) + flags(2) + created(8) + 6×u32 lengths (24) = 40
    static let headerSize = 40

    static func isCableform(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4) == magic
    }

    /// Marketing version from the app bundle (`CFBundleShortVersionString`).
    static var appVersion: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !v.isEmpty {
            return v
        }
        return "unknown"
    }

    static func encode(_ model: TelegramModel) throws -> Data {
        let toD = Data(model.toAddress.utf8)
        let fromD = Data(model.fromName.utf8)
        let officeD = Data(model.office.utf8)
        let bodyD = Data(model.bodyText.utf8)
        let sourceD = Data(model.sourceText.utf8)

        var meta: [String: String] = [
            "wordCount": String(model.wordCount),
            "company": model.company,
            "notes": model.notes,
            "app": "Cableform",
            "appVersion": appVersion,
        ]
        if let check = model.paidCollect {
            meta["paidCollect"] = check.rawValue
        }
        let metaD = try JSONSerialization.data(withJSONObject: meta, options: [.sortedKeys])

        var flags: UInt16 = 0
        if model.useWireStyle { flags |= 1 }

        var out = Data()
        out.reserveCapacity(headerSize + toD.count + fromD.count + officeD.count
            + bodyD.count + sourceD.count + metaD.count)
        out.append(magic)
        out.appendUInt16LE(version)
        out.appendUInt16LE(flags)
        out.appendInt64LE(Int64(model.filed.timeIntervalSince1970))
        out.appendUInt32LE(UInt32(toD.count))
        out.appendUInt32LE(UInt32(fromD.count))
        out.appendUInt32LE(UInt32(officeD.count))
        out.appendUInt32LE(UInt32(bodyD.count))
        out.appendUInt32LE(UInt32(sourceD.count))
        out.appendUInt32LE(UInt32(metaD.count))
        out.append(toD)
        out.append(fromD)
        out.append(officeD)
        out.append(bodyD)
        out.append(sourceD)
        out.append(metaD)
        return out
    }

    static func decode(_ data: Data) throws -> TelegramModel {
        guard data.count >= headerSize else {
            throw CableformError.badDocument
        }
        guard isCableform(data) else {
            throw CableformError.badDocument
        }

        var o = 4
        let ver = data.readUInt16LE(at: &o)
        guard ver == 1 else {
            throw CableformError.badDocument
        }
        let flags = data.readUInt16LE(at: &o)
        let created = data.readInt64LE(at: &o)
        let toLen = Int(data.readUInt32LE(at: &o))
        let fromLen = Int(data.readUInt32LE(at: &o))
        let officeLen = Int(data.readUInt32LE(at: &o))
        let bodyLen = Int(data.readUInt32LE(at: &o))
        let sourceLen = Int(data.readUInt32LE(at: &o))
        let metaLen = Int(data.readUInt32LE(at: &o))

        // Reject absurd lengths (corrupt / non-cblf misread as binary)
        let payload = toLen + fromLen + officeLen + bodyLen + sourceLen + metaLen
        guard toLen >= 0, fromLen >= 0, officeLen >= 0, bodyLen >= 0,
              sourceLen >= 0, metaLen >= 0,
              data.count >= headerSize + payload
        else {
            throw CableformError.badDocument
        }

        func take(_ n: Int, field: String) throws -> String {
            let start = o
            let end = o + n
            o = end
            guard n > 0 else { return "" }
            let slice = data.subdata(in: start..<end)
            guard let s = String(data: slice, encoding: .utf8) else {
                throw CableformError.invalidUTF8(field: field)
            }
            return s
        }

        let to = try take(toLen, field: "to")
        let from = try take(fromLen, field: "from")
        let office = try take(officeLen, field: "office")
        let body = try take(bodyLen, field: "body")
        let source = try take(sourceLen, field: "source")
        let metaRaw = metaLen > 0 ? data.subdata(in: o..<(o + metaLen)) : Data()

        var model = TelegramModel()
        model.toAddress = to
        model.fromName = from
        model.office = office
        model.bodyText = body
        model.sourceText = source.isEmpty ? body : source
        model.useWireStyle = (flags & 1) != 0
        model.filed = Date(timeIntervalSince1970: TimeInterval(created))
        model.paidCollect = nil

        if !metaRaw.isEmpty {
            // Metadata is JSON UTF-8; reject binary corruption rather than ignoring it.
            guard String(data: metaRaw, encoding: .utf8) != nil else {
                throw CableformError.invalidUTF8(field: "metadata")
            }
            guard let obj = try? JSONSerialization.jsonObject(with: metaRaw) as? [String: Any] else {
                throw CableformError.badDocument
            }
            if let pc = obj["paidCollect"] as? String,
               let parsed = TelegramModel.PaidCollect(rawValue: pc) {
                model.paidCollect = parsed
            }
            model.company = obj["company"] as? String ?? model.company
            model.notes = obj["notes"] as? String ?? ""
        }
        return model
    }
}

// MARK: - Alignment-safe little-endian I/O

private extension Data {
    mutating func appendUInt16LE(_ v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ v: UInt32) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 24) & 0xFF))
    }

    mutating func appendInt64LE(_ v: Int64) {
        let u = UInt64(bitPattern: v)
        for i in 0..<8 {
            append(UInt8((u >> (i * 8)) & 0xFF))
        }
    }

    func readUInt16LE(at offset: inout Int) -> UInt16 {
        let v = UInt16(self[offset])
            | (UInt16(self[offset + 1]) << 8)
        offset += 2
        return v
    }

    func readUInt32LE(at offset: inout Int) -> UInt32 {
        let v = UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
        offset += 4
        return v
    }

    func readInt64LE(at offset: inout Int) -> Int64 {
        var u: UInt64 = 0
        for i in 0..<8 {
            u |= UInt64(self[offset + i]) << (i * 8)
        }
        offset += 8
        return Int64(bitPattern: u)
    }
}
