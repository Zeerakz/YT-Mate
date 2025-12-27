import SwiftUI

/// Animated loading view with "brain" pulsing animation
/// Shown while AI is processing the video
struct LoadingView: View {
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0

    let message: String

    init(message: String = "Analyzing video...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            // Animated brain icon
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.5 : 1.0)

                // Inner circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                // Brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(rotationAngle))

                // Orbiting particles
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.blue.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(y: -50)
                        .rotationEffect(.degrees(rotationAngle + Double(index * 120)))
                }
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }

                withAnimation(
                    .linear(duration: 3)
                    .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360
                }
            }

            // Loading text
            VStack(spacing: 8) {
                Text(message)
                    .font(.headline)

                Text("This usually takes 3-5 seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Compact Loading Indicator
struct CompactLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Skeleton Loading
struct SkeletonLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 180)
                .shimmer(isAnimating: isAnimating)

            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 24)
                .shimmer(isAnimating: isAnimating)

            // Summary skeleton
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                        .shimmer(isAnimating: isAnimating)
                }
            }

            // Action items skeleton
            VStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 32, height: 32)
                            .shimmer(isAnimating: isAnimating)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 16)
                                .shimmer(isAnimating: isAnimating)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 12)
                                .shimmer(isAnimating: isAnimating)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Effect
extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
            }
            .mask(self)
        )
    }
}

#Preview {
    VStack {
        LoadingView()

        Divider()

        CompactLoadingView()
            .padding()

        Divider()

        SkeletonLoadingView()
    }
}
