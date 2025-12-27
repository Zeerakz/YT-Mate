import Foundation
import FirebaseFirestore
import SwiftData

/// Service for syncing VideoSummary data with Cloud Firestore
/// Provides real-time sync and offline persistence support
@MainActor
final class FirestoreService: ObservableObject {
    /// Shared singleton instance
    static let shared = FirestoreService()

    /// Firestore database instance
    private let db = Firestore.firestore()

    /// Collection name for summaries
    private let summariesCollection = "summaries"

    /// Active listeners
    private var listeners: [ListenerRegistration] = []

    /// Sync state
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?

    private init() {
        configureFirestore()
    }

    /// Configure Firestore settings
    private func configureFirestore() {
        let settings = FirestoreSettings()
        // Enable offline persistence
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }

    // MARK: - CRUD Operations

    /// Save a summary to Firestore
    /// - Parameter summary: The VideoSummary to save
    /// - Returns: The Firestore document ID
    @discardableResult
    func saveSummary(_ summary: VideoSummary) async throws -> String {
        isSyncing = true
        lastSyncError = nil

        defer { isSyncing = false }

        do {
            let data = summary.toFirestoreData()
            let docRef: DocumentReference

            if let existingId = summary.firestoreId {
                // Update existing document
                docRef = db.collection(summariesCollection).document(existingId)
                try await docRef.setData(data, merge: true)
            } else {
                // Create new document
                docRef = try await db.collection(summariesCollection).addDocument(data: data)
            }

            return docRef.documentID
        } catch {
            lastSyncError = error.localizedDescription
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }

    /// Fetch all summaries for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of VideoSummary objects
    func fetchSummaries(for userId: String) async throws -> [VideoSummary] {
        isSyncing = true
        lastSyncError = nil

        defer { isSyncing = false }

        do {
            let snapshot = try await db.collection(summariesCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
                VideoSummary.fromFirestoreData(doc.data(), documentId: doc.documentID)
            }
        } catch {
            lastSyncError = error.localizedDescription
            throw FirestoreError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch a single summary by ID
    /// - Parameters:
    ///   - id: The local summary ID
    ///   - userId: The user's ID
    /// - Returns: VideoSummary if found
    func fetchSummary(id: String, userId: String) async throws -> VideoSummary? {
        do {
            let snapshot = try await db.collection(summariesCollection)
                .whereField("id", isEqualTo: id)
                .whereField("userId", isEqualTo: userId)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else {
                return nil
            }

            return VideoSummary.fromFirestoreData(doc.data(), documentId: doc.documentID)
        } catch {
            throw FirestoreError.fetchFailed(error.localizedDescription)
        }
    }

    /// Delete a summary from Firestore
    /// - Parameter summary: The VideoSummary to delete
    func deleteSummary(_ summary: VideoSummary) async throws {
        guard let firestoreId = summary.firestoreId else {
            return // Not synced to Firestore yet
        }

        do {
            try await db.collection(summariesCollection).document(firestoreId).delete()
        } catch {
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }

    /// Delete multiple summaries
    /// - Parameter summaries: Array of summaries to delete
    func deleteSummaries(_ summaries: [VideoSummary]) async throws {
        let batch = db.batch()

        for summary in summaries {
            if let firestoreId = summary.firestoreId {
                let docRef = db.collection(summariesCollection).document(firestoreId)
                batch.deleteDocument(docRef)
            }
        }

        try await batch.commit()
    }

    // MARK: - Real-time Sync

    /// Start listening for real-time updates
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - onChange: Callback when data changes
    func startListening(for userId: String, onChange: @escaping ([VideoSummary]) -> Void) {
        let listener = db.collection(summariesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Firestore listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let summaries = documents.compactMap { doc in
                    VideoSummary.fromFirestoreData(doc.data(), documentId: doc.documentID)
                }

                onChange(summaries)
            }

        listeners.append(listener)
    }

    /// Stop all active listeners
    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Batch Sync

    /// Sync local SwiftData summaries to Firestore
    /// - Parameters:
    ///   - summaries: Local summaries that need syncing
    ///   - modelContext: SwiftData model context
    func syncLocalSummaries(_ summaries: [VideoSummary], modelContext: ModelContext) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let unsyncedSummaries = summaries.filter { !$0.isSynced }

        for summary in unsyncedSummaries {
            do {
                let firestoreId = try await saveSummary(summary)
                summary.firestoreId = firestoreId
                summary.isSynced = true
            } catch {
                print("Failed to sync summary \(summary.id): \(error.localizedDescription)")
            }
        }

        try modelContext.save()
    }

    /// Import summaries from Firestore to local SwiftData
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - modelContext: SwiftData model context
    func importFromFirestore(userId: String, modelContext: ModelContext) async throws {
        let remoteSummaries = try await fetchSummaries(for: userId)

        for remoteSummary in remoteSummaries {
            // Check if already exists locally
            let descriptor = FetchDescriptor<VideoSummary>(
                predicate: #Predicate { $0.id == remoteSummary.id }
            )

            let existing = try modelContext.fetch(descriptor)

            if existing.isEmpty {
                // Insert new summary
                modelContext.insert(remoteSummary)
            } else if let local = existing.first {
                // Update if remote is newer
                if remoteSummary.updatedAt > local.updatedAt {
                    local.tldr = remoteSummary.tldr
                    local.vibeCategory = remoteSummary.vibeCategory
                    local.difficultyLevel = remoteSummary.difficultyLevel
                    local.userNotes = remoteSummary.userNotes
                    local.updatedAt = remoteSummary.updatedAt
                }
            }
        }

        try modelContext.save()
    }
}

// MARK: - Error Types
enum FirestoreError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
