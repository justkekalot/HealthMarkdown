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
    private var downloader: ModelDownloader?
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
    /// token (the Gemma repos are license-gated). Uses a URLSessionDownloadTask
    /// (native chunked streaming to disk + real progress) — NOT a byte-by-byte
    /// async loop, which was glacially slow for multi-GB files.
    func download() {
        guard !isReady else { return }
        guard hasToken else {
            state = .failed("Add your Hugging Face token first (the Gemma model is license-gated).")
            return
        }
        state = .downloading(progress: 0)
        let dest = modelURL(for: selectedVariant)
        downloader = ModelDownloader(
            url: selectedVariant.downloadURL,
            token: hfToken,
            destination: dest,
            onProgress: { [weak self] p in
                Task { @MainActor in self?.state = .downloading(progress: p) }
            },
            onFinish: { [weak self] errorMessage in
                Task { @MainActor in
                    guard let self else { return }
                    self.state = errorMessage.map { .failed($0) } ?? .ready
                    self.downloader = nil
                }
            }
        )
        downloader?.start()
    }

    func cancel() {
        downloader?.cancel()
        downloader = nil
        refreshState()
    }

    func delete() {
        try? fm.removeItem(at: modelURL(for: selectedVariant))
        refreshState()
    }

    /// A ready engine for the downloaded model, or nil if not downloaded.
    func makeEngine() -> LLMEngine? {
        guard isReady else { return nil }
        return GemmaEngine(modelPath: modelURL(for: selectedVariant).path, displayName: selectedVariant.title)
    }
}
