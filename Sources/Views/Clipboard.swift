import UIKit
import UniformTypeIdentifiers

/// Clipboard helpers for copying an export as a **file** (markdown / PDF / CSV),
/// so pasting into a file-aware app (Files, Mail, and chat apps that accept the
/// type — e.g. PDF in ChatGPT/Claude) attaches the file itself.
///
/// Caveat: a plain text input always extracts text from the pasteboard, no
/// matter what we register — that's the destination app's choice. PDF is the
/// one type a text-only composer can't read as text, so it's the best bet for
/// "paste as a file".
enum Clipboard {
    /// Register a single data representation under `type` with a filename. We do
    /// NOT expose a `file://` URL — some apps paste that as a path string.
    static func copy(_ data: Data, name: String, type: UTType) {
        let provider = NSItemProvider()
        provider.suggestedName = sanitize(name)
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        UIPasteboard.general.setItemProviders([provider], localOnly: false, expirationDate: nil)
    }

    static func copyMarkdownFile(_ markdown: String, name: String) {
        copy(Data(markdown.utf8), name: name, type: UTType(filenameExtension: "md") ?? .plainText)
    }

    static func copyCSV(_ csv: String, name: String) {
        copy(Data(csv.utf8), name: name, type: .commaSeparatedText)
    }

    static func copyPDF(_ data: Data, name: String) {
        copy(data, name: name, type: .pdf)
    }

    private static func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "AppleHealth-Export" : cleaned
    }
}

/// Renders an export into alternate file formats (PDF, CSV) for the copy menu.
enum ExportFormats {
    /// Paginate plain text into a US-Letter PDF (monospace). Heavy for very large
    /// exports — call off the main thread.
    static func pdf(fromText text: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter @72dpi
        let margin: CGFloat = 36
        let printable = page.insetBy(dx: margin, dy: margin)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.black,
        ]
        let formatter = UISimpleTextPrintFormatter(attributedText: NSAttributedString(string: text, attributes: attrs))
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let out = NSMutableData()
        UIGraphicsBeginPDFContextToData(out, page, nil)
        let pages = max(renderer.numberOfPages, 1)
        for i in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return out as Data
    }

    /// Extract markdown table rows (`| a | b |`) into CSV. When there are no
    /// tables, fall back to one cell per non-empty line so the file isn't empty.
    static func csv(fromMarkdown markdown: String) -> String {
        var rows: [String] = []
        var sawTable = false
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("|") else { continue }
            var cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first == "" { cells.removeFirst() }   // outer pipes
            if cells.last == "" { cells.removeLast() }
            // Skip the |---|---| separator row.
            if cells.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 == "-" || $0 == ":" } }) { continue }
            sawTable = true
            rows.append(cells.map(escapeCSV).joined(separator: ","))
        }
        if !sawTable {
            rows = markdown.split(separator: "\n").map { escapeCSV(String($0)) }
        }
        return rows.joined(separator: "\n")
    }

    private static func escapeCSV(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
