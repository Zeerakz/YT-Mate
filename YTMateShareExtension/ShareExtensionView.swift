import SwiftUI

/// SwiftUI view for the Share Extension
/// Displays a compact summary interface (Apple Maps style half-sheet)
struct ShareExtensionView: View {
    let url: String
    let onComplete: (Bool) -> Void
    let onCancel: () -> Void

    @State private var isLoading = true
    @State private var summary: ExtensionSummary?
    @State private var errorMessage: String?

    private var videoId: String? {
        YouTubeURLParser.extractVideoId(from: url)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                if isLoading {
                    loadingView
                } else if let summary = summary {
                    successView(summary)
                } else if let error = errorMessage {
                    errorView(error)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("YT Insights")
                        .font(.headline)
                }

                if summary != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open") {
                            onComplete(true)
                        }
                    }
                }
            }
        }
        .task {
            await loadSummary()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated brain icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Analyzing video...")
                    .font(.headline)

                Text("This usually takes 3-5 seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Video preview
            if let videoId = videoId {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                        }
                    }
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Success View

    private func successView(_ summary: ExtensionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail
                if let videoId = videoId {
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 160)
                        }
                    }
                }

                // Badges
                HStack(spacing: 8) {
                    Text(summary.vibeCategory)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text(summary.difficultyLevel)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                // TL;DR
                VStack(alignment: .leading, spacing: 8) {
                    Text("TL;DR")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(summary.tldr)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Action items preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summary.actionItemCount) Action Items")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(summary.previewItems.indices, id: \.self) { index in
                        let item = summary.previewItems[index]
                        HStack(spacing: 8) {
                            Text(item.emoji)
                            Text(item.headline)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }

                    if summary.actionItemCount > summary.previewItems.count {
                        Text("+ \(summary.actionItemCount - summary.previewItems.count) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Open in app hint
                Text("Tap 'Open' to save to your library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Unable to Analyze")
                    .font(.headline)

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await loadSummary()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Load Summary

    private func loadSummary() async {
        isLoading = true
        errorMessage = nil

        // Simulate API call for extension preview
        // In production, this would call the Gemini API
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay

            // Mock response for extension
            summary = ExtensionSummary(
                tldr: "This video provides practical insights on the topic. Key takeaways include actionable steps you can implement immediately.",
                vibeCategory: "Tutorial",
                difficultyLevel: "Intermediate",
                actionItemCount: 6,
                previewItems: [
                    PreviewActionItem(emoji: "💡", headline: "Key insight from the video"),
                    PreviewActionItem(emoji: "📝", headline: "Important concept explained"),
                    PreviewActionItem(emoji: "🎯", headline: "Actionable step to take")
                ]
            )
            isLoading = false
        } catch {
            errorMessage = "Failed to analyze video. Please try opening in the app."
            isLoading = false
        }
    }
}

// MARK: - Extension Models

struct ExtensionSummary {
    let tldr: String
    let vibeCategory: String
    let difficultyLevel: String
    let actionItemCount: Int
    let previewItems: [PreviewActionItem]
}

struct PreviewActionItem {
    let emoji: String
    let headline: String
}

#Preview {
    ShareExtensionView(
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        onComplete: { _ in },
        onCancel: {}
    )
}
