import SwiftUI

// MARK: - Conditional Modifiers
extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a modifier if a value is not nil
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Card Style
extension View {
    /// Apply card styling with rounded corners and shadow
    func cardStyle(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 4,
        shadowY: CGFloat = 2
    ) -> some View {
        self
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: shadowRadius, y: shadowY)
    }
}

// MARK: - Hide Keyboard
extension View {
    /// Hide keyboard when tapping outside
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

// MARK: - Haptic Feedback
extension View {
    /// Trigger haptic feedback
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onAppear {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }

    /// Trigger notification haptic
    func notificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) -> some View {
        self.onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(type)
        }
    }
}

// MARK: - Loading Overlay
extension View {
    /// Show loading overlay
    func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        if let message = message {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

// MARK: - Navigation
extension View {
    /// Embed in NavigationStack
    func embedInNavigation() -> some View {
        NavigationStack {
            self
        }
    }
}

// MARK: - Debug
extension View {
    /// Print view size for debugging
    func debugSize(_ label: String = "") -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        print("\(label) size: \(geometry.size)")
                    }
            }
        )
    }

    /// Add debug border
    func debugBorder(_ color: Color = .red) -> some View {
        self.border(color, width: 1)
    }
}

// MARK: - Accessibility
extension View {
    /// Add combined accessibility label and hint
    func accessibilityInfo(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
    }
}

// MARK: - Animation
extension View {
    /// Apply spring animation with standard parameters
    func standardSpring() -> some View {
        self.animation(.spring(response: 0.3, dampingFraction: 0.7), value: UUID())
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Apply shimmer loading effect
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}
