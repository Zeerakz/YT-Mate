import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck
import CoreSpotlight

/// Main app entry point for YT Mate
@main
struct YTMateApp: App {
    /// SwiftData model container for offline persistence
    let modelContainer: ModelContainer

    /// Auth service for user authentication state
    @StateObject private var authService = AuthService.shared

    /// Clipboard service for URL detection
    @StateObject private var clipboardService = ClipboardService.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure App Check for security
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Configure SwiftData model container
        do {
            let schema = Schema([
                VideoSummary.self,
                ActionItem.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.com.ytmate.app")
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(clipboardService)
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    handleSpotlightActivity(userActivity)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Deep Link Handling

    /// Handle Spotlight search result tap
    private func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let result = SpotlightService.parseSpotlightActivity(userActivity) else {
            return
        }

        // Navigate to the summary
        NotificationCenter.default.post(
            name: .navigateToSummary,
            object: nil,
            userInfo: [
                "summaryId": result.summaryId,
                "actionItemId": result.actionItemId as Any
            ]
        )
    }

    /// Handle incoming URL (e.g., from Share Extension or deep link)
    private func handleIncomingURL(_ url: URL) {
        // Check if it's a YouTube URL
        if let videoId = YouTubeURLParser.extractVideoId(from: url.absoluteString) {
            NotificationCenter.default.post(
                name: .processYouTubeURL,
                object: nil,
                userInfo: [
                    "url": url.absoluteString,
                    "videoId": videoId
                ]
            )
        }

        // Check if it's an internal deep link
        if url.scheme == "ytmate" {
            handleDeepLink(url)
        }
    }

    /// Handle internal deep links
    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        switch host {
        case "summary":
            // ytmate://summary/{id}
            if let summaryId = url.pathComponents.dropFirst().first {
                NotificationCenter.default.post(
                    name: .navigateToSummary,
                    object: nil,
                    userInfo: ["summaryId": summaryId]
                )
            }

        case "summarize":
            // ytmate://summarize?url={youtube_url}
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value {
                NotificationCenter.default.post(
                    name: .processYouTubeURL,
                    object: nil,
                    userInfo: ["url": urlParam]
                )
            }

        default:
            break
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToSummary = Notification.Name("navigateToSummary")
    static let processYouTubeURL = Notification.Name("processYouTubeURL")
}

// MARK: - App Check Provider Factory
#if DEBUG
class AppCheckDebugProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppCheckDebugProvider(app: app)
    }
}
#else
class DeviceCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return DeviceCheckProvider(app: app)
    }
}
#endif
