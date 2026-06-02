import Foundation

/// Downloads a large file (the Gemma .task model) with a **background**
/// URLSessionDownloadTask. A background session keeps running when the app is
/// backgrounded or the screen locks — a default session is suspended, which is
/// why progress reset on lock. The download continues and reports progress when
/// the app is foregrounded again. Auth header carries the Hugging Face token.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    private let url: URL
    private let token: String
    private let destination: URL
    private let onProgress: (Double) -> Void
    /// nil = success, non-nil = error message.
    private let onFinish: (String?) -> Void

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private let sessionID: String

    init(url: URL, token: String, destination: URL,
         onProgress: @escaping (Double) -> Void,
         onFinish: @escaping (String?) -> Void) {
        self.url = url
        self.token = token
        self.destination = destination
        self.onProgress = onProgress
        self.onFinish = onFinish
        // Unique-but-stable per destination so a relaunch can reattach.
        self.sessionID = "app.escrime.healthmarkdown.modeldl." + destination.lastPathComponent
    }

    func start() {
        var request = URLRequest(url: url)
        // Token is optional — the Gemma 4 litert-lm repos are public. Only send
        // auth if one was provided (for gated repos / rate limits).
        if !token.trimmingCharacters(in: .whitespaces).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 3600

        let config = URLSessionConfiguration.background(withIdentifier: sessionID)
        config.isDiscretionary = false               // start now, don't wait for "ideal" conditions
        config.sessionSendsLaunchEvents = true        // wake the app when done
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 24 * 3600 // big file, slow networks
        config.allowsCellularAccess = true

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        // If a previous task for this session is still alive (e.g. after lock),
        // reattach to it instead of starting a duplicate.
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            if let existing = tasks.first as? URLSessionDownloadTask {
                self.task = existing
                existing.resume()
            } else {
                let task = session.downloadTask(with: request)
                self.task = task
                task.resume()
            }
        }
    }

    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (http.statusCode == 401 || http.statusCode == 403)
                ? "Access denied (\(http.statusCode)). Check your token and that you accepted the Gemma license on Hugging Face."
                : "Download failed (HTTP \(http.statusCode))."
            onFinish(msg)
            return
        }
        // The temp file is deleted as soon as this method returns, so move it now
        // (synchronously, on the delegate queue).
        do {
            let fm = FileManager.default
            try? fm.removeItem(at: destination)
            try fm.moveItem(at: location, to: destination)
            onFinish(nil)
        } catch {
            onFinish("Couldn't save the model: \(error.localizedDescription)")
        }
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            if error.code == NSURLErrorCancelled { return } // user cancelled
            onFinish("Download failed: \(error.localizedDescription)")
        }
    }
}
