import SwiftUI

/// Settings view for app configuration and account management
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeleting = false

    @AppStorage("enableSpotlightIndex") private var enableSpotlightIndex = true
    @AppStorage("enableClipboardDetection") private var enableClipboardDetection = true
    @AppStorage("defaultSortOrder") private var defaultSortOrder = SortOrder.newest.rawValue

    var body: some View {
        NavigationStack {
            List {
                // Account section
                accountSection

                // Preferences section
                preferencesSection

                // Storage section
                storageSection

                // About section
                aboutSection

                // Sign out / Delete account
                if authService.isAuthenticated {
                    accountActionsSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    try? authService.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out? Your summaries will remain on this device.")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all synced summaries. This action cannot be undone.")
            }
            .overlay {
                if isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Deleting account...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if authService.isAuthenticated {
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(avatarInitials)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authService.displayName ?? "User")
                            .font(.headline)

                        if let email = authService.email {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    // Trigger sign in flow
                } label: {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Sign in with Apple")
                    }
                }
            }
        } header: {
            Text("Account")
        }
    }

    private var avatarInitials: String {
        guard let name = authService.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        Section {
            Toggle(isOn: $enableSpotlightIndex) {
                Label("Spotlight Search", systemImage: "magnifyingglass")
            }
            .onChange(of: enableSpotlightIndex) { _, newValue in
                if !newValue {
                    Task {
                        await SpotlightService.shared.removeAllItems()
                    }
                }
            }

            Toggle(isOn: $enableClipboardDetection) {
                Label("Clipboard Detection", systemImage: "doc.on.clipboard")
            }

            Picker(selection: $defaultSortOrder) {
                ForEach(SortOrder.allCases, id: \.rawValue) { order in
                    Text(order.rawValue).tag(order.rawValue)
                }
            } label: {
                Label("Default Sort", systemImage: "arrow.up.arrow.down")
            }
        } header: {
            Text("Preferences")
        } footer: {
            Text("Clipboard detection shows a prompt when you copy a YouTube URL.")
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            NavigationLink {
                StorageDetailView()
            } label: {
                Label("Storage & Cache", systemImage: "internaldrive")
            }

            Button(role: .destructive) {
                Task {
                    await SpotlightService.shared.removeAllItems()
                }
            } label: {
                Label("Clear Spotlight Index", systemImage: "trash")
            }
        } header: {
            Text("Storage")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://ytmate.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://ytmate.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://ytmate.app/support")!) {
                Label("Support", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Account Actions Section

    private var accountActionsSection: some View {
        Section {
            Button {
                showingSignOutAlert = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                showingDeleteAccountAlert = true
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                try await AuthService.shared.deleteAccount()
                isDeleting = false
                dismiss()
            } catch {
                isDeleting = false
                // Show error
            }
        }
    }
}

// MARK: - Storage Detail View
struct StorageDetailView: View {
    @State private var localStorageSize: String = "Calculating..."
    @State private var cacheSize: String = "Calculating..."

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Local Summaries")
                    Spacer()
                    Text(localStorageSize)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Image Cache")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    clearImageCache()
                } label: {
                    Text("Clear Image Cache")
                }
            }
        }
        .navigationTitle("Storage")
        .task {
            calculateStorageSizes()
        }
    }

    private func calculateStorageSizes() {
        // Calculate SwiftData storage
        localStorageSize = "~2 MB" // Placeholder

        // Calculate image cache
        cacheSize = "~15 MB" // Placeholder
    }

    private func clearImageCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheSize = "0 MB"
    }
}

#Preview {
    SettingsView()
}
