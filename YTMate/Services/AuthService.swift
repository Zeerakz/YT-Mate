import Foundation
import AuthenticationServices
import FirebaseAuth
import CryptoKit

/// Service for handling authentication with Sign in with Apple
/// Integrates with Firebase Auth for user management
@MainActor
final class AuthService: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = AuthService()

    /// Current authenticated user
    @Published private(set) var currentUser: User?

    /// Authentication state
    @Published private(set) var isAuthenticated = false

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message
    @Published private(set) var errorMessage: String?

    /// Nonce for Sign in with Apple
    private var currentNonce: String?

    /// Auth state listener handle
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    override private init() {
        super.init()
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Setup Firebase Auth state listener
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    /// Get the current user ID
    var userId: String? {
        currentUser?.uid
    }

    /// Get the current user's display name
    var displayName: String? {
        currentUser?.displayName
    }

    /// Get the current user's email
    var email: String? {
        currentUser?.email
    }

    // MARK: - Sign in with Apple

    /// Start Sign in with Apple flow
    /// - Returns: ASAuthorizationAppleIDRequest configured for the app
    func createAppleIDRequest() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return request
    }

    /// Handle Sign in with Apple authorization
    /// - Parameter authorization: The ASAuthorization from the delegate
    func handleAuthorization(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }

        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }

        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Create Firebase credential
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            // Sign in with Firebase
            let result = try await Auth.auth().signIn(with: credential)

            // Update display name if available from Apple
            if let fullName = appleIDCredential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            }

            currentUser = result.user
            isAuthenticated = true

        } catch {
            errorMessage = error.localizedDescription
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }

    /// Handle Sign in with Apple error
    /// - Parameter error: The error from ASAuthorizationController
    func handleAuthorizationError(_ error: Error) {
        let authError = error as? ASAuthorizationError

        switch authError?.code {
        case .canceled:
            errorMessage = nil // User canceled, not an error
        case .failed:
            errorMessage = "Sign in failed. Please try again."
        case .invalidResponse:
            errorMessage = "Invalid response from Apple. Please try again."
        case .notHandled:
            errorMessage = "Sign in request was not handled."
        case .notInteractive:
            errorMessage = "Sign in requires user interaction."
        case .unknown:
            errorMessage = "An unknown error occurred."
        default:
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }

    // MARK: - Account Management

    /// Delete the current user's account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.noCurrentUser
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Delete user data from Firestore first
            try await FirestoreService.shared.deleteSummaries(
                try await FirestoreService.shared.fetchSummaries(for: user.uid)
            )

            // Delete Firebase Auth account
            try await user.delete()

            currentUser = nil
            isAuthenticated = false
        } catch {
            throw AuthError.deleteFailed(error.localizedDescription)
        }
    }

    /// Check if the Apple ID credential is still valid
    func checkCredentialState() async {
        guard let userId = currentUser?.providerData.first(where: { $0.providerID == "apple.com" })?.uid else {
            return
        }

        do {
            let credentialState = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userId)

            switch credentialState {
            case .revoked:
                try signOut()
            case .authorized:
                break // All good
            case .notFound:
                try signOut()
            case .transferred:
                break // Handle transfer if needed
            @unknown default:
                break
            }
        } catch {
            print("Failed to check credential state: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Generate a random nonce string
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// SHA256 hash of the input string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

// MARK: - Error Types
enum AuthError: LocalizedError {
    case invalidCredential
    case invalidNonce
    case invalidToken
    case signInFailed(String)
    case signOutFailed(String)
    case noCurrentUser
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential."
        case .invalidNonce:
            return "Invalid state. Please try again."
        case .invalidToken:
            return "Unable to fetch identity token."
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .noCurrentUser:
            return "No user is currently signed in."
        case .deleteFailed(let message):
            return "Account deletion failed: \(message)"
        }
    }
}
