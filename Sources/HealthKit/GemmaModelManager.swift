import Foundation
import Combine

/// Manages the optional on-device Gemma model: choosing a size, downloading it
/// with progress, and reporting readiness. The actual inference binding
/// (MediaPipe LLM Inference / MLX) is wired separately once the dependency is
/// added to the project — see `GemmaEngine` note. Until then this manages the
/// real file lifecycle so the download UX is genuine, not faked.
@MainActor
final class GemmaModelManager: ObservableObject {

    enum Variant: String, CaseIterable, Identifiable {
        case e2b, e4b
        var id: String { rawValue }
        var title: String { self == .e2b ? "Gemma 3n E2B" : "Gemma 3n E4B" }
        var sizeText: String { self == .e2b ? "≈ 3.1 GB" : "≈ 4.4 GB" }
        var blurb: String {
            self == .e2b
            ? "Recommended. Runs reliably on-device — good answers, fits in memory."
            : "Experimental. Sharper answers, but ~4.4 GB may hit iOS memory limits and crash on some devices."
        }
        /// Hugging Face download URL for the MediaPipe .task (int4) file.
        var downloadURL: URL {
            URL(string: "https://huggingface.co/google/gemma-3n-\(self == .e2b ? "E2B" : "E4B")-it-litert-preview/resolve/main/gemma-3n-\(self == .e2b ? "E2B" : "E4B")-it-int4.task")!
        }
    }

    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .notDownloaded
    @Published var selectedVariant: Variant = .e2b

    private let fm = FileManager.default
    private var downloadTask: Task<Void, Never>?
    private let tokenKey = "hfToken"

    /// Hugging Face access token (Gemma repos are license-gated). Stored on
    /// device only; never committed or transmitted anywhere but Hugging Face.
    var hfToken: String {
        get { UserDefaults.standard.string(forKey: tokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey); objectWillChange.send() }
    }
    var hasToken: Bool { !hfToken.trimmingCharacters(in: .whitespaces).isEmpty }

    private var dir: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("Models", isDirectory: true)
        if !fm.fileExists(atPath: d.path) {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    func modelURL(for v: Variant) -> URL { dir.appendingPathComponent("gemma-\(v.rawValue).task") }

    var isReady: Bool { if case .ready = state { return true }; return false }

    init() { refreshState() }

    func refreshState() {
        if fm.fileExists(atPath: modelURL(for: selectedVariant).path) {
            state = .ready
        } else {
            state = .notDownloaded
        }
    }

    /// Begin downloading the selected variant from Hugging Face using the saved
    /// token (the Gemma repos are license-gated).
    func download() {
        guard !isReady else { return }
        guard hasToken else {
            state = .failed("Add your Hugging Face token first (the Gemma model is license-gated).")
            return
        }
        state = .downloading(progress: 0)
        downloadTask?.cancel()
        let variant = selectedVariant
        let token = hfToken
        downloadTask = Task { await runDownload(url: variant.downloadURL, token: token) }
    }

    func cancel() {
        downloadTask?.cancel()
        refreshState()
    }

    func delete() {
        try? fm.removeItem(at: modelURL(for: selectedVariant))
        refreshState()
    }

    private func runDownload(url: URL, token: String) async {
        let dest = modelURL(for: selectedVariant)
        let tmp = dest.appendingPathExtension("part")
        do {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                state = .failed(http.statusCode == 401 || http.statusCode == 403
                    ? "Access denied (\(http.statusCode)). Check your token and that you've accepted the Gemma license on Hugging Face."
                    : "Download failed (HTTP \(http.statusCode)).")
                return
            }

            let total = response.expectedContentLength
            // Stream to a file handle (multi-GB — never hold it all in memory).
            fm.createFile(atPath: tmp.path, contents: nil)
            let handle = try FileHandle(forWritingTo: tmp)
            defer { try? handle.close() }

            var received: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(1 << 20)
            var lastReported = 0.0
            for try await byte in bytes {
                buffer.append(byte)
                received += 1
                if buffer.count >= (1 << 20) {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    if total > 0 {
                        let p = Double(received) / Double(total)
                        if p - lastReported >= 0.005 { lastReported = p; state = .downloading(progress: p) }
                    }
                }
            }
            if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
            try handle.close()
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tmp, to: dest)
            state = .ready
        } catch is CancellationError {
            try? fm.removeItem(at: tmp)
            refreshState()
        } catch {
            try? fm.removeItem(at: tmp)
            state = .failed("Download failed: \(error.localizedDescription)")
        }
    }

    /// A ready engine for the downloaded model, or nil if not downloaded.
    func makeEngine() -> LLMEngine? {
        guard isReady else { return nil }
        return GemmaEngine(modelPath: modelURL(for: selectedVariant).path, displayName: selectedVariant.title)
    }
}
