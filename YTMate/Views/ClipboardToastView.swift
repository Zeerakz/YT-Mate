import SwiftUI

/// Toast notification for clipboard-detected YouTube URLs
/// Appears at the top of the screen when a YouTube URL is detected
struct ClipboardToastView: View {
    let url: String
    let onSummarize: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    private var videoId: String? {
        YouTubeURLParser.extractVideoId(from: url)
    }

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Thumbnail
                if let videoId = videoId {
                    AsyncImage(url: URL(string: YouTubeURLParser.thumbnailURL(for: videoId, quality: .medium))) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay {
                                    Image(systemName: "play.rectangle")
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 60, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text("YouTube link detected")
                        .font(.subheadline.weight(.semibold))

                    Text("Tap to summarize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSummarize()
                        }
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.blue)
                            .clipShape(Circle())
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            )
            .padding(.horizontal)
            .offset(y: isVisible ? 0 : -100)
            .opacity(isVisible ? 1 : 0)

            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if isVisible {
                    withAnimation(.spring(response: 0.3)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Minimal Toast
struct MinimalToastView: View {
    let message: String
    let icon: String
    let style: ToastStyle

    @State private var isVisible = false

    enum ToastStyle {
        case success, error, info

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(style.color)

                Text(message)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
            .offset(y: isVisible ? 0 : -50)
            .opacity(isVisible ? 1 : 0)

            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(response: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            ClipboardToastView(
                url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                onSummarize: {},
                onDismiss: {}
            )
        }
    }
}
