import UIKit

/// Clipboard helpers for copying exports as **files** (not raw text), so pasting
/// into Files / Mail / a chat app drops the `.md` file itself.
enum Clipboard {
    /// Put an existing file on the pasteboard as a file, keeping its name. Falls
    /// back to copying the text if a provider can't be made.
    static func copyFile(at url: URL) {
        if let provider = NSItemProvider(contentsOf: url) {
            UIPasteboard.general.setItemProviders([provider], localOnly: false, expirationDate: nil)
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            UIPasteboard.general.string = text
        }
    }

    /// Write `markdown` to a temp `.md` file named `name` and copy it as a file.
    static func copyMarkdownFile(_ markdown: String, name: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitize(name)).md")
        do {
            try markdown.data(using: .utf8)?.write(to: url, options: .atomic)
            copyFile(at: url)
        } catch {
            UIPasteboard.general.string = markdown   // last-resort fallback
        }
    }

    private static func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "AppleHealth-Export" : cleaned
    }
}
