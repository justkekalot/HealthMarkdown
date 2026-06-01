import Foundation

/// Downloads a large file (the Gemma .task model) with a URLSessionDownloadTask.
/// This uses the system's native chunked streaming-to-disk and progress
/// reporting — far faster and lighter than reading an async byte stream, which
/// crawled for multi-GB files. Auth header carries the Hugging Face token.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    private let url: URL
    private let token: String
    private let destination: URL
    private let onProgress: (Double) -> Void
    /// Called once on completion: nil = success, non-nil = error message.
    private let onFinish: (String?) -> Void

    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    init(url: URL, token: String, destination: URL,
         onProgress: @escaping (Double) -> Void,
         onFinish: @escaping (String?) -> Void) {
        self.url = url
        self.token = token
        self.destination = destination
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func start() {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 3600 // multi-GB over Wi-Fi
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: request)
        self.task = task
        task.resume()
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
        // Check the HTTP status — a gated/auth failure still "finishes" with an
        // error-body file, which we must not treat as a model.
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (http.statusCode == 401 || http.statusCode == 403)
                ? "Access denied (\(http.statusCode)). Check your token and that you accepted the Gemma license on Hugging Face."
                : "Download failed (HTTP \(http.statusCode))."
            onFinish(msg)
            return
        }
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
