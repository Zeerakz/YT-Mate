import SwiftUI
import AuthenticationServices

/// Authentication view with Sign in with Apple
struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App branding
            VStack(spacing: 16) {
                // App icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }

                Text("YT Mate")
                    .font(.largeTitle.weight(.bold))

                Text("Click Share, Get Smarter")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "bolt.fill",
                    title: "Instant Summaries",
                    description: "Get actionable insights in seconds"
                )

                featureRow(
                    icon: "brain.head.profile",
                    title: "AI-Powered",
                    description: "Powered by Gemini 3 Flash"
                )

                featureRow(
                    icon: "icloud.fill",
                    title: "Sync Everywhere",
                    description: "Access your library on all devices"
                )

                featureRow(
                    icon: "magnifyingglass",
                    title: "Spotlight Search",
                    description: "Find tips from your home screen"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Sign in with Apple button
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Sign in to sync your summaries across devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await AuthService.shared.handleAuthorization(authorization)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }

        case .failure(let error):
            AuthService.shared.handleAuthorizationError(error)
            if let authError = error as? ASAuthorizationError, authError.code != .canceled {
                viewModel.errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Compact Sign In Button
struct CompactSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    AuthView()
}
