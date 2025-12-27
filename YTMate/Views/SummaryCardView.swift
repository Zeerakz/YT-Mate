import SwiftUI

/// Card view displaying a video summary preview in the library list
struct SummaryCardView: View {
    let summary: VideoSummary

    private var vibeCategory: VibeCategory {
        VibeCategory.from(string: summary.vibeCategory)
    }

    private var difficultyLevel: DifficultyLevel {
        DifficultyLevel.from(string: summary.difficultyLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with thumbnail and title
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: summary.thumbnailURL ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                Image(systemName: "play.rectangle")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 100, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title and metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.videoTitle ?? "Video Summary")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        // Vibe category badge
                        HStack(spacing: 2) {
                            Image(systemName: vibeCategory.iconName)
                                .font(.caption2)
                            Text(vibeCategory.displayName)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(vibeCategory.color.opacity(0.15))
                        .foregroundStyle(vibeCategory.color)
                        .clipShape(Capsule())

                        // Difficulty level
                        HStack(spacing: 2) {
                            Image(systemName: difficultyLevel.iconName)
                                .font(.caption2)
                            Text(difficultyLevel.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // TL;DR Summary
            Text(summary.tldr)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Action items preview
            if !summary.actionItems.isEmpty {
                actionItemsPreview
            }

            // Footer with date
            HStack {
                Text(summary.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Action item count
                Label("\(summary.actionItems.count)", systemImage: "list.bullet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Note indicator
                if summary.userNotes != nil {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Sync indicator
                if !summary.isSynced {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var actionItemsPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(summary.actionItems.prefix(3), id: \.id) { item in
                HStack(spacing: 6) {
                    Text(item.emoji)
                        .font(.caption)
                    Text(item.headline)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
            }

            if summary.actionItems.count > 3 {
                Text("+ \(summary.actionItems.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let previewSummary = GeminiResponse.sample.toVideoSummary(
        videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        videoId: "dQw4w9WgXcQ",
        videoTitle: "Master Portrait Photography: Professional Lighting Techniques",
        thumbnailURL: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
        userId: "preview"
    )

    return SummaryCardView(summary: previewSummary)
        .padding()
}
