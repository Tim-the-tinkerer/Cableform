import SwiftUI

/// On-screen paper blank that mirrors the PNG export layout.
struct PaperPreview: View {
    let model: TelegramModel

    private let paper = Color(red: 0.97, green: 0.93, blue: 0.80)
    private let crimson = Color(red: 0.55, green: 0.12, blue: 0.12)
    private let muted = Color(red: 0.38, green: 0.30, blue: 0.22)
    private let ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    private let stub = Color(red: 0.90, green: 0.84, blue: 0.70)
    private let ruleBlue = Color(red: 0.25, green: 0.32, blue: 0.55).opacity(0.35)

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, 720)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                paperSheet(width: w)
                    .frame(width: w)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func paperSheet(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Perforated stub
            ZStack {
                stub
                VStack(spacing: 14) {
                    ForEach(0..<18, id: \.self) { _ in
                        Circle()
                            .fill(muted.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                // Banner
                Text(model.company.uppercased())
                    .font(.custom("Copperplate", size: 18))
                    .foregroundStyle(Color(red: 0.99, green: 0.95, blue: 0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(crimson)

                Text("CABLE · TELEGRAM · NIGHT LETTER  ·  DELIVERED ON PAPER")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Rectangle().fill(crimson).frame(height: 1)

                metaGrid
                    .padding(.top, 12)

                Rectangle().fill(crimson.opacity(0.7)).frame(height: 1)
                    .padding(.top, 10)

                Text("MESSAGE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(muted)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ruledBody

                Rectangle().fill(crimson.opacity(0.5)).frame(height: 1)
                    .padding(.top, 12)

                Text("This form is a paper record of a cable / telegraph message · Cableform")
                    .font(.system(size: 9))
                    .foregroundStyle(muted.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(paper)
        .overlay(
            RoundedRectangle(cornerRadius: 1)
                .stroke(crimson, lineWidth: 2)
                .padding(6)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(12)
    }

    private var metaGrid: some View {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                field("DATE FILED", df.string(from: model.filed))
                field("WORDS", "\(model.wordCount)")
                if let check = model.paidCollect {
                    field("CHECK", check.rawValue)
                }
            }
            field("TO", model.toAddress.isEmpty ? "—" : model.toAddress)
            HStack(alignment: .top, spacing: 16) {
                field("FROM", model.fromName.isEmpty ? "—" : model.fromName)
                field("OFFICE", model.office.isEmpty ? "—" : model.office)
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(muted)
            Text(value)
                .font(.custom("American Typewriter", size: 13))
                .foregroundStyle(ink)
                .lineLimit(3)
            Rectangle()
                .fill(crimson.opacity(0.35))
                .frame(height: 0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ruledBody: some View {
        let lines = max(8, lineCount(for: model.bodyText))
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<lines, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(ruleBlue)
                            .frame(height: 1)
                    }
                    .frame(height: 26)
                }
            }
            Text(model.bodyText.isEmpty ? " " : model.bodyText)
                .font(.custom("American Typewriter", size: 14))
                .foregroundStyle(ink)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.top, 2)
        }
    }

    private func lineCount(for text: String) -> Int {
        let chars = max(text.count, 1)
        // rough wrap estimate for ~55 chars/line
        return max(8, Int(ceil(Double(chars) / 55.0)) + text.filter { $0 == "\n" }.count)
    }
}
