import SwiftUI

/// View for manually adding a YouTube video URL
/// Supports paste from clipboard, manual entry, and URL validation
struct AddVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var geminiService: GeminiService
    @EnvironmentObject private var authService: AuthService

    @State private var urlText: String = ""
    @State private var clipboardURL: String?
    @State private var isValidURL: Bool = false
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    /// Callback when video is successfully processed
    var onVideoAdded: ((VideoSummary) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header illustration
                    headerSection

                    // Clipboard suggestion
                    if let clipboardURL = clipboardURL, urlText.isEmpty {
                        clipboardSuggestion(clipboardURL)
                    }

                    // URL input field
                    urlInputSection

                    // Video preview (if valid URL)
                    if isValidURL, let videoId = YouTubeURLParser.extractVideoId(from: urlText) {
                        videoPreview(videoId: videoId)
                    }

                    // Process button
                    processButton

                    // Supported formats hint
                    supportedFormatsHint

                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkClipboard()
            }
            .onChange(of: urlText) { _, newValue in
                validateURL(newValue)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "link.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Paste a YouTube link")
                .font(.title3.weight(.semibold))

            Text("We'll extract actionable insights in seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Clipboard Suggestion

    private func clipboardSuggestion(_ url: String) -> some View {
        Button {
            urlText = url
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Paste from clipboard")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - URL Input Section

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube URL")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)

                TextField("https://youtube.com/watch?v=...", text: $urlText)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                if !urlText.isEmpty {
                    Button {
                        urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                // Paste button
                Button {
                    if let pasteboardString = UIPasteboard.general.string {
                        urlText = pasteboardString
                    }
                } label: {
                    Text("Paste")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Validation feedback
            if !urlText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: isValidURL ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(isValidURL ? "Valid YouTube URL" : "Please enter a valid YouTube URL")
                }
                .font(.caption)
                .foregroundStyle(isValidURL ? .green : .orange)
            }
        }
    }

    // MARK: - Video Preview

    private func videoPreview(videoId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                ProgressView()
                            )
                    }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Video ID: \(videoId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Ready to analyze")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        Button {
            Task {
                await processVideo()
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "brain.head.profile")
                }
                Text(isProcessing ? "Analyzing..." : "Get Insights")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isValidURL && !isProcessing
                    ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isValidURL || isProcessing)
    }

    // MARK: - Supported Formats Hint

    private var supportedFormatsHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported formats")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(supportedFormats, id: \.self) { format in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(format)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var supportedFormats: [String] {
        [
            "youtube.com/watch?v=VIDEO_ID",
            "youtu.be/VIDEO_ID",
            "youtube.com/shorts/VIDEO_ID",
            "m.youtube.com/watch?v=VIDEO_ID"
        ]
    }

    // MARK: - Methods

    private func checkClipboard() {
        guard let pasteboardString = UIPasteboard.general.string else { return }

        if YouTubeURLParser.isValidYouTubeURL(pasteboardString) {
            clipboardURL = pasteboardString
        }
    }

    private func validateURL(_ url: String) {
        isValidURL = YouTubeURLParser.isValidYouTubeURL(url)
    }

    private func processVideo() async {
        guard let videoId = YouTubeURLParser.extractVideoId(from: urlText),
              let userId = authService.currentUserId else {
            errorMessage = "Invalid URL or not signed in"
            showError = true
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let summary = try await geminiService.summarizeVideo(
                url: urlText,
                videoId: videoId,
                userId: userId
            )

            onVideoAdded?(summary)
            dismiss()
        } catch let error as GeminiError {
            errorMessage = error.userMessage
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }
}

// MARK: - Preview

#Preview {
    AddVideoView()
        .environmentObject(GeminiService.shared)
        .environmentObject(AuthService.shared)
}
