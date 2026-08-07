import AppKit
import Foundation

/// Draws a physical-style telegram blank to an `NSImage` / PNG.
enum PaperRenderer {

    static func image(for model: TelegramModel, width: CGFloat = 850) -> NSImage {
        let margin: CGFloat = 36
        let contentW = width - margin * 2

        let paper = NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.80, alpha: 1)
        let ink = NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1)
        let crimson = NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.12, alpha: 1)
        let muted = NSColor(calibratedRed: 0.38, green: 0.30, blue: 0.22, alpha: 1)
        let lineBlue = NSColor(calibratedRed: 0.25, green: 0.32, blue: 0.55, alpha: 0.35)

        let companyFont = NSFont(name: "Copperplate", size: 22)
            ?? NSFont.systemFont(ofSize: 22, weight: .bold)
        let labelFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
        let fieldFont = NSFont(name: "American Typewriter", size: 14)
            ?? NSFont.systemFont(ofSize: 14)
        let bodyFont = NSFont(name: "American Typewriter", size: 15)
            ?? NSFont.systemFont(ofSize: 15)
        let footerFont = NSFont.systemFont(ofSize: 9, weight: .regular)

        let body = model.bodyText.isEmpty ? " " : model.bodyText
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: ink,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.lineSpacing = 10
                p.paragraphSpacing = 4
                return p
            }(),
        ]
        let bodyAttr = NSAttributedString(string: body, attributes: bodyAttrs)
        let bodyBounds = bodyAttr.boundingRect(
            with: NSSize(width: contentW - 8, height: 20_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        // Ruled lines: at least 8 lines of message space
        let linePitch: CGFloat = 28
        let minBodyH = linePitch * 8
        let bodyH = max(minBodyH, ceil(bodyBounds.height) + 16)

        let headerBlock: CGFloat = 130
        let metaBlock: CGFloat = 100
        let footerBlock: CGFloat = 40
        let height = margin + headerBlock + metaBlock + 24 + bodyH + footerBlock + margin

        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        // Paper
        paper.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        // Soft edge shadow strip (left stub perforation look)
        let stubW: CGFloat = 18
        NSColor(calibratedRed: 0.90, green: 0.84, blue: 0.70, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: stubW, height: height)).fill()
        muted.withAlphaComponent(0.25).setFill()
        var py: CGFloat = 12
        while py < height {
            NSBezierPath(ovalIn: NSRect(x: 5, y: py, width: 8, height: 8)).fill()
            py += 22
        }

        // Outer frame
        crimson.setStroke()
        let frame = NSBezierPath(rect: NSRect(x: stubW + 10, y: 14, width: width - stubW - 24, height: height - 28))
        frame.lineWidth = 2.2
        frame.stroke()
        let inner = NSBezierPath(rect: NSRect(x: stubW + 16, y: 20, width: width - stubW - 36, height: height - 40))
        inner.lineWidth = 0.7
        inner.stroke()

        let left = stubW + margin
        let usableW = width - left - margin
        var y = height - margin - 4

        // Company banner
        crimson.setFill()
        NSBezierPath(rect: NSRect(x: left, y: y - 34, width: usableW, height: 34)).fill()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: companyFont,
            .foregroundColor: NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.88, alpha: 1),
        ]
        let company = model.company.uppercased()
        let cSize = company.size(withAttributes: titleAttrs)
        company.draw(at: NSPoint(x: left + (usableW - cSize.width) / 2, y: y - 28), withAttributes: titleAttrs)
        y -= 42

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: muted,
        ]
        let sub = "CABLE · TELEGRAM · NIGHT LETTER  ·  DELIVERED ON PAPER"
        let sSize = sub.size(withAttributes: subAttrs)
        sub.draw(at: NSPoint(x: left + (usableW - sSize.width) / 2, y: y - 12), withAttributes: subAttrs)
        y -= 26

        rule(from: NSPoint(x: left, y: y), to: NSPoint(x: left + usableW, y: y), color: crimson)
        y -= 18

        let labAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: muted]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: fieldFont, .foregroundColor: ink]

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let filedStr = df.string(from: model.filed)

        // Row 1: DATE / WORDS / optional CHECK
        drawLabeledField("DATE FILED", filedStr, x: left, y: y, lab: labAttrs, val: valAttrs)
        drawLabeledField("WORDS", "\(model.wordCount)", x: left + usableW * 0.42, y: y, lab: labAttrs, val: valAttrs)
        if let check = model.paidCollect {
            drawLabeledField("CHECK", check.rawValue, x: left + usableW * 0.68, y: y, lab: labAttrs, val: valAttrs)
        }
        y -= 44

        // Row 2: TO
        drawLabeledField("TO", model.toAddress.isEmpty ? "—" : model.toAddress, x: left, y: y, lab: labAttrs, val: valAttrs, width: usableW)
        y -= 40

        // Row 3: FROM / OFFICE
        drawLabeledField("FROM", model.fromName.isEmpty ? "—" : model.fromName, x: left, y: y, lab: labAttrs, val: valAttrs)
        drawLabeledField("OFFICE", model.office.isEmpty ? "—" : model.office, x: left + usableW * 0.52, y: y, lab: labAttrs, val: valAttrs)
        y -= 36

        rule(from: NSPoint(x: left, y: y), to: NSPoint(x: left + usableW, y: y), color: crimson.withAlphaComponent(0.7))
        y -= 14

        "MESSAGE".draw(at: NSPoint(x: left, y: y - 10), withAttributes: labAttrs)
        y -= 18

        // Ruled message area
        let bodyTop = y
        let bodyRect = NSRect(x: left, y: bodyTop - bodyH, width: usableW, height: bodyH)
        lineBlue.setStroke()
        var ly = bodyRect.maxY - linePitch
        while ly >= bodyRect.minY {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bodyRect.minX, y: ly))
            path.line(to: NSPoint(x: bodyRect.maxX, y: ly))
            path.lineWidth = 0.8
            path.stroke()
            ly -= linePitch
        }

        // Body text sitting on the lines
        let textRect = NSRect(
            x: bodyRect.minX + 4,
            y: bodyRect.minY + 4,
            width: bodyRect.width - 8,
            height: bodyRect.height - 6
        )
        bodyAttr.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

        y = bodyRect.minY - 16
        rule(from: NSPoint(x: left, y: y), to: NSPoint(x: left + usableW, y: y), color: crimson.withAlphaComponent(0.5))
        y -= 16

        let foot = "This form is a paper record of a cable / telegraph message · Cableform"
        let footAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: muted.withAlphaComponent(0.9),
        ]
        let fSize = foot.size(withAttributes: footAttrs)
        foot.draw(
            at: NSPoint(x: left + (usableW - fSize.width) / 2, y: max(24, y - 6)),
            withAttributes: footAttrs
        )

        image.unlockFocus()
        return image
    }

    static func pngData(for model: TelegramModel) -> Data? {
        let img = image(for: model)
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func drawLabeledField(
        _ label: String,
        _ value: String,
        x: CGFloat,
        y: CGFloat,
        lab: [NSAttributedString.Key: Any],
        val: [NSAttributedString.Key: Any],
        width: CGFloat = 220
    ) {
        label.draw(at: NSPoint(x: x, y: y), withAttributes: lab)
        let v = value
        // Underline for fill-in look
        let vSize = v.size(withAttributes: val)
        v.draw(at: NSPoint(x: x, y: y - 20), withAttributes: val)
        NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.12, alpha: 0.35).setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: y - 24))
        path.line(to: NSPoint(x: x + max(width * 0.9, vSize.width + 40), y: y - 24))
        path.lineWidth = 0.6
        path.stroke()
    }

    private static func rule(from: NSPoint, to: NSPoint, color: NSColor) {
        color.setStroke()
        let p = NSBezierPath()
        p.move(to: from)
        p.line(to: to)
        p.lineWidth = 1
        p.stroke()
    }
}
