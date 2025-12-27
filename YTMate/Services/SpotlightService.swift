import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

/// Service for indexing VideoSummary content in iOS Spotlight Search
/// Allows users to search for tips and summaries from the iOS Home Screen
@MainActor
final class SpotlightService: ObservableObject {
    /// Shared singleton instance
    static let shared = SpotlightService()

    /// Domain identifier for our searchable items
    private let domainIdentifier = "com.ytmate.summaries"

    /// Index status
    @Published private(set) var isIndexing = false
    @Published private(set) var lastError: String?

    private init() {}

    // MARK: - Indexing

    /// Index a video summary and its action items
    /// - Parameter summary: The VideoSummary to index
    func indexSummary(_ summary: VideoSummary) async {
        isIndexing = true
        defer { isIndexing = false }

        var searchableItems: [CSSearchableItem] = []

        // Create searchable item for the summary itself
        let summaryItem = createSearchableItem(for: summary)
        searchableItems.append(summaryItem)

        // Create searchable items for each action item
        for actionItem in summary.actionItems {
            let item = createSearchableItem(for: actionItem, in: summary)
            searchableItems.append(item)
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(searchableItems)
        } catch {
            lastError = error.localizedDescription
            print("Spotlight indexing error: \(error.localizedDescription)")
        }
    }

    /// Index multiple summaries
    /// - Parameter summaries: Array of summaries to index
    func indexSummaries(_ summaries: [VideoSummary]) async {
        isIndexing = true
        defer { isIndexing = false }

        var allItems: [CSSearchableItem] = []

        for summary in summaries {
            allItems.append(createSearchableItem(for: summary))

            for actionItem in summary.actionItems {
                allItems.append(createSearchableItem(for: actionItem, in: summary))
            }
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(allItems)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Remove a summary from the Spotlight index
    /// - Parameter summary: The VideoSummary to remove
    func removeSummary(_ summary: VideoSummary) async {
        var identifiers = [summary.id]
        identifiers.append(contentsOf: summary.actionItems.map { "\(summary.id)_\($0.id)" })

        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Remove all indexed items
    func removeAllItems() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Searchable Item Creation

    /// Create a searchable item for a video summary
    private func createSearchableItem(for summary: VideoSummary) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)

        // Basic info
        attributeSet.title = summary.videoTitle ?? "Video Summary"
        attributeSet.contentDescription = summary.tldr

        // Keywords for search
        attributeSet.keywords = summary.searchKeywords

        // Category and metadata
        attributeSet.subject = summary.vibeCategory

        // Thumbnail
        if let thumbnailURL = summary.thumbnailURL {
            attributeSet.thumbnailURL = URL(string: thumbnailURL)
        }

        // Timestamps
        attributeSet.contentCreationDate = summary.createdAt
        attributeSet.contentModificationDate = summary.updatedAt

        // Related content
        attributeSet.relatedUniqueIdentifier = summary.videoURL

        return CSSearchableItem(
            uniqueIdentifier: summary.id,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }

    /// Create a searchable item for an action item
    private func createSearchableItem(for actionItem: ActionItem, in summary: VideoSummary) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)

        // Action item content
        attributeSet.title = "\(actionItem.emoji) \(actionItem.headline)"
        attributeSet.contentDescription = actionItem.detail

        // Keywords
        attributeSet.keywords = [
            actionItem.headline,
            summary.vibeCategory,
            summary.difficultyLevel
        ]

        // Video context
        if let videoTitle = summary.videoTitle {
            attributeSet.album = videoTitle // Use album as a way to group by video
        }

        // Timestamp info
        attributeSet.duration = NSNumber(value: actionItem.timestampSeconds)

        // Thumbnail from parent video
        if let thumbnailURL = summary.thumbnailURL {
            attributeSet.thumbnailURL = URL(string: thumbnailURL)
        }

        return CSSearchableItem(
            uniqueIdentifier: "\(summary.id)_\(actionItem.id)",
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }

    // MARK: - Handling Spotlight Results

    /// Parse a Spotlight activity to get the summary/action item IDs
    /// - Parameter userActivity: The NSUserActivity from Spotlight
    /// - Returns: Tuple of (summaryId, actionItemId?) or nil
    static func parseSpotlightActivity(_ userActivity: NSUserActivity) -> (summaryId: String, actionItemId: String?)? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }

        let components = identifier.split(separator: "_")

        if components.count == 2 {
            // This is an action item: summaryId_actionItemId
            return (String(components[0]), String(components[1]))
        } else {
            // This is a summary
            return (identifier, nil)
        }
    }
}

// MARK: - Batch Operations
extension SpotlightService {
    /// Reindex all summaries
    /// Useful after app update or data migration
    func reindexAll(_ summaries: [VideoSummary]) async {
        // First remove all existing items
        await removeAllItems()

        // Then index all summaries
        await indexSummaries(summaries)
    }
}
