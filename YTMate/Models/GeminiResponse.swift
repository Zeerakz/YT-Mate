import Foundation

/// Response schema from Gemini 3 Flash API
/// Matches the structured JSON output enforced via system instructions
struct GeminiResponse: Codable {
    /// The "TL;DR" - 2-sentence high-level summary
    let summary: String

    /// Difficulty level of the content
    let difficultyLevel: String

    /// The "Vibe Check" - 1-word category tag
    let vibeCategory: String

    /// Action items extracted from the video
    let actionItems: [GeminiActionItem]

    enum CodingKeys: String, CodingKey {
        case summary
        case difficultyLevel = "difficulty_level"
        case vibeCategory = "vibe_category"
        case actionItems = "action_items"
    }
}

/// Action item from Gemini response
struct GeminiActionItem: Codable {
    /// Emoji representing the action type
    let emoji: String

    /// Short headline/action verb
    let headline: String

    /// Detailed context or instructions
    let detail: String

    /// Timestamp in seconds
    let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case emoji
        case headline
        case detail
        case timestamp
    }
}

// MARK: - Conversion to Domain Models
extension GeminiResponse {
    /// Convert Gemini response to VideoSummary
    func toVideoSummary(
        videoURL: String,
        videoId: String,
        videoTitle: String? = nil,
        thumbnailURL: String? = nil,
        userId: String
    ) -> VideoSummary {
        let summary = VideoSummary(
            videoURL: videoURL,
            videoId: videoId,
            videoTitle: videoTitle,
            thumbnailURL: thumbnailURL,
            tldr: self.summary,
            difficultyLevel: difficultyLevel,
            vibeCategory: vibeCategory,
            userId: userId
        )

        // Create action items with proper ordering
        let actionItems = self.actionItems.enumerated().map { index, item in
            ActionItem(
                emoji: item.emoji,
                headline: item.headline,
                detail: item.detail,
                timestampSeconds: item.timestamp,
                orderIndex: index,
                videoSummary: summary
            )
        }

        summary.actionItems = actionItems
        return summary
    }
}

// MARK: - Sample Data for Testing/Previews
extension GeminiResponse {
    static var sample: GeminiResponse {
        GeminiResponse(
            summary: "This comprehensive photography tutorial covers essential lighting techniques for portrait photography. The instructor demonstrates professional setups using affordable equipment that beginners can easily replicate.",
            difficultyLevel: "Intermediate",
            vibeCategory: "Tutorial",
            actionItems: [
                GeminiActionItem(
                    emoji: "💡",
                    headline: "Place key light at 45-degree angle",
                    detail: "Position your main light source at 45 degrees from the subject's face to create flattering shadows that add depth.",
                    timestamp: 45
                ),
                GeminiActionItem(
                    emoji: "🪞",
                    headline: "Use reflector on shadow side",
                    detail: "A simple white foam board can bounce light back into shadows, reducing harsh contrast.",
                    timestamp: 120
                ),
                GeminiActionItem(
                    emoji: "📷",
                    headline: "Set aperture between f/2.8-f/4",
                    detail: "This aperture range provides pleasing background blur while keeping the entire face in focus.",
                    timestamp: 210
                ),
                GeminiActionItem(
                    emoji: "🎨",
                    headline: "Match color temperature of all lights",
                    detail: "Mixing daylight and tungsten creates color casts. Use gels or consistent bulb types.",
                    timestamp: 340
                ),
                GeminiActionItem(
                    emoji: "👁️",
                    headline: "Focus on the nearest eye",
                    detail: "Sharp eyes are critical for portraits. Always focus on the eye closest to the camera.",
                    timestamp: 425
                )
            ]
        )
    }
}

// MARK: - JSON Schema for Gemini
extension GeminiResponse {
    /// The JSON schema string to enforce structured output from Gemini
    static var jsonSchema: String {
        """
        {
          "type": "object",
          "properties": {
            "summary": {
              "type": "string",
              "description": "A 2-sentence TL;DR summary of the video's key value proposition"
            },
            "difficulty_level": {
              "type": "string",
              "enum": ["Beginner", "Intermediate", "Advanced", "Expert"],
              "description": "The skill level required to benefit from this content"
            },
            "vibe_category": {
              "type": "string",
              "enum": ["Technical", "Motivational", "Educational", "Tutorial", "Entertainment", "News", "Satire", "Review", "Vlog", "Interview", "Documentary", "How-To", "Other"],
              "description": "A single word describing the content type/vibe"
            },
            "action_items": {
              "type": "array",
              "description": "5-10 actionable items extracted from the video",
              "items": {
                "type": "object",
                "properties": {
                  "emoji": {
                    "type": "string",
                    "description": "A single emoji that represents this action"
                  },
                  "headline": {
                    "type": "string",
                    "description": "A short, actionable headline starting with a verb (e.g., 'Place key light at 45-degree angle')"
                  },
                  "detail": {
                    "type": "string",
                    "description": "Additional context or instructions for this action item"
                  },
                  "timestamp": {
                    "type": "integer",
                    "description": "The timestamp in seconds where this item is discussed in the video"
                  }
                },
                "required": ["emoji", "headline", "detail", "timestamp"]
              },
              "minItems": 5,
              "maxItems": 10
            }
          },
          "required": ["summary", "difficulty_level", "vibe_category", "action_items"]
        }
        """
    }
}
