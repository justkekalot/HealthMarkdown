import UIKit
import UniformTypeIdentifiers

/// Clipboard helpers for copying an export as a **file** (not raw text and not a
/// file path), so pasting into Files / Mail / Messages / a chat app attaches the
/// `.md` file itself.
enum Clipboard {
    /// Put the markdown on the pasteboard as a named file. We register a *data*
    /// representation under the markdown UTI plus a suggested filename — and
    /// deliberately do NOT expose a `file://` URL, because some apps paste that
    /// URL as a path string instead of attaching the file.
    static func copyMarkdownFile(_ markdown: String, name: String) {
        let data = Data(markdown.utf8)
        let type = UTType(filenameExtension: "md") ?? .plainText
        let provider = NSItemProvider()
        provider.suggestedName = sanitize(name)
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        UIPasteboard.general.setItemProviders([provider], localOnly: false, expirationDate: nil)
    }

    private static func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "AppleHealth-Export" : cleaned
    }
}
