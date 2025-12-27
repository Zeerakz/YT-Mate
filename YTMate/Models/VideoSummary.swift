import Foundation
import SwiftData

/// Main model representing a summarized YouTube video
/// Persisted locally with SwiftData and synced to Cloud Firestore
@Model
final class VideoSummary {
    /// Unique identifier
    @Attribute(.unique)
    var id: String

    /// Original YouTube video URL
    var videoURL: String

    /// YouTube video ID extracted from URL
    var videoId: String

    /// Video title (if available)
    var videoTitle: String?

    /// Video thumbnail URL
    var thumbnailURL: String?

    /// The "TL;DR" - 2-sentence high-level summary
    var tldr: String

    /// Difficulty level of the content
    var difficultyLevel: String

    /// The "Vibe Check" - 1-word category tag
    var vibeCategory: String

    /// Action items extracted from the video
    @Relationship(deleteRule: .cascade)
    var actionItems: [ActionItem]

    /// User's personal notes
    var userNotes: String?

    /// Creation timestamp
    var createdAt: Date

    /// Last modified timestamp
    var updatedAt: Date

    /// User ID who owns this summary
    var userId: String

    /// Whether the summary has been synced to Firestore
    var isSynced: Bool

    /// Firestore document ID (if synced)
    var firestoreId: String?

    init(
        id: String = UUID().uuidString,
        videoURL: String,
        videoId: String,
        videoTitle: String? = nil,
        thumbnailURL: String? = nil,
        tldr: String,
        difficultyLevel: String,
        vibeCategory: String,
        actionItems: [ActionItem] = [],
        userNotes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        userId: String,
        isSynced: Bool = false,
        firestoreId: String? = nil
    ) {
        self.id = id
        self.videoURL = videoURL
        self.videoId = videoId
        self.videoTitle = videoTitle
        self.thumbnailURL = thumbnailURL
        self.tldr = tldr
        self.difficultyLevel = difficultyLevel
        self.vibeCategory = vibeCategory
        self.actionItems = actionItems
        self.userNotes = userNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
        self.isSynced = isSynced
        self.firestoreId = firestoreId
    }
}

// MARK: - Firestore Conversion
extension VideoSummary {
    /// Convert to dictionary for Firestore
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "videoURL": videoURL,
            "videoId": videoId,
            "tldr": tldr,
            "difficultyLevel": difficultyLevel,
            "vibeCategory": vibeCategory,
            "actionItems": actionItems.map { $0.toFirestoreData() },
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "userId": userId
        ]

        if let videoTitle = videoTitle {
            data["videoTitle"] = videoTitle
        }
        if let thumbnailURL = thumbnailURL {
            data["thumbnailURL"] = thumbnailURL
        }
        if let userNotes = userNotes {
            data["userNotes"] = userNotes
        }

        return data
    }

    /// Create from Firestore document data
    static func fromFirestoreData(_ data: [String: Any], documentId: String) -> VideoSummary? {
        guard let id = data["id"] as? String,
              let videoURL = data["videoURL"] as? String,
              let videoId = data["videoId"] as? String,
              let tldr = data["tldr"] as? String,
              let difficultyLevel = data["difficultyLevel"] as? String,
              let vibeCategory = data["vibeCategory"] as? String,
              let userId = data["userId"] as? String else {
            return nil
        }

        let actionItemsData = data["actionItems"] as? [[String: Any]] ?? []
        let actionItems = actionItemsData.compactMap { ActionItem.fromFirestoreData($0) }

        let summary = VideoSummary(
            id: id,
            videoURL: videoURL,
            videoId: videoId,
            videoTitle: data["videoTitle"] as? String,
            thumbnailURL: data["thumbnailURL"] as? String,
            tldr: tldr,
            difficultyLevel: difficultyLevel,
            vibeCategory: vibeCategory,
            actionItems: actionItems,
            userNotes: data["userNotes"] as? String,
            createdAt: (data["createdAt"] as? Date) ?? Date(),
            updatedAt: (data["updatedAt"] as? Date) ?? Date(),
            userId: userId,
            isSynced: true,
            firestoreId: documentId
        )

        return summary
    }
}

// MARK: - Spotlight Indexing
extension VideoSummary {
    /// Generate searchable text for Spotlight indexing
    var searchableText: String {
        var text = tldr
        if let title = videoTitle {
            text = title + " " + text
        }
        text += " " + actionItems.map { $0.headline }.joined(separator: " ")
        return text
    }

    /// Keywords for Spotlight search
    var searchKeywords: [String] {
        var keywords = [vibeCategory, difficultyLevel]
        keywords.append(contentsOf: actionItems.map { $0.headline })
        return keywords
    }
}
