import Foundation
import SwiftUI

/// Predefined categories for auto-sorting summaries based on content "vibe"
enum VibeCategory: String, CaseIterable, Codable {
    case technical = "Technical"
    case motivational = "Motivational"
    case educational = "Educational"
    case tutorial = "Tutorial"
    case entertainment = "Entertainment"
    case news = "News"
    case satire = "Satire"
    case review = "Review"
    case vlog = "Vlog"
    case interview = "Interview"
    case documentary = "Documentary"
    case howTo = "How-To"
    case other = "Other"

    /// Display name for the category
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon for the category
    var iconName: String {
        switch self {
        case .technical:
            return "gearshape.2"
        case .motivational:
            return "flame"
        case .educational:
            return "graduationcap"
        case .tutorial:
            return "play.rectangle"
        case .entertainment:
            return "sparkles.tv"
        case .news:
            return "newspaper"
        case .satire:
            return "theatermasks"
        case .review:
            return "star.bubble"
        case .vlog:
            return "video"
        case .interview:
            return "person.2"
        case .documentary:
            return "film"
        case .howTo:
            return "wrench.and.screwdriver"
        case .other:
            return "questionmark.folder"
        }
    }

    /// Theme color for the category
    var color: Color {
        switch self {
        case .technical:
            return .blue
        case .motivational:
            return .orange
        case .educational:
            return .purple
        case .tutorial:
            return .green
        case .entertainment:
            return .pink
        case .news:
            return .gray
        case .satire:
            return .yellow
        case .review:
            return .indigo
        case .vlog:
            return .cyan
        case .interview:
            return .teal
        case .documentary:
            return .brown
        case .howTo:
            return .mint
        case .other:
            return .secondary
        }
    }

    /// Create from string (with fallback)
    static func from(string: String) -> VibeCategory {
        // Try exact match first
        if let category = VibeCategory(rawValue: string) {
            return category
        }

        // Try case-insensitive match
        let lowercased = string.lowercased()
        for category in VibeCategory.allCases {
            if category.rawValue.lowercased() == lowercased {
                return category
            }
        }

        // Try partial match for common variations
        if lowercased.contains("tech") {
            return .technical
        } else if lowercased.contains("motiv") || lowercased.contains("inspir") {
            return .motivational
        } else if lowercased.contains("edu") || lowercased.contains("learn") {
            return .educational
        } else if lowercased.contains("tutor") {
            return .tutorial
        } else if lowercased.contains("entertain") || lowercased.contains("fun") {
            return .entertainment
        } else if lowercased.contains("news") {
            return .news
        } else if lowercased.contains("satire") || lowercased.contains("comedy") {
            return .satire
        } else if lowercased.contains("review") {
            return .review
        } else if lowercased.contains("vlog") {
            return .vlog
        } else if lowercased.contains("interview") {
            return .interview
        } else if lowercased.contains("doc") {
            return .documentary
        } else if lowercased.contains("how") {
            return .howTo
        }

        return .other
    }
}

// MARK: - Difficulty Level
enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"

    /// Display name
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon
    var iconName: String {
        switch self {
        case .beginner:
            return "1.circle"
        case .intermediate:
            return "2.circle"
        case .advanced:
            return "3.circle"
        case .expert:
            return "star.circle"
        }
    }

    /// Theme color
    var color: Color {
        switch self {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .orange
        case .expert:
            return .red
        }
    }

    /// Create from string (with fallback)
    static func from(string: String) -> DifficultyLevel {
        if let level = DifficultyLevel(rawValue: string) {
            return level
        }

        let lowercased = string.lowercased()
        if lowercased.contains("begin") || lowercased.contains("easy") || lowercased.contains("intro") {
            return .beginner
        } else if lowercased.contains("inter") || lowercased.contains("medium") {
            return .intermediate
        } else if lowercased.contains("adv") || lowercased.contains("hard") {
            return .advanced
        } else if lowercased.contains("expert") || lowercased.contains("pro") {
            return .expert
        }

        return .intermediate
    }
}
