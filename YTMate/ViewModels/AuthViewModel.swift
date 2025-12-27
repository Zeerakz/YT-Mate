import Foundation
import AuthenticationServices

/// ViewModel for authentication UI
/// Wraps AuthService for use in SwiftUI views
@MainActor
@Observable
final class AuthViewModel: NSObject {
    /// Current auth state
    var isAuthenticated: Bool {
        AuthService.shared.isAuthenticated
    }

    /// Current user ID
    var userId: String? {
        AuthService.shared.userId
    }

    /// Current user display name
    var displayName: String? {
        AuthService.shared.displayName
    }

    /// Current user email
    var email: String? {
        AuthService.shared.email
    }

    /// Loading state
    var isLoading = false

    /// Error message
    var errorMessage: String?

    /// Show delete account confirmation
    var showDeleteConfirmation = false

    /// Completion handler for Sign in with Apple
    private var signInCompletion: ((Result<Void, Error>) -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Sign In

    /// Start Sign in with Apple flow
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        return try await withCheckedThrowingContinuation { continuation in
            signInCompletion = { result in
                continuation.resume(with: result)
            }

            let request = AuthService.shared.createAppleIDRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() {
        do {
            try AuthService.shared.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Account Management

    /// Delete the current user's account
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await AuthService.shared.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Check credential validity
    func checkCredentialState() async {
        await AuthService.shared.checkCredentialState()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            do {
                try await AuthService.shared.handleAuthorization(authorization)
                signInCompletion?(.success(()))
            } catch {
                signInCompletion?(.failure(error))
            }
            signInCompletion = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        AuthService.shared.handleAuthorizationError(error)

        // Only report as error if not user cancellation
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            signInCompletion?(.success(())) // Not really an error
        } else {
            signInCompletion?(.failure(error))
        }
        signInCompletion = nil
    }
}

// MARK: - Preview Support
extension AuthViewModel {
    static var preview: AuthViewModel {
        AuthViewModel()
    }
}
