import SwiftUI
import SwiftData

/// Root content view handling authentication state and navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var clipboardService: ClipboardService
    @Environment(\.modelContext) private var modelContext

    @State private var pendingURL: String?
    @State private var pendingSummaryId: String?
    @State private var showingSummarySheet = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                LibraryView()
            } else {
                AuthView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .processYouTubeURL)) { notification in
            handleProcessURLNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSummary)) { notification in
            handleNavigateNotification(notification)
        }
        .sheet(isPresented: $showingSummarySheet) {
            if let url = pendingURL {
                SummarySheetView(
                    url: url,
                    userId: authService.userId ?? "",
                    onSave: { _ in
                        pendingURL = nil
                        showingSummarySheet = false
                    },
                    onDismiss: {
                        pendingURL = nil
                        showingSummarySheet = false
                    }
                )
            }
        }
        .task {
            // Check Apple ID credential state on launch
            await authService.checkCredentialState()

            // Check clipboard for YouTube URL
            clipboardService.checkClipboard()
        }
    }

    // MARK: - Notification Handlers

    private func handleProcessURLNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? String else {
            return
        }

        pendingURL = url
        showingSummarySheet = true
    }

    private func handleNavigateNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let summaryId = userInfo["summaryId"] as? String else {
            return
        }

        pendingSummaryId = summaryId

        // Navigation will be handled by LibraryView
        NotificationCenter.default.post(
            name: .internalNavigateToSummary,
            object: nil,
            userInfo: ["summaryId": summaryId]
        )
    }
}

// MARK: - Internal Navigation
extension Notification.Name {
    static let internalNavigateToSummary = Notification.Name("internalNavigateToSummary")
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(ClipboardService.shared)
        .modelContainer(for: VideoSummary.self, inMemory: true)
}
