import Foundation

extension String {
    /// Truncate string to a maximum length with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length - trailing.count)) + trailing
        }
        return self
    }

    /// Check if string contains a valid YouTube URL
    var containsYouTubeURL: Bool {
        YouTubeURLParser.isValidYouTubeURL(self)
    }

    /// Extract YouTube video ID if present
    var youtubeVideoId: String? {
        YouTubeURLParser.extractVideoId(from: self)
    }

    /// Remove HTML tags from string
    var strippingHTML: String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }

        return attributed.string
    }

    /// Trim whitespace and newlines
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if string is empty after trimming whitespace
    var isBlank: Bool {
        self.trimmed.isEmpty
    }

    /// Convert to URL if valid
    var asURL: URL? {
        URL(string: self)
    }

    /// Extract first N words
    func firstWords(_ count: Int) -> String {
        let words = self.split(separator: " ").prefix(count)
        return words.joined(separator: " ")
    }

    /// Count words in string
    var wordCount: Int {
        self.split(separator: " ").count
    }
}

// MARK: - Localization
extension String {
    /// Localized string using self as key
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Validation
extension String {
    /// Check if string is a valid email
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: emailRegex, options: .regularExpression) != nil
    }

    /// Check if string is a valid URL
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

// MARK: - Encoding
extension String {
    /// URL encoded string
    var urlEncoded: String? {
        self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    /// URL decoded string
    var urlDecoded: String? {
        self.removingPercentEncoding
    }

    /// Base64 encoded string
    var base64Encoded: String? {
        self.data(using: .utf8)?.base64EncodedString()
    }

    /// Base64 decoded string
    var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
