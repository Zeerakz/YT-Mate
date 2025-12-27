import Foundation
import FirebaseVertexAI

/// Service for interacting with Gemini 3 Flash via Vertex AI in Firebase
/// Handles video summarization using native video understanding capabilities
@MainActor
final class GeminiService: ObservableObject {
    /// Shared singleton instance
    static let shared = GeminiService()

    /// Current processing state
    @Published private(set) var isProcessing = false

    /// Last error message
    @Published private(set) var errorMessage: String?

    /// The Vertex AI model instance
    private var model: GenerativeModel?

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
    - Include accurate timestamps where each action is discussed
    - Start each headline with an action verb

    For 'vibe_category':
    - Choose the single most appropriate category
    - Options: Technical, Motivational, Educational, Tutorial, Entertainment, News, Satire, Review, Vlog, Interview, Documentary, How-To, Other

    For 'difficulty_level':
    - Assess the expertise level required to benefit from this content
    - Options: Beginner, Intermediate, Advanced, Expert
    """

    private init() {
        setupModel()
    }

    /// Initialize the Gemini model with Vertex AI
    private func setupModel() {
        // Initialize Vertex AI with Firebase
        let vertexAI = VertexAI.vertexAI()

        // Configure generation parameters for fast, structured output
        let generationConfig = GenerationConfig(
            temperature: 0.3,  // Lower temperature for consistent output
            topP: 0.8,
            topK: 40,
            maxOutputTokens: 2048,
            responseMIMEType: "application/json"
        )

        // Create the model with Gemini 3 Flash
        model = vertexAI.generativeModel(
            modelName: "gemini-2.0-flash-exp",  // Using latest available flash model
            generationConfig: generationConfig,
            systemInstruction: ModelContent(role: "system", parts: [.text(systemInstruction)])
        )
    }

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

        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Create the prompt with the video URL
            // Gemini 3 Flash can natively understand video content from URLs
            let prompt = """
            Analyze this YouTube video and extract actionable insights:
            \(url)

            Return a JSON object with this exact structure:
            \(GeminiResponse.jsonSchema)
            """

            // Generate content with the video URL
            // Gemini's native video understanding will fetch and analyze the video
            let response = try await model.generateContent(prompt)

            // Extract the text response
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }

            // Parse the JSON response
            guard let jsonData = text.data(using: .utf8) else {
                throw GeminiError.invalidJSON
            }

            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: jsonData)

            // Generate thumbnail URL from video ID
            let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"

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
            let geminiError = GeminiError.apiError(error.localizedDescription)
            errorMessage = geminiError.localizedDescription
            throw geminiError
        }
    }

    /// Summarize video with streaming response for real-time UI updates
    /// - Parameters:
    ///   - url: The YouTube video URL
    ///   - onPartialResult: Callback for streaming partial results
    func summarizeVideoStreaming(
        url: String,
        videoId: String,
        userId: String,
        onPartialResult: @escaping (String) -> Void
    ) async throws -> VideoSummary {
        guard let model = model else {
            throw GeminiError.modelNotInitialized
        }

        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            let prompt = """
            Analyze this YouTube video and extract actionable insights:
            \(url)

            Return a JSON object with this exact structure:
            \(GeminiResponse.jsonSchema)
            """

            var fullResponse = ""

            // Stream the response
            let contentStream = try model.generateContentStream(prompt)

            for try await chunk in contentStream {
                if let text = chunk.text {
                    fullResponse += text
                    onPartialResult(fullResponse)
                }
            }

            // Parse the complete JSON response
            guard let jsonData = fullResponse.data(using: .utf8) else {
                throw GeminiError.invalidJSON
            }

            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: jsonData)

            let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"

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
            let geminiError = GeminiError.apiError(error.localizedDescription)
            errorMessage = geminiError.localizedDescription
            throw geminiError
        }
    }
}

// MARK: - Error Types
enum GeminiError: LocalizedError {
    case modelNotInitialized
    case emptyResponse
    case invalidJSON
    case videoNotAccessible
    case quotaExceeded
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "AI model not initialized. Please restart the app."
        case .emptyResponse:
            return "Received empty response from AI. Please try again."
        case .invalidJSON:
            return "Failed to parse AI response. Please try again."
        case .videoNotAccessible:
            return "Cannot access this video. It may be private or age-restricted."
        case .quotaExceeded:
            return "API quota exceeded. Please try again later."
        case .apiError(let message):
            return "AI Error: \(message)"
        }
    }
}
