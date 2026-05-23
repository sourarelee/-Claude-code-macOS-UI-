import SwiftUI

struct MarkdownRenderer: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(parse(), id: \.id) { block in
                switch block {
                case .h1(let t): Text(inline(t)).font(.system(size: 17, weight: .semibold)).padding(.top, 8).padding(.bottom, 2)
                case .h2(let t): Text(inline(t)).font(.system(size: 15, weight: .semibold)).padding(.top, 6).padding(.bottom, 1)
                case .h3(let t): Text(inline(t)).font(.system(size: 14, weight: .medium)).padding(.top, 4)
                case .p(let t): Text(inline(t)).font(Design.Font.body).lineSpacing(2)
                case .bullet(let t): HStack(alignment: .top, spacing: 6) { Circle().fill(Color.primary.opacity(0.35)).frame(width: 4, height: 4).padding(.top, 7); Text(inline(t)).font(Design.Font.body) }
                case .num(let n, let t): HStack(alignment: .top, spacing: 6) { Text("\(n).").font(Design.Font.body).foregroundColor(.secondary); Text(inline(t)).font(Design.Font.body) }
                case .quote(let t): HStack(spacing: 0) { RoundedRectangle(cornerRadius: 1).fill(Design.Color.accent.opacity(0.4)).frame(width: 3); Text(inline(t)).font(Design.Font.body).foregroundColor(.secondary).italic().padding(.leading, 8) }
                case .code(let code, let lang):
                    VStack(spacing: 0) {
                        if !lang.isEmpty { HStack { Text(lang).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary.opacity(0.6)).padding(.horizontal, 10).padding(.vertical, 4); Spacer(); Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string) }) { Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5)) }.buttonStyle(.plain).padding(.trailing, 10) }; Divider().opacity(0.3) }
                        ScrollView(.horizontal, showsIndicators: false) { Text(code).font(Design.Font.code).foregroundColor(.primary.opacity(0.85)).padding(Design.Spacing.md) }
                    }.background(Design.Color.codeBg).clipShape(RoundedRectangle(cornerRadius: Design.Radius.sm)).padding(.vertical, 4)
                case .div: Divider().opacity(0.3).padding(.vertical, 4)
                case .empty: Color.clear.frame(height: 4)
                }
            }
        }
    }

    private func inline(_ text: String) -> AttributedString {
        var r = AttributedString(); var rem = text[...]
        while !rem.isEmpty {
            if let br = rem.firstRange(of: /\*\*(.+?)\*\*/) {
                if br.lowerBound > rem.startIndex { r.append(AttributedString(String(rem[rem.startIndex..<br.lowerBound]))) }
                var a = AttributedString(String(rem[br].dropFirst(2).dropLast(2))); a.font = .system(size: 13.5, weight: .semibold); r.append(a)
                rem = rem[br.upperBound...]
            } else if let ir = rem.firstRange(of: /\*(.+?)\*/) {
                if ir.lowerBound > rem.startIndex { r.append(AttributedString(String(rem[rem.startIndex..<ir.lowerBound]))) }
                var a = AttributedString(String(rem[ir].dropFirst().dropLast())); a.font = .system(size: 13.5).italic(); r.append(a)
                rem = rem[ir.upperBound...]
            } else if let cr = rem.firstRange(of: /`(.+?)`/) {
                if cr.lowerBound > rem.startIndex { r.append(AttributedString(String(rem[rem.startIndex..<cr.lowerBound]))) }
                var a = AttributedString(String(rem[cr].dropFirst().dropLast())); a.font = Design.Font.code; a.backgroundColor = Color.primary.opacity(0.06); r.append(a)
                rem = rem[cr.upperBound...]
            } else if let lr = rem.firstRange(of: /\[(.+?)\]\((.+?)\)/) {
                if lr.lowerBound > rem.startIndex { r.append(AttributedString(String(rem[rem.startIndex..<lr.lowerBound]))) }
                let parts = String(rem[lr].dropFirst().dropLast()).components(separatedBy: "](")
                var a = AttributedString(parts.first ?? ""); a.foregroundColor = Design.Color.accent; a.underlineStyle = .single; r.append(a)
                rem = rem[lr.upperBound...]
            } else { r.append(AttributedString(String(rem))); break }
        }
        if r.characters.isEmpty { r = AttributedString(text) }; r.font = .system(size: 13.5); return r
    }

    private func parse() -> [Block] {
        let lines = text.components(separatedBy: "\n"); var blocks: [Block] = []; var codeLines: [String] = []; var inCode = false; var codeLang = ""
        for line in lines {
            if line.hasPrefix("```") {
                if inCode { blocks.append(.code(codeLines.joined(separator: "\n"), codeLang)); codeLines = []; inCode = false; codeLang = "" }
                else { codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces); inCode = true }
            } else if inCode { codeLines.append(line) }
            else if line.hasPrefix("# ") { blocks.append(.h1(String(line.dropFirst(2)))) }
            else if line.hasPrefix("## ") { blocks.append(.h2(String(line.dropFirst(3)))) }
            else if line.hasPrefix("### ") { blocks.append(.h3(String(line.dropFirst(4)))) }
            else if line.hasPrefix("> ") { blocks.append(.quote(String(line.dropFirst(2)))) }
            else if line.hasPrefix("- ") || line.hasPrefix("* ") { blocks.append(.bullet(String(line.dropFirst(2)))) }
            else if let m = line.wholeMatch(of: /^(\d+)\.\s(.+)/) { blocks.append(.num(Int(m.1) ?? 0, String(m.2))) }
            else if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") { blocks.append(.div) }
            else if line.trimmingCharacters(in: .whitespaces).isEmpty { blocks.append(.empty) }
            else { blocks.append(.p(line)) }
        }
        if inCode, !codeLines.isEmpty { blocks.append(.code(codeLines.joined(separator: "\n"), codeLang)) }
        return blocks
    }
}

private enum Block: Identifiable {
    case h1(String), h2(String), h3(String), p(String), bullet(String), num(Int, String), quote(String), code(String, String), div, empty
    var id: String {
        switch self {
        case .h1(let t): "h1-\(t.hashValue)"
        case .h2(let t): "h2-\(t.hashValue)"
        case .h3(let t): "h3-\(t.hashValue)"
        case .p(let t): "p-\(t.hashValue)"
        case .bullet(let t): "b-\(t.hashValue)"
        case .num(let n, let t): "n\(n)-\(t.hashValue)"
        case .quote(let t): "q-\(t.hashValue)"
        case .code(let c, let l): "cb-\(c.hashValue)-\(l)"
        case .div: "div-\(UUID())"
        case .empty: "e-\(UUID())"
        }
    }
}
