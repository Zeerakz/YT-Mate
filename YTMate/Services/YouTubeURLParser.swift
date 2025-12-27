import Foundation

/// Utility for parsing and validating YouTube URLs
/// Extracts video IDs from various YouTube URL formats
enum YouTubeURLParser {
    /// Regular expression patterns for YouTube URLs
    private static let patterns: [String] = [
        // Standard watch URL: youtube.com/watch?v=VIDEO_ID
        #"(?:youtube\.com\/watch\?v=|youtube\.com\/watch\?.+&v=)([a-zA-Z0-9_-]{11})"#,

        // Short URL: youtu.be/VIDEO_ID
        #"youtu\.be\/([a-zA-Z0-9_-]{11})"#,

        // Embed URL: youtube.com/embed/VIDEO_ID
        #"youtube\.com\/embed\/([a-zA-Z0-9_-]{11})"#,

        // Shorts URL: youtube.com/shorts/VIDEO_ID
        #"youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})"#,

        // Live URL: youtube.com/live/VIDEO_ID
        #"youtube\.com\/live\/([a-zA-Z0-9_-]{11})"#,

        // v parameter in any position: youtube.com/...?...v=VIDEO_ID...
        #"youtube\.com\/.+[?&]v=([a-zA-Z0-9_-]{11})"#,

        // Mobile app share: youtube.com/watch?v=VIDEO_ID with additional params
        #"(?:m\.)?youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})"#
    ]

    /// Extract video ID from a YouTube URL
    /// - Parameter url: The URL string to parse
    /// - Returns: The video ID if found, nil otherwise
    static func extractVideoId(from url: String) -> String? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        for pattern in patterns {
            if let videoId = extractUsingPattern(pattern, from: trimmedURL) {
                return videoId
            }
        }

        return nil
    }

    /// Extract video ID using a specific regex pattern
    private static func extractUsingPattern(_ pattern: String, from url: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(url.startIndex..., in: url)

        guard let match = regex.firstMatch(in: url, options: [], range: range) else {
            return nil
        }

        guard match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: url) else {
            return nil
        }

        return String(url[captureRange])
    }

    /// Check if a string is a valid YouTube URL
    /// - Parameter url: The string to check
    /// - Returns: True if the string is a valid YouTube URL
    static func isValidYouTubeURL(_ url: String) -> Bool {
        return extractVideoId(from: url) != nil
    }

    /// Normalize a YouTube URL to the standard format
    /// - Parameter url: The YouTube URL to normalize
    /// - Returns: The normalized URL (youtube.com/watch?v=VIDEO_ID) or nil if invalid
    static func normalizeURL(_ url: String) -> String? {
        guard let videoId = extractVideoId(from: url) else {
            return nil
        }

        return "https://www.youtube.com/watch?v=\(videoId)"
    }

    /// Generate a YouTube URL with timestamp
    /// - Parameters:
    ///   - videoId: The video ID
    ///   - seconds: The timestamp in seconds
    /// - Returns: The YouTube URL with timestamp parameter
    static func urlWithTimestamp(videoId: String, seconds: Int) -> String {
        return "https://www.youtube.com/watch?v=\(videoId)&t=\(seconds)s"
    }

    /// Generate thumbnail URL for a video
    /// - Parameters:
    ///   - videoId: The video ID
    ///   - quality: The thumbnail quality
    /// - Returns: The thumbnail URL
    static func thumbnailURL(for videoId: String, quality: ThumbnailQuality = .maxRes) -> String {
        return "https://img.youtube.com/vi/\(videoId)/\(quality.rawValue).jpg"
    }

    /// Thumbnail quality options
    enum ThumbnailQuality: String {
        case `default` = "default"      // 120x90
        case medium = "mqdefault"       // 320x180
        case high = "hqdefault"         // 480x360
        case standard = "sddefault"     // 640x480
        case maxRes = "maxresdefault"   // 1280x720 (may not exist for all videos)
    }
}

// MARK: - URL Validation
extension YouTubeURLParser {
    /// Detailed validation result
    struct ValidationResult {
        let isValid: Bool
        let videoId: String?
        let normalizedURL: String?
        let thumbnailURL: String?
        let errorMessage: String?
    }

    /// Perform detailed validation of a YouTube URL
    /// - Parameter url: The URL to validate
    /// - Returns: Detailed validation result
    static func validate(_ url: String) -> ValidationResult {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        if trimmedURL.isEmpty {
            return ValidationResult(
                isValid: false,
                videoId: nil,
                normalizedURL: nil,
                thumbnailURL: nil,
                errorMessage: "URL cannot be empty"
            )
        }

        // Check if it's a URL at all
        guard URL(string: trimmedURL) != nil else {
            return ValidationResult(
                isValid: false,
                videoId: nil,
                normalizedURL: nil,
                thumbnailURL: nil,
                errorMessage: "Invalid URL format"
            )
        }

        // Check for YouTube domain
        let lowercased = trimmedURL.lowercased()
        let isYouTubeDomain = lowercased.contains("youtube.com") || lowercased.contains("youtu.be")

        if !isYouTubeDomain {
            return ValidationResult(
                isValid: false,
                videoId: nil,
                normalizedURL: nil,
                thumbnailURL: nil,
                errorMessage: "Not a YouTube URL"
            )
        }

        // Extract video ID
        guard let videoId = extractVideoId(from: trimmedURL) else {
            return ValidationResult(
                isValid: false,
                videoId: nil,
                normalizedURL: nil,
                thumbnailURL: nil,
                errorMessage: "Could not extract video ID from URL"
            )
        }

        return ValidationResult(
            isValid: true,
            videoId: videoId,
            normalizedURL: normalizeURL(trimmedURL),
            thumbnailURL: thumbnailURL(for: videoId),
            errorMessage: nil
        )
    }
}

// MARK: - Playlist Support
extension YouTubeURLParser {
    /// Extract playlist ID from a YouTube URL
    /// - Parameter url: The URL to parse
    /// - Returns: The playlist ID if found
    static func extractPlaylistId(from url: String) -> String? {
        let pattern = #"[?&]list=([a-zA-Z0-9_-]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(url.startIndex..., in: url)

        guard let match = regex.firstMatch(in: url, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: url) else {
            return nil
        }

        return String(url[captureRange])
    }

    /// Check if URL is a playlist
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL contains a playlist parameter
    static func isPlaylistURL(_ url: String) -> Bool {
        return extractPlaylistId(from: url) != nil
    }
}
