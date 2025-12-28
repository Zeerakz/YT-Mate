import Foundation
import UIKit
import Combine

/// Service for monitoring the clipboard for YouTube URLs
/// Shows a toast notification when a valid YouTube URL is detected
@MainActor
final class ClipboardService: ObservableObject {
    /// Shared singleton instance
    static let shared = ClipboardService()

    /// The detected YouTube URL (if any)
    @Published private(set) var detectedURL: String?

    /// Whether we should show the toast
    @Published var showToast = false

    /// Last processed clipboard content (to avoid duplicate checks)
    private var lastProcessedContent: String?

    /// Notification observer
    private var willEnterForegroundObserver: NSObjectProtocol?

    private init() {
        setupNotifications()
    }

    deinit {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Setup notification observers
    private func setupNotifications() {
        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    /// Check clipboard for YouTube URL
    /// Called on app launch and when returning to foreground
    func checkClipboard() {
        // Check if we have pasteboard access
        guard UIPasteboard.general.hasStrings else {
            clearDetectedURL()
            return
        }

        // Get clipboard content
        guard let clipboardContent = UIPasteboard.general.string else {
            clearDetectedURL()
            return
        }

        // Skip if we've already processed this content
        if clipboardContent == lastProcessedContent {
            return
        }

        lastProcessedContent = clipboardContent

        // Check if it's a valid YouTube URL
        if let videoId = YouTubeURLParser.extractVideoId(from: clipboardContent), !videoId.isEmpty {
            detectedURL = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
            showToast = true
        } else {
            clearDetectedURL()
        }
    }

    /// Clear the detected URL
    func clearDetectedURL() {
        detectedURL = nil
        showToast = false
    }

    /// Dismiss the toast
    func dismissToast() {
        showToast = false
        // Keep the URL in case user changes their mind
    }

    /// Get the URL and clear state
    func consumeURL() -> String? {
        let url = detectedURL
        clearDetectedURL()
        return url
    }

    /// Reset the last processed content (for testing or manual refresh)
    func resetLastProcessed() {
        lastProcessedContent = nil
    }
}

// MARK: - Clipboard Privacy
extension ClipboardService {
    /// Request clipboard access with explanation
    /// Note: iOS 14+ shows a notification when clipboard is accessed
    func requestClipboardAccess() {
        // Simply accessing the clipboard will trigger iOS's privacy notification
        // There's no explicit permission API, but the user can restrict it in Settings
        _ = UIPasteboard.general.hasStrings
    }
}
