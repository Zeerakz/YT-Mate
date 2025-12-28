import Foundation
import FirebaseAI

/// Service for interacting with Gemini via Firebase AI Logic
/// Handles video summarization using native YouTube URL understanding
///
/// Updated for Firebase AI Logic SDK (formerly Vertex AI in Firebase)
/// Uses Gemini 3 Flash for native YouTube video understanding
@MainActor
final class GeminiService: ObservableObject {
    // MARK: - Singleton

    /// Shared singleton instance
    static let shared = GeminiService()

    // MARK: - Published State

    /// Current processing state
    @Published private(set) var isProcessing = false

    /// Last error message
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    /// The Firebase AI instance
    private var firebaseAI: FirebaseAI?

    /// The generative model instance
    private var model: GenerativeModel?

    /// Rate limiting: Track daily YouTube video processing
    private var dailyVideoCount: Int = 0
    private var lastResetDate: Date = Date()

    /// Maximum YouTube videos per day (8 hours at ~10 min avg = ~48 videos, be conservative)
    private let maxDailyVideos: Int = 40

    /// Model configuration
    private let modelName = "gemini-3-flash"  // Gemini 3 Flash (Dec 2025)

    /// System prompt for consistent, actionable output
    private let systemInstruction = """
    You are an expert learning assistant. Your goal is to extract hard utility from video content.
    Ignore fluff, intros, sponsor reads, and filler content.

    You must analyze the YouTube video provided and output valid JSON matching the exact schema provided.

    For the 'summary' field:
    - Write exactly 2 sentences
    - Focus on the core value proposition and key takeaways
    - Be specific, not generic

    For 'action_items':
    - Extract 5-10 actionable items
    - Focus on instructions, not descriptions
    - BAD: "He talks about lighting"
    - GOOD: "Place key light at 45-degree angle from subject"
    - Include accurate timestamps (in seconds) where each action is discussed
    - Start each headline with an action verb

    For 'vibe_category':
    - Choose the single most appropriate category
    - Options: Technical, Motivational, Educational, Tutorial, Entertainment, News, Satire, Review, Vlog, Interview, Documentary, How-To, Other

    For 'difficulty_level':
    - Assess the expertise level required to benefit from this content
    - Options: Beginner, Intermediate, Advanced, Expert
    """

    // MARK: - Initialization

    private init() {
        setupFirebaseAI()
    }

    /// Initialize Firebase AI Logic with appropriate backend
    private func setupFirebaseAI() {
        // Initialize Firebase AI with Google AI backend (free tier available)
        // Use .vertexAI() for production with Vertex AI backend
        firebaseAI = FirebaseAI.firebaseAI(backend: .googleAI())

        // Configure generation parameters for fast, structured output
        let generationConfig = GenerationConfig(
            temperature: 0.3,           // Lower temperature for consistent output
            topP: 0.8,
            topK: 40,
            maxOutputTokens: 4096,      // Increased for detailed action items
            responseMIMEType: "application/json"
        )

        // Safety settings - allow educational content analysis
        let safetySettings = [
            SafetySetting(harmCategory: .harassment, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .hateSpeech, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockOnlyHigh)
        ]

        // Create the model with system instruction
        model = firebaseAI?.generativeModel(
            modelName: modelName,
            generationConfig: generationConfig,
            safetySettings: safetySettings,
            systemInstruction: ModelContent(role: "system", parts: [.text(systemInstruction)])
        )
    }

    // MARK: - Rate Limiting

    /// Check and update rate limiting
    private func checkRateLimit() throws {
        let calendar = Calendar.current
        let now = Date()

        // Reset counter if it's a new day
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            dailyVideoCount = 0
            lastResetDate = now
        }

        // Check if we've exceeded daily limit
        if dailyVideoCount >= maxDailyVideos {
            throw GeminiError.dailyQuotaExceeded(remaining: 0)
        }
    }

    /// Get remaining daily quota
    var remainingDailyQuota: Int {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            return maxDailyVideos
        }
        return max(0, maxDailyVideos - dailyVideoCount)
    }

    // MARK: - Video Summarization

    /// Summarize a YouTube video by URL
    /// - Parameters:
    ///   - url: The YouTube video URL
    ///   - videoId: The extracted video ID
    ///   - userId: The current user's ID
    /// - Returns: A VideoSummary object ready for persistence
    func summarizeVideo(url: String, videoId: String, userId: String) async throws -> VideoSummary {
        guard let model = model else {
            throw GeminiError.modelNotInitialized
        }

        // Check rate limiting
        try checkRateLimit()

        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Create the video part using FileDataPart with YouTube URL
            // Firebase AI Logic SDK supports YouTube URLs directly
            let videoPart = FileDataPart(uri: url, mimeType: "video/*")

            // Create the text prompt
            let promptText = """
            Analyze this YouTube video and extract actionable insights.

            Return a JSON object with this exact structure:
            \(GeminiResponse.jsonSchema)

            Important:
            - Timestamps should be in seconds (integer)
            - Each action item should start with a verb
            - Be specific and actionable
            """

            let textPart = ModelContent.Part.text(promptText)

            // Generate content with video + text parts
            let response = try await model.generateContent([
                ModelContent(role: "user", parts: [.fileData(videoPart), textPart])
            ])

            // Increment rate limit counter
            dailyVideoCount += 1

            // Extract and validate the text response
            guard let text = response.text, !text.isEmpty else {
                throw GeminiError.emptyResponse
            }

            // Clean the response (remove markdown code blocks if present)
            let cleanedText = cleanJSONResponse(text)

            // Parse the JSON response
            guard let jsonData = cleanedText.data(using: .utf8) else {
                throw GeminiError.invalidJSON(details: "Failed to convert response to data")
            }

            let decoder = JSONDecoder()
            let geminiResponse: GeminiResponse

            do {
                geminiResponse = try decoder.decode(GeminiResponse.self, from: jsonData)
            } catch let decodingError {
                throw GeminiError.invalidJSON(details: decodingError.localizedDescription)
            }

            // Generate thumbnail URL from video ID
            let thumbnailURL = YouTubeURLParser.thumbnailURL(for: videoId, quality: .maxRes)

            // Convert to domain model
            let summary = geminiResponse.toVideoSummary(
                videoURL: url,
                videoId: videoId,
                thumbnailURL: thumbnailURL,
                userId: userId
            )

            return summary

        } catch let error as GeminiError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            // Map Firebase AI errors to our error types
            let mappedError = mapFirebaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }

    /// Summarize video with streaming response for real-time UI updates
    /// - Parameters:
    ///   - url: The YouTube video URL
    ///   - videoId: The extracted video ID
    ///   - userId: The current user's ID
    ///   - onPartialResult: Callback for streaming partial results (called on MainActor)
    /// - Returns: A VideoSummary object ready for persistence
    func summarizeVideoStreaming(
        url: String,
        videoId: String,
        userId: String,
        onPartialResult: @escaping @MainActor (String) -> Void
    ) async throws -> VideoSummary {
        guard let model = model else {
            throw GeminiError.modelNotInitialized
        }

        // Check rate limiting
        try checkRateLimit()

        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Create the video part using FileDataPart with YouTube URL
            let videoPart = FileDataPart(uri: url, mimeType: "video/*")

            // Create the text prompt
            let promptText = """
            Analyze this YouTube video and extract actionable insights.

            Return a JSON object with this exact structure:
            \(GeminiResponse.jsonSchema)

            Important:
            - Timestamps should be in seconds (integer)
            - Each action item should start with a verb
            - Be specific and actionable
            """

            let textPart = ModelContent.Part.text(promptText)

            var fullResponse = ""

            // Stream the response
            let contentStream = try model.generateContentStream([
                ModelContent(role: "user", parts: [.fileData(videoPart), textPart])
            ])

            for try await chunk in contentStream {
                if let text = chunk.text {
                    fullResponse += text
                    // Call the callback on MainActor to avoid race conditions
                    await onPartialResult(fullResponse)
                }
            }

            // Increment rate limit counter
            dailyVideoCount += 1

            // Clean and parse the complete JSON response
            let cleanedText = cleanJSONResponse(fullResponse)

            guard let jsonData = cleanedText.data(using: .utf8) else {
                throw GeminiError.invalidJSON(details: "Failed to convert response to data")
            }

            let decoder = JSONDecoder()
            let geminiResponse: GeminiResponse

            do {
                geminiResponse = try decoder.decode(GeminiResponse.self, from: jsonData)
            } catch let decodingError {
                throw GeminiError.invalidJSON(details: decodingError.localizedDescription)
            }

            let thumbnailURL = YouTubeURLParser.thumbnailURL(for: videoId, quality: .maxRes)

            return geminiResponse.toVideoSummary(
                videoURL: url,
                videoId: videoId,
                thumbnailURL: thumbnailURL,
                userId: userId
            )

        } catch let error as GeminiError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            let mappedError = mapFirebaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }

    // MARK: - Helper Methods

    /// Clean JSON response by removing markdown code blocks
    private func cleanJSONResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json prefix
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        // Remove ``` suffix
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Map Firebase AI errors to our error types
    private func mapFirebaseError(_ error: Error) -> GeminiError {
        let errorString = error.localizedDescription.lowercased()

        // Check for specific error patterns
        if errorString.contains("permission") || errorString.contains("private") {
            return .videoNotAccessible(reason: "Video is private or unavailable")
        }

        if errorString.contains("quota") || errorString.contains("rate limit") {
            return .apiQuotaExceeded
        }

        if errorString.contains("not found") || errorString.contains("404") {
            return .videoNotAccessible(reason: "Video not found")
        }

        if errorString.contains("age") || errorString.contains("restricted") {
            return .videoNotAccessible(reason: "Video is age-restricted")
        }

        if errorString.contains("blocked") || errorString.contains("safety") {
            return .contentBlocked
        }

        if errorString.contains("timeout") || errorString.contains("timed out") {
            return .requestTimeout
        }

        if errorString.contains("network") || errorString.contains("connection") {
            return .networkError(error.localizedDescription)
        }

        // Default to generic API error
        return .apiError(error.localizedDescription)
    }

    // MARK: - Model Switching

    /// Switch to a different model (e.g., for testing Gemini 3)
    func switchModel(to newModelName: String) {
        guard let firebaseAI = firebaseAI else { return }

        let generationConfig = GenerationConfig(
            temperature: 0.3,
            topP: 0.8,
            topK: 40,
            maxOutputTokens: 4096,
            responseMIMEType: "application/json"
        )

        model = firebaseAI.generativeModel(
            modelName: newModelName,
            generationConfig: generationConfig,
            systemInstruction: ModelContent(role: "system", parts: [.text(systemInstruction)])
        )
    }
}

// MARK: - Error Types

enum GeminiError: LocalizedError, Equatable {
    case modelNotInitialized
    case emptyResponse
    case invalidJSON(details: String)
    case videoNotAccessible(reason: String)
    case apiQuotaExceeded
    case dailyQuotaExceeded(remaining: Int)
    case contentBlocked
    case requestTimeout
    case networkError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "AI model not initialized. Please restart the app."
        case .emptyResponse:
            return "Received empty response from AI. Please try again."
        case .invalidJSON(let details):
            return "Failed to parse AI response: \(details)"
        case .videoNotAccessible(let reason):
            return "Cannot access video: \(reason)"
        case .apiQuotaExceeded:
            return "API quota exceeded. Please try again later."
        case .dailyQuotaExceeded(let remaining):
            return "Daily video limit reached (\(remaining) remaining). Try again tomorrow."
        case .contentBlocked:
            return "Content was blocked by safety filters."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "AI Error: \(message)"
        }
    }

    /// Whether this error is retryable
    var isRetryable: Bool {
        switch self {
        case .requestTimeout, .networkError:
            return true
        case .emptyResponse:
            return true
        default:
            return false
        }
    }

    static func == (lhs: GeminiError, rhs: GeminiError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
