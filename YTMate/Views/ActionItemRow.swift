import SwiftUI

/// Row view for displaying a single action item
/// Includes timestamp link to jump to that point in the video
struct ActionItemRow: View {
    let item: ActionItem
    let videoURL: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with emoji and headline
            HStack(alignment: .top, spacing: 10) {
                Text(item.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.headline)
                        .font(.subheadline.weight(.semibold))

                    // Timestamp link
                    if let timestampURL = item.youtubeURLWithTimestamp(baseURL: videoURL) {
                        Link(destination: timestampURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption)
                                Text(item.formattedTimestamp)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                // Expand/collapse button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Detail text (shown when expanded)
            if isExpanded {
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 42) // Align with headline
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Compact Version
struct ActionItemCompactRow: View {
    let item: ActionItem

    var body: some View {
        HStack(spacing: 8) {
            Text(item.emoji)
                .font(.body)

            Text(item.headline)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(item.formattedTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActionItemRow(
            item: ActionItem(
                emoji: "💡",
                headline: "Place key light at 45-degree angle",
                detail: "Position your main light source at 45 degrees from the subject's face to create flattering shadows that add depth and dimension to portraits.",
                timestampSeconds: 125,
                orderIndex: 0
            ),
            videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )

        ActionItemCompactRow(
            item: ActionItem(
                emoji: "🪞",
                headline: "Use reflector on shadow side",
                detail: "A simple white foam board can bounce light back into shadows.",
                timestampSeconds: 210,
                orderIndex: 1
            )
        )
        .padding(.horizontal)
    }
    .padding()
}
