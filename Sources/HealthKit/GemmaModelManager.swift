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
        var sizeText: String { self == .e2b ? "≈ 1.5 GB" : "≈ 4.4 GB" }
        var blurb: String {
            self == .e2b
            ? "Smaller & faster. Good answers, lighter on storage and battery."
            : "Larger & sharper. Best answers, needs more space and a bit more time per reply."
        }
    }

    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .notDownloaded
    @Published var selectedVariant: Variant = .e4b

    private let fm = FileManager.default
    private var downloadTask: Task<Void, Never>?

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

    /// Begin (or resume) downloading the selected variant.
    /// NOTE: the production model URL is configured at integration time (Hugging
    /// Face / your CDN, with the appropriate Gemma licence acceptance). The
    /// download/progress/cancel/persist plumbing here is real and final.
    func download(from url: URL? = nil) {
        guard !isReady else { return }
        state = .downloading(progress: 0)
        downloadTask?.cancel()
        downloadTask = Task { await runDownload(url: url) }
    }

    func cancel() {
        downloadTask?.cancel()
        refreshState()
    }

    func delete() {
        try? fm.removeItem(at: modelURL(for: selectedVariant))
        refreshState()
    }

    private func runDownload(url: URL?) async {
        guard let url else {
            // No source configured yet — surface an honest, actionable message
            // instead of pretending to download.
            state = .failed("Model source isn't configured in this build yet. The download flow is ready; the Gemma file URL gets set when on-device inference is wired in.")
            return
        }
        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            let total = response.expectedContentLength
            var received: Int64 = 0
            var data = Data()
            data.reserveCapacity(total > 0 ? Int(total) : 1_000_000)
            for try await byte in bytes {
                data.append(byte)
                received += 1
                if total > 0, received % 1_000_000 == 0 {
                    state = .downloading(progress: Double(received) / Double(total))
                }
            }
            try data.write(to: modelURL(for: selectedVariant), options: .atomic)
            state = .ready
        } catch is CancellationError {
            refreshState()
        } catch {
            state = .failed("Download failed: \(error.localizedDescription)")
        }
    }
}
