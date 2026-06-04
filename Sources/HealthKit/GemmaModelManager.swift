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
        var title: String {
            switch self {
            case .e2b: return "Gemma 4 E2B"
            case .e4b: return "Gemma 4 E4B"
            }
        }
        var sizeText: String {
            switch self {
            case .e2b: return "≈ 2.6 GB"
            case .e4b: return "≈ 3.7 GB"
            }
        }
        var blurb: String {
            switch self {
            case .e2b: return "Recommended. Google's latest small on-device model — the same one AI Edge Gallery uses. Capable and reasonably quick."
            case .e4b: return "Larger & sharper. More capable answers, needs more space and a bit more time per reply."
            }
        }
        var rawTag: String { self == .e2b ? "E2B" : "E4B" }

        /// Hugging Face download URL for the LiteRT-LM .litertlm file.
        var downloadURL: URL {
            URL(string: "https://huggingface.co/litert-community/gemma-4-\(rawTag)-it-litert-lm/resolve/main/gemma-4-\(rawTag)-it.litertlm")!
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

    private var dir: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("Models", isDirectory: true)
        if !fm.fileExists(atPath: d.path) {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    func modelURL(for v: Variant) -> URL { dir.appendingPathComponent("gemma-4-\(v.rawValue).litertlm") }

    var isReady: Bool { if case .ready = state { return true }; return false }

    init() {
        // Default to whichever variant is actually downloaded (the user may have
        // E4B even though E2B is the nominal default) so the model is selected
        // automatically instead of falling back to the built-in engine.
        if let downloaded = Variant.allCases.first(where: { fm.fileExists(atPath: modelURL(for: $0).path) }) {
            selectedVariant = downloaded
        }
        refreshState()
    }

    func refreshState() {
        if fm.fileExists(atPath: modelURL(for: selectedVariant).path) {
            state = .ready
        } else {
            state = .notDownloaded
        }
    }

    /// Begin downloading the selected variant from Hugging Face. The
    /// litert-community Gemma 4 repos are public — no token, account, or license
    /// gate — so this is a plain unauthenticated download. Uses a background
    /// URLSession so the multi-GB download survives screen lock.
    func download() {
        guard !isReady else { return }
        state = .downloading(progress: 0)
        let dest = modelURL(for: selectedVariant)
        downloader = ModelDownloader(
            url: selectedVariant.downloadURL,
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
        releaseEngine()
        try? fm.removeItem(at: modelURL(for: selectedVariant))
        refreshState()
    }

    /// One long-lived engine, cached on the manager (which lives for the whole
    /// app session). The native LiteRT-LM Conversation/Session SEGFAULTs on
    /// deallocation in this preview binding, so we must NOT let the engine
    /// deinit when a chat view closes — keep it here, not in view @State.
    private var cachedEngine: GemmaEngine?
    private var cachedEngineVariant: Variant?
    private var cachedEnginePath: String?

    /// A ready engine for the downloaded model, or nil if not downloaded.
    /// Reuses the cached engine unless the model/variant changed.
    func makeEngine() -> LLMEngine? {
        guard isReady else { return nil }
        let path = modelURL(for: selectedVariant).path
        if let e = cachedEngine, cachedEngineVariant == selectedVariant, cachedEnginePath == path {
            return e
        }
        let e = GemmaEngine(modelPath: path, displayName: selectedVariant.title)
        cachedEngine = e
        cachedEngineVariant = selectedVariant
        cachedEnginePath = path
        return e
    }

    /// Drop the cached engine (e.g. when the model is deleted or variant swapped
    /// and we want to free it). Safe because no view holds a strong ref.
    func releaseEngine() {
        cachedEngine = nil
        cachedEngineVariant = nil
        cachedEnginePath = nil
    }
}
