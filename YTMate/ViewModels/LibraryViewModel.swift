import Foundation
import SwiftData
import Combine

/// ViewModel for the Library view
/// Manages the list of video summaries and filtering/sorting
@MainActor
@Observable
final class LibraryViewModel {
    /// All video summaries
    var summaries: [VideoSummary] = []

    /// Filtered summaries based on search and category
    var filteredSummaries: [VideoSummary] {
        var result = summaries

        // Apply search filter
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { summary in
                summary.tldr.lowercased().contains(lowercasedSearch) ||
                (summary.videoTitle?.lowercased().contains(lowercasedSearch) ?? false) ||
                summary.actionItems.contains { $0.headline.lowercased().contains(lowercasedSearch) }
            }
        }

        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.vibeCategory == category.rawValue }
        }

        // Apply sorting
        switch sortOrder {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .alphabetical:
            result.sort { ($0.videoTitle ?? "") < ($1.videoTitle ?? "") }
        }

        return result
    }

    /// Search text
    var searchText = ""

    /// Selected category filter
    var selectedCategory: VibeCategory?

    /// Sort order
    var sortOrder: SortOrder = .newest

    /// Loading state
    var isLoading = false

    /// Error message
    var errorMessage: String?

    /// Whether to show the summary sheet
    var showingSummarySheet = false

    /// URL being processed
    var processingURL: String?

    /// Categories present in the library
    var availableCategories: [VibeCategory] {
        let categoryStrings = Set(summaries.map { $0.vibeCategory })
        return categoryStrings.compactMap { VibeCategory.from(string: $0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Summary counts by category
    var categoryCounts: [VibeCategory: Int] {
        var counts: [VibeCategory: Int] = [:]
        for summary in summaries {
            let category = VibeCategory.from(string: summary.vibeCategory)
            counts[category, default: 0] += 1
        }
        return counts
    }

    // MARK: - Data Loading

    /// Load summaries from SwiftData
    func loadSummaries(from context: ModelContext) {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<VideoSummary>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            summaries = try context.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load summaries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Sync with Firestore
    func syncWithFirestore(userId: String, context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            // First sync local to remote
            try await FirestoreService.shared.syncLocalSummaries(summaries, modelContext: context)

            // Then import any remote changes
            try await FirestoreService.shared.importFromFirestore(userId: userId, modelContext: context)

            // Reload from local database
            loadSummaries(from: context)

            // Update Spotlight index
            await SpotlightService.shared.indexSummaries(summaries)

        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Summary Actions

    /// Delete a summary
    func deleteSummary(_ summary: VideoSummary, context: ModelContext) async {
        do {
            // Remove from Spotlight
            await SpotlightService.shared.removeSummary(summary)

            // Delete from Firestore
            try await FirestoreService.shared.deleteSummary(summary)

            // Delete from local database
            context.delete(summary)
            try context.save()

            // Update local array
            summaries.removeAll { $0.id == summary.id }

        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    /// Delete multiple summaries
    func deleteSummaries(_ summariesToDelete: [VideoSummary], context: ModelContext) async {
        for summary in summariesToDelete {
            await deleteSummary(summary, context: context)
        }
    }

    // MARK: - URL Processing

    /// Process a YouTube URL
    func processURL(_ url: String, userId: String, context: ModelContext) async {
        processingURL = url
        showingSummarySheet = true
    }

    /// Clear processing state
    func clearProcessing() {
        processingURL = nil
        showingSummarySheet = false
    }

    // MARK: - Filtering

    /// Clear all filters
    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        sortOrder = .newest
    }

    /// Toggle category filter
    func toggleCategory(_ category: VibeCategory) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
    }
}

// MARK: - Sort Order
enum SortOrder: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case alphabetical = "A-Z"

    var icon: String {
        switch self {
        case .newest:
            return "arrow.down"
        case .oldest:
            return "arrow.up"
        case .alphabetical:
            return "textformat.abc"
        }
    }
}
