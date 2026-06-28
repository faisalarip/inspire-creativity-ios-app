//
//  SwiftCodeView.swift
//  InspireCreativityApp
//
//  Lightweight syntax-highlighted code viewer. Not a full lexer — just
//  matches keywords, strings, and comments to look like Xcode dark mode.
//

import SwiftUI

struct SwiftCodeView: View {

    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(source.split(separator: "\n",
                                       omittingEmptySubsequences: false).enumerated()),
                    id: \.offset) { idx, line in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(Theme.Typo.mono(11))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(width: 26, alignment: .trailing)
                    highlight(String(line))
                        .font(Theme.Typo.mono(12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
    }

    /// Minimal token coloring. Stops at `//` comments and `"…"` strings.
    private func highlight(_ line: String) -> Text {
        // Comment detection — anything after `//` (not in a string) is a comment.
        if let range = line.range(of: "//") {
            let head = String(line[line.startIndex..<range.lowerBound])
            let tail = String(line[range.lowerBound...])
            return highlightCode(head) +
                Text(tail).foregroundColor(Color(white: 0.45))
        }
        return highlightCode(line)
    }

    private func highlightCode(_ s: String) -> Text {
        let keywords: Set<String> = [
            "import", "struct", "class", "enum", "func", "var", "let", "if", "else",
            "switch", "case", "for", "in", "return", "self", "super", "guard", "while",
            "do", "try", "throws", "async", "await", "private", "public", "internal",
            "static", "extension", "protocol", "typealias", "init", "where", "as", "is",
            "@State", "@Binding", "@Published", "@MainActor", "@StateObject",
            "@ObservedObject", "@EnvironmentObject", "@ViewBuilder", "@available"
        ]
        let types: Set<String> = [
            "View", "Color", "Image", "Text", "VStack", "HStack", "ZStack",
            "Button", "Circle", "Rectangle", "Capsule", "RoundedRectangle",
            "LinearGradient", "RadialGradient", "AngularGradient", "MeshGradient",
            "ForEach", "Path", "Shape", "ViewModifier", "Animation", "State", "Binding",
            "GeometryReader", "ScrollView", "NavigationStack", "EmptyView", "Spacer",
            "Group", "Double", "Int", "CGFloat", "String", "Bool", "Array",
            "Namespace", "CGSize", "CGPoint", "CGRect"
        ]
        // Tokenize crudely: split on whitespace + punctuation borders, keep separators.
        var result = Text("")
        var current = ""
        var inString = false
        var stringBuf = ""
        for ch in s {
            if ch == "\"" {
                if inString {
                    stringBuf.append(ch)
                    result = result + Text(stringBuf).foregroundColor(Color(red: 0.98, green: 0.6, blue: 0.4))
                    stringBuf = ""
                    inString = false
                } else {
                    if !current.isEmpty {
                        result = result + colorize(token: current, keywords: keywords, types: types)
                        current = ""
                    }
                    stringBuf.append(ch)
                    inString = true
                }
                continue
            }
            if inString {
                stringBuf.append(ch)
                continue
            }
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "@" || ch == "." {
                current.append(ch)
            } else {
                if !current.isEmpty {
                    result = result + colorize(token: current, keywords: keywords, types: types)
                    current = ""
                }
                result = result + Text(String(ch)).foregroundColor(.white.opacity(0.85))
            }
        }
        if !current.isEmpty {
            result = result + colorize(token: current, keywords: keywords, types: types)
        }
        if !stringBuf.isEmpty {
            result = result + Text(stringBuf).foregroundColor(Color(red: 0.98, green: 0.6, blue: 0.4))
        }
        return result
    }

    private func colorize(token: String, keywords: Set<String>, types: Set<String>) -> Text {
        if keywords.contains(token) {
            return Text(token).foregroundColor(Color(red: 0.96, green: 0.4, blue: 0.65))
        }
        if types.contains(token) || (token.first?.isUppercase ?? false) {
            return Text(token).foregroundColor(Color(red: 0.5, green: 0.85, blue: 1.0))
        }
        if Double(token) != nil {
            return Text(token).foregroundColor(Color(red: 0.85, green: 0.85, blue: 1.0))
        }
        return Text(token).foregroundColor(.white.opacity(0.9))
    }
}
