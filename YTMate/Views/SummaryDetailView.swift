import SwiftUI

/// Detailed view of a video summary with all action items
struct SummaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let summary: VideoSummary

    @State private var showingShareSheet = false
    @State private var showingEditNote = false
    @State private var editedNote: String = ""

    private var vibeCategory: VibeCategory {
        VibeCategory.from(string: summary.vibeCategory)
    }

    private var difficultyLevel: DifficultyLevel {
        DifficultyLevel.from(string: summary.difficultyLevel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Video thumbnail and info
                videoHeader

                // TL;DR
                tldrSection

                // Quick stats
                statsSection

                // Action items
                actionItemsSection

                // User notes
                if let notes = summary.userNotes, !notes.isEmpty {
                    userNotesSection(notes)
                }

                // Metadata footer
                metadataFooter
            }
            .padding()
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingEditNote = true
                    editedNote = summary.userNotes ?? ""
                } label: {
                    Image(systemName: "note.text.badge.plus")
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingEditNote) {
            editNoteSheet
        }
    }

    // MARK: - Subviews

    private var videoHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with play button overlay
            AsyncImage(url: URL(string: summary.thumbnailURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay { ProgressView() }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .center) {
                // Play button overlay
                Link(destination: URL(string: summary.videoURL)!) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                }
            }

            // Title
            if let title = summary.videoTitle {
                Text(title)
                    .font(.title3.weight(.semibold))
            }

            // Category and difficulty badges
            HStack(spacing: 8) {
                categoryBadge
                difficultyBadge
            }
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vibeCategory.iconName)
            Text(vibeCategory.displayName)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(vibeCategory.color.opacity(0.15))
        .foregroundStyle(vibeCategory.color)
        .clipShape(Capsule())
    }

    private var difficultyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: difficultyLevel.iconName)
            Text(difficultyLevel.displayName)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(difficultyLevel.color.opacity(0.15))
        .foregroundStyle(difficultyLevel.color)
        .clipShape(Capsule())
    }

    private var tldrSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("TL;DR", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(summary.tldr)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            statItem(
                icon: "list.bullet",
                value: "\(summary.actionItems.count)",
                label: "Actions"
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: "clock",
                value: totalDuration,
                label: "Content"
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: vibeCategory.iconName,
                value: vibeCategory.displayName,
                label: "Type"
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalDuration: String {
        guard let lastTimestamp = summary.actionItems.max(by: { $0.timestampSeconds < $1.timestampSeconds })?.timestampSeconds else {
            return "N/A"
        }

        let minutes = lastTimestamp / 60
        return "\(minutes)+ min"
    }

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Action Plan", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(summary.actionItems.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { item in
                ActionItemRow(
                    item: item,
                    videoURL: summary.videoURL
                )
            }
        }
    }

    private func userNotesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Saved")
                Text(summary.createdAt, style: .date)
                Text("at")
                Text(summary.createdAt, style: .time)
            }

            if !summary.isSynced {
                Label("Pending sync", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    // MARK: - Edit Note Sheet

    private var editNoteSheet: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $editedNote)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("Personal Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditNote = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        summary.userNotes = editedNote.isEmpty ? nil : editedNote
                        summary.updatedAt = Date()
                        try? modelContext.save()
                        showingEditNote = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Share Text

    private var shareText: String {
        var text = ""

        if let title = summary.videoTitle {
            text += "\(title)\n\n"
        }

        text += "TL;DR: \(summary.tldr)\n\n"
        text += "Key Actions:\n"

        for (index, item) in summary.actionItems.enumerated() {
            text += "\(index + 1). \(item.emoji) \(item.headline)\n"
        }

        text += "\n\(summary.videoURL)"
        text += "\n\nGenerated by YT Mate"

        return text
    }
}

#Preview {
    NavigationStack {
        SummaryDetailView(
            summary: GeminiResponse.sample.toVideoSummary(
                videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                videoId: "dQw4w9WgXcQ",
                videoTitle: "Master Portrait Photography: Professional Lighting Techniques",
                thumbnailURL: "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
                userId: "preview"
            )
        )
    }
}
