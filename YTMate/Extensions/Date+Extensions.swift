import Foundation

extension Date {
    /// Format date as relative time (e.g., "2 hours ago", "Yesterday")
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format date for display (e.g., "Dec 27, 2025")
    var displayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Format date with time (e.g., "Dec 27, 2025 at 3:45 PM")
    var displayFormattedWithTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is within the last week
    var isWithinLastWeek: Bool {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return self > weekAgo
    }

    /// Group label for date (Today, Yesterday, This Week, Earlier)
    var groupLabel: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isWithinLastWeek {
            return "This Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: self)
        }
    }
}

// MARK: - Timestamp Formatting
extension Int {
    /// Format seconds as timestamp (MM:SS or HH:MM:SS)
    var formattedAsTimestamp: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format seconds as duration string (e.g., "5 min", "1 hr 30 min")
    var formattedAsDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours) hr \(minutes) min"
            } else {
                return "\(hours) hr"
            }
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(self) sec"
        }
    }
}
