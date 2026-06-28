//
//  CodeExport.swift
//  InspireCreativityApp
//
//  Code-egress plumbing: getting an animation's Swift source out of the app
//  as a real `.swift` file, as import-stripped clipboard text.
//  Cross-platform (Foundation / CoreTransferable / UniformTypeIdentifiers).
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────
// MARK: SwiftSnippet — a shareable / draggable .swift file
// MARK: ─────────────────────────────────────────────────────────────

/// One animation's Swift source as a transferable file. Conforming to
/// `Transferable` lets `ShareLink` and `.draggable` hand the system a genuine
/// `Foo.swift` (attachable in Mail/AirDrop, savable to Files, droppable into
/// Xcode on iPad/Mac), with a plain-text fallback for text drop targets.
struct SwiftSnippet: Codable, Sendable {
    /// File name including the `.swift` extension, e.g. "LiquidHeart.swift".
    let filename: String
    let source: String

    init(filename: String, source: String) {
        self.filename = filename
        self.source = source
    }

    /// Builds a snippet from a human display name, deriving a Swift-safe file
    /// name from it.
    init(displayName: String, source: String) {
        self.init(filename: SwiftSnippet.fileName(for: displayName), source: source)
    }

    /// Turns a display name into a Swift-safe file name: strips everything but
    /// letters and digits, falls back to "Animation" when nothing usable
    /// remains, and always appends ".swift".
    static func fileName(for displayName: String) -> String {
        let base = displayName.replacingOccurrences(
            of: "[^A-Za-z0-9]+", with: "", options: .regularExpression)
        return (base.isEmpty ? "Animation" : base) + ".swift"
    }
}

extension SwiftSnippet: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Preferred: a real .swift file (AirDrop, Files, drag into Xcode).
        FileRepresentation(exportedContentType: .swiftSource) { snippet in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(snippet.filename)
            try? FileManager.default.removeItem(at: url)
            try snippet.source.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
        // Fallback: plain text, so dropping onto a text field pastes the code.
        ProxyRepresentation(exporting: \.source)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: SwiftSource — pre-egress text transforms
// MARK: ─────────────────────────────────────────────────────────────

/// Pure helpers for massaging Swift source before it leaves the app.
enum SwiftSource {
    /// Drops the leading run of `import` lines (and the blank lines among/after
    /// them) so a snippet can be pasted into a file that already declares its
    /// imports. Source with no leading imports is returned unchanged.
    static func bodyWithoutImports(_ source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var start = 0
        while start < lines.count {
            let trimmed = lines[start].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("import ") || trimmed.isEmpty {
                start += 1
            } else {
                break
            }
        }
        return lines[start...].joined(separator: "\n")
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: SwiftFileDocument — FileDocument for .fileExporter
// MARK: ─────────────────────────────────────────────────────────────

/// Minimal `FileDocument` that holds Swift source text and writes it as a
/// `.swift` file. Used by `.fileExporter` in `MacDetailView`.
struct SwiftFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.swiftSource] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
