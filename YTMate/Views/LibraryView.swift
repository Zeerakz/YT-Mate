import SwiftUI
import SwiftData

/// Main library view showing all saved video summaries
/// Features search, filtering by category, and sorting
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var clipboardService = ClipboardService.shared

    @State private var selectedSummary: VideoSummary?
    @State private var showingSettings = false
    @State private var showingURLInput = false
    @State private var manualURL = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.summaries.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    summaryListView
                }

                // Clipboard toast
                if clipboardService.showToast, let url = clipboardService.detectedURL {
                    ClipboardToastView(
                        url: url,
                        onSummarize: {
                            Task {
                                await viewModel.processURL(url, userId: authService.userId ?? "", context: modelContext)
                            }
                            clipboardService.clearDetectedURL()
                        },
                        onDismiss: {
                            clipboardService.dismissToast()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("YT Mate")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    sortMenu
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingURLInput = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search summaries...")
            .refreshable {
                if let userId = authService.userId {
                    await viewModel.syncWithFirestore(userId: userId, context: modelContext)
                }
            }
            .onAppear {
                viewModel.loadSummaries(from: modelContext)
                clipboardService.checkClipboard()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingURLInput) {
                urlInputSheet
            }
            .sheet(isPresented: $viewModel.showingSummarySheet) {
                if let url = viewModel.processingURL {
                    SummarySheetView(
                        url: url,
                        userId: authService.userId ?? "",
                        onSave: { summary in
                            viewModel.summaries.insert(summary, at: 0)
                            viewModel.clearProcessing()
                        },
                        onDismiss: {
                            viewModel.clearProcessing()
                        }
                    )
                }
            }
            .navigationDestination(item: $selectedSummary) { summary in
                SummaryDetailView(summary: summary)
            }
        }
    }

    // MARK: - Subviews

    private var summaryListView: some View {
        VStack(spacing: 0) {
            // Category filter chips
            if !viewModel.availableCategories.isEmpty {
                categoryChips
            }

            // Summary list
            List {
                ForEach(viewModel.filteredSummaries, id: \.id) { summary in
                    SummaryCardView(summary: summary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSummary = summary
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteSummary(summary, context: modelContext)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        count: viewModel.categoryCounts[category] ?? 0,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation {
                            viewModel.toggleCategory(category)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                } label: {
                    HStack {
                        Text(order.rawValue)
                        if viewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Summaries Yet", systemImage: "brain.head.profile")
        } description: {
            Text("Share a YouTube video to get started, or paste a URL below.")
        } actions: {
            Button {
                showingURLInput = true
            } label: {
                Text("Add YouTube URL")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var urlInputSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter YouTube URL")
                    .font(.headline)

                TextField("https://youtube.com/watch?v=...", text: $manualURL)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                if !manualURL.isEmpty {
                    let validation = YouTubeURLParser.validate(manualURL)
                    if validation.isValid {
                        Label("Valid YouTube URL", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(validation.errorMessage ?? "Invalid URL", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manualURL = ""
                        showingURLInput = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Summarize") {
                        Task {
                            await viewModel.processURL(manualURL, userId: authService.userId ?? "", context: modelContext)
                        }
                        manualURL = ""
                        showingURLInput = false
                    }
                    .disabled(!YouTubeURLParser.isValidYouTubeURL(manualURL))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: VibeCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption.weight(.medium))
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : Color(.systemGray5))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: VideoSummary.self, inMemory: true)
}
