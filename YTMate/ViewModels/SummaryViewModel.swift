import Foundation
import SwiftData

/// ViewModel for generating and managing a single video summary
/// Handles the Gemini API call and result processing
@MainActor
@Observable
final class SummaryViewModel {
    /// The video URL being processed
    var videoURL: String = ""

    /// The extracted video ID
    var videoId: String?

    /// The generated summary
    var summary: VideoSummary?

    /// Processing state
    var state: ProcessingState = .idle

    /// Error message if any
    var errorMessage: String?

    /// Partial response during streaming
    var partialResponse: String = ""

    /// User's personal note
    var userNote: String = ""

    /// Whether the summary was saved
    var isSaved = false

    // MARK: - Processing

    /// Generate a summary for the given URL
    func generateSummary(for url: String, userId: String) async {
        // Validate URL
        let validation = YouTubeURLParser.validate(url)

        guard validation.isValid, let videoId = validation.videoId else {
            state = .error
            errorMessage = validation.errorMessage ?? "Invalid YouTube URL"
            return
        }

        self.videoURL = validation.normalizedURL ?? url
        self.videoId = videoId
        state = .loading
        errorMessage = nil
        partialResponse = ""

        do {
            // Use streaming for real-time UI updates
            let result = try await GeminiService.shared.summarizeVideoStreaming(
                url: self.videoURL,
                videoId: videoId,
                userId: userId
            ) { [weak self] partial in
                self?.partialResponse = partial
            }

            self.summary = result
            state = .success

        } catch {
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Generate summary without streaming (faster for simple cases)
    func generateSummaryDirect(for url: String, userId: String) async {
        let validation = YouTubeURLParser.validate(url)

        guard validation.isValid, let videoId = validation.videoId else {
            state = .error
            errorMessage = validation.errorMessage ?? "Invalid YouTube URL"
            return
        }

        self.videoURL = validation.normalizedURL ?? url
        self.videoId = videoId
        state = .loading
        errorMessage = nil

        do {
            let result = try await GeminiService.shared.summarizeVideo(
                url: self.videoURL,
                videoId: videoId,
                userId: userId
            )

            self.summary = result
            state = .success

        } catch {
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Saving

    /// Save the summary to local database and sync to Firestore
    func saveSummary(context: ModelContext) async throws {
        guard let summary = summary else {
            throw SummaryError.noSummaryToSave
        }

        // Add user note if provided
        if !userNote.isEmpty {
            summary.userNotes = userNote
        }

        // Save to SwiftData
        context.insert(summary)
        try context.save()

        // Index in Spotlight
        await SpotlightService.shared.indexSummary(summary)

        // Sync to Firestore
        do {
            let firestoreId = try await FirestoreService.shared.saveSummary(summary)
            summary.firestoreId = firestoreId
            summary.isSynced = true
            try context.save()
        } catch {
            // Log but don't fail - will sync later
            print("Firestore sync failed: \(error.localizedDescription)")
        }

        isSaved = true
    }

    /// Discard the summary without saving
    func discardSummary() {
        summary = nil
        state = .idle
        resetState()
    }

    // MARK: - State Management

    /// Reset all state
    func resetState() {
        videoURL = ""
        videoId = nil
        summary = nil
        state = .idle
        errorMessage = nil
        partialResponse = ""
        userNote = ""
        isSaved = false
    }

    /// Retry the last URL
    func retry(userId: String) async {
        guard !videoURL.isEmpty else { return }
        await generateSummary(for: videoURL, userId: userId)
    }
}

// MARK: - Processing State
enum ProcessingState: Equatable {
    case idle
    case loading
    case success
    case error

    var isLoading: Bool {
        self == .loading
    }

    var isSuccess: Bool {
        self == .success
    }

    var isError: Bool {
        self == .error
    }
}

// MARK: - Errors
enum SummaryError: LocalizedError {
    case noSummaryToSave
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSummaryToSave:
            return "No summary available to save."
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        }
    }
}

// MARK: - Preview Support
extension SummaryViewModel {
    static var preview: SummaryViewModel {
        let vm = SummaryViewModel()
        vm.summary = GeminiResponse.sample.toVideoSummary(
            videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            videoId: "dQw4w9WgXcQ",
            videoTitle: "How to Master Portrait Photography",
            userId: "preview-user"
        )
        vm.state = .success
        return vm
    }
}
