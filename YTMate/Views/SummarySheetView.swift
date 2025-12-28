import SwiftUI
import SwiftData

/// Half-height modal sheet for displaying generated summary
/// Shows loading state, result, and save options (Apple Maps style)
struct SummarySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let url: String
    let userId: String
    let onSave: (VideoSummary) -> Void
    let onDismiss: () -> Void

    @State private var viewModel = SummaryViewModel()
    @State private var userNote = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                switch viewModel.state {
                case .idle, .loading:
                    loadingContent

                case .success:
                    if let summary = viewModel.summary {
                        successContent(summary)
                    }

                case .error:
                    errorContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(viewModel.state.isSuccess ? "Summary" : "Analyzing")
                        .font(.headline)
                }

                if viewModel.state.isSuccess {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(viewModel.state.isLoading)
        .task {
            await viewModel.generateSummary(for: url, userId: userId)
        }
    }

    // MARK: - Loading Content

    private var loadingContent: some View {
        VStack(spacing: 24) {
            Spacer()

            LoadingView(message: "Analyzing video...")

            // URL being processed
            Text(url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Success Content

    private func successContent(_ summary: VideoSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Video thumbnail
                if let thumbnailURL = summary.thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 180)
                        }
                    }
                }

                // Category and difficulty badges
                HStack(spacing: 8) {
                    let vibeCategory = VibeCategory.from(string: summary.vibeCategory)
                    let difficultyLevel = DifficultyLevel.from(string: summary.difficultyLevel)

                    HStack(spacing: 4) {
                        Image(systemName: vibeCategory.iconName)
                        Text(vibeCategory.displayName)
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vibeCategory.color.opacity(0.15))
                    .foregroundStyle(vibeCategory.color)
                    .clipShape(Capsule())

                    HStack(spacing: 4) {
                        Image(systemName: difficultyLevel.iconName)
                        Text(difficultyLevel.displayName)
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyLevel.color.opacity(0.15))
                    .foregroundStyle(difficultyLevel.color)
                    .clipShape(Capsule())
                }

                // TL;DR
                VStack(alignment: .leading, spacing: 8) {
                    Label("TL;DR", systemImage: "text.quote")
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
                    Label("\(summary.actionItems.count) Action Items", systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(summary.actionItems.prefix(3), id: \.id) { item in
                        HStack(spacing: 8) {
                            Text(item.emoji)
                            Text(item.headline)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(item.formattedTimestamp)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if summary.actionItems.count > 3 {
                        Text("+ \(summary.actionItems.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Add note section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add Note (Optional)", systemImage: "note.text.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Add a personal note...", text: $userNote, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Error Content

    private var errorContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Unable to Analyze Video")
                    .font(.headline)

                Text(viewModel.errorMessage ?? "An unexpected error occurred")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await viewModel.retry(userId: userId)
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        guard let summary = viewModel.summary else { return }

        isSaving = true

        // Add user note
        if !userNote.isEmpty {
            summary.userNotes = userNote
        }

        Task {
            do {
                try await viewModel.saveSummary(context: modelContext)
                onSave(summary)
                dismiss()
            } catch {
                // Handle save error
                isSaving = false
            }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SummarySheetView(
                url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                userId: "preview",
                onSave: { _ in },
                onDismiss: {}
            )
        }
}
