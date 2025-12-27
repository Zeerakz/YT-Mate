import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Share Extension View Controller
/// Handles incoming shared URLs from the YouTube app and other sources
class ShareViewController: UIViewController {
    /// The extracted YouTube URL
    private var sharedURL: String?

    /// Hosting controller for SwiftUI view
    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared content
        extractSharedURL { [weak self] url in
            guard let self = self else { return }

            if let url = url {
                self.sharedURL = url
                self.setupSwiftUIView(with: url)
            } else {
                self.showError("No valid YouTube URL found")
            }
        }
    }

    // MARK: - URL Extraction

    private func extractSharedURL(completion: @escaping (String?) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completion(nil)
            return
        }

        // Try to find a URL attachment
        for attachment in attachments {
            // Check for URL type
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            let urlString = url.absoluteString
                            if YouTubeURLParser.isValidYouTubeURL(urlString) {
                                completion(urlString)
                            } else {
                                completion(nil)
                            }
                        } else if let urlString = item as? String {
                            if YouTubeURLParser.isValidYouTubeURL(urlString) {
                                completion(urlString)
                            } else {
                                completion(nil)
                            }
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }

            // Check for plain text that might be a URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            // Try to extract YouTube URL from text
                            if YouTubeURLParser.isValidYouTubeURL(text) {
                                completion(text)
                            } else {
                                // Try to find URL in text
                                let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                                let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

                                for match in matches ?? [] {
                                    if let range = Range(match.range, in: text) {
                                        let urlString = String(text[range])
                                        if YouTubeURLParser.isValidYouTubeURL(urlString) {
                                            completion(urlString)
                                            return
                                        }
                                    }
                                }
                                completion(nil)
                            }
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }
        }

        completion(nil)
    }

    // MARK: - SwiftUI Setup

    private func setupSwiftUIView(with url: String) {
        let shareView = ShareExtensionView(
            url: url,
            onComplete: { [weak self] success in
                self?.complete(success: success)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Cannot Summarize",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.cancel()
        })

        present(alert, animated: true)
    }

    // MARK: - Completion

    private func complete(success: Bool) {
        if success {
            // Open main app with the URL
            if let url = sharedURL,
               let appURL = URL(string: "ytmate://summarize?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                openURL(appURL)
            }
        }

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.ytmate.share", code: 0))
    }

    // MARK: - Open URL

    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.perform(#selector(openURL(_:)), with: url)
                return
            }
            responder = responder?.next
        }
    }
}

// MARK: - YouTube URL Parser (Local Copy)
// Note: This is a simplified copy for the extension target
enum YouTubeURLParser {
    private static let patterns: [String] = [
        #"(?:youtube\.com\/watch\?v=|youtube\.com\/watch\?.+&v=)([a-zA-Z0-9_-]{11})"#,
        #"youtu\.be\/([a-zA-Z0-9_-]{11})"#,
        #"youtube\.com\/embed\/([a-zA-Z0-9_-]{11})"#,
        #"youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})"#,
        #"youtube\.com\/live\/([a-zA-Z0-9_-]{11})"#
    ]

    static func isValidYouTubeURL(_ url: String) -> Bool {
        return extractVideoId(from: url) != nil
    }

    static func extractVideoId(from url: String) -> String? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            let range = NSRange(trimmedURL.startIndex..., in: trimmedURL)

            guard let match = regex.firstMatch(in: trimmedURL, options: [], range: range),
                  match.numberOfRanges >= 2,
                  let captureRange = Range(match.range(at: 1), in: trimmedURL) else {
                continue
            }

            return String(trimmedURL[captureRange])
        }

        return nil
    }
}
