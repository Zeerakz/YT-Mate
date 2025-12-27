import Foundation
import SwiftData

/// Represents a single actionable item extracted from a video
/// Follows the format: action_verb + context + timestamp
@Model
final class ActionItem {
    /// Unique identifier
    @Attribute(.unique)
    var id: String

    /// Emoji representing the action type
    var emoji: String

    /// Short headline/action verb (e.g., "Place key light at 45-degree angle")
    var headline: String

    /// Detailed context or instructions
    var detail: String

    /// Timestamp in seconds where this action is discussed
    var timestampSeconds: Int

    /// Order index for display
    var orderIndex: Int

    /// Parent video summary
    var videoSummary: VideoSummary?

    init(
        id: String = UUID().uuidString,
        emoji: String,
        headline: String,
        detail: String,
        timestampSeconds: Int,
        orderIndex: Int = 0,
        videoSummary: VideoSummary? = nil
    ) {
        self.id = id
        self.emoji = emoji
        self.headline = headline
        self.detail = detail
        self.timestampSeconds = timestampSeconds
        self.orderIndex = orderIndex
        self.videoSummary = videoSummary
    }
}

// MARK: - Computed Properties
extension ActionItem {
    /// Format timestamp as MM:SS or HH:MM:SS
    var formattedTimestamp: String {
        let hours = timestampSeconds / 3600
        let minutes = (timestampSeconds % 3600) / 60
        let seconds = timestampSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Generate YouTube URL with timestamp
    func youtubeURLWithTimestamp(baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }

        // Add or update the 't' parameter for timestamp
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "t" }
        queryItems.append(URLQueryItem(name: "t", value: "\(timestampSeconds)s"))
        components.queryItems = queryItems

        return components.url
    }
}

// MARK: - Firestore Conversion
extension ActionItem {
    /// Convert to dictionary for Firestore
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "emoji": emoji,
            "headline": headline,
            "detail": detail,
            "timestampSeconds": timestampSeconds,
            "orderIndex": orderIndex
        ]
    }

    /// Create from Firestore document data
    static func fromFirestoreData(_ data: [String: Any]) -> ActionItem? {
        guard let id = data["id"] as? String,
              let emoji = data["emoji"] as? String,
              let headline = data["headline"] as? String,
              let detail = data["detail"] as? String,
              let timestampSeconds = data["timestampSeconds"] as? Int else {
            return nil
        }

        return ActionItem(
            id: id,
            emoji: emoji,
            headline: headline,
            detail: detail,
            timestampSeconds: timestampSeconds,
            orderIndex: data["orderIndex"] as? Int ?? 0
        )
    }
}

// MARK: - Spotlight Indexing
extension ActionItem {
    /// Generate searchable content for Spotlight
    var spotlightDescription: String {
        "\(emoji) \(headline): \(detail)"
    }
}
