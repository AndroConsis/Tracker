import Foundation
import Supabase

@MainActor
class CigaretteDataStore: ObservableObject {
    static let shared = CigaretteDataStore()
    
    @Published var allEntries: [CigaretteEntry] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreData = true
    @Published var totalCount: Int = 0
    
    private var currentPage = 0
    private let pageSize = 20
    
    private init() {}
    
    // MARK: - Load Entries (Initial Load)
    func loadEntries() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        
        do {
            guard let userId = AuthManager.shared.getCurrentUser()?.id else {
                throw DataStoreError.userNotFound
            }
            
            let response: [CigaretteEntry] = try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("smoked_at", ascending: false)
                .range(from: 0, to: pageSize - 1)
                .execute()
                .value
            
            self.allEntries = response
            self.hasMoreData = response.count >= pageSize
            
        } catch let error as PostgrestError {
            self.errorMessage = "Failed to load entries: \(error.message)"
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                self.errorMessage = "Request timed out. Please try again."
            case .notConnectedToInternet:
                self.errorMessage = "No internet connection. Please check your network."
            default:
                self.errorMessage = "Network error. Please try again."
            }
        } catch DataStoreError.userNotFound {
            self.errorMessage = "Please log in to view your entries."
        } catch {
            self.errorMessage = "An unexpected error occurred. Please try again."
        }
        isLoading = false
    }

    // MARK: - Load All-time Count
    func loadTotalCount() async {
        do {
            guard let userId = AuthManager.shared.getCurrentUser()?.id else {
                throw DataStoreError.userNotFound
            }
            let response = try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .execute()
            self.totalCount = response.count ?? 0
        } catch let error as PostgrestError {
            self.errorMessage = "Failed to load total count: \(error.message)"
            self.totalCount = 0
        } catch DataStoreError.userNotFound {
            self.errorMessage = "Please log in to view your total count."
            self.totalCount = 0
        } catch {
            self.errorMessage = "An unexpected error occurred while loading total count."
            self.totalCount = 0
        }
    }
    
    // MARK: - Load More Entries (Pagination)
    func loadMoreEntries() async {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        errorMessage = nil
        
        do {
            guard let userId = AuthManager.shared.getCurrentUser()?.id else {
                throw DataStoreError.userNotFound
            }
            
            let from = (currentPage + 1) * pageSize
            let to = from + pageSize - 1
            
            let response: [CigaretteEntry] = try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("smoked_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            
            self.allEntries.append(contentsOf: response)
            self.currentPage += 1
            self.hasMoreData = response.count >= pageSize
            
        } catch let error as PostgrestError {
            self.errorMessage = "Failed to load more entries: \(error.message)"
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                self.errorMessage = "Request timed out. Please try again."
            case .notConnectedToInternet:
                self.errorMessage = "No internet connection. Please check your network."
            default:
                self.errorMessage = "Network error. Please try again."
            }
        } catch DataStoreError.userNotFound {
            self.errorMessage = "Please log in to view your entries."
        } catch {
            self.errorMessage = "An unexpected error occurred. Please try again."
        }
        isLoadingMore = false
    }
    
    // MARK: - Add Entry
    func addEntry(reason: String? = nil) async {
        errorMessage = nil
        do {
            guard let userId = AuthManager.shared.getCurrentUser()?.id else {
                throw DataStoreError.userNotFound
            }
            let newEntry = CigaretteEntry(
                id: UUID(),
                userId: userId,
                timestamp: Date(),
                reason: reason
            )
            let response: [CigaretteEntry] = try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .insert(newEntry)
                .select()
                .execute()
                .value
            if let insertedEntry = response.first {
                self.allEntries.insert(insertedEntry, at: 0)
                self.totalCount += 1  // Increment total count for real-time updates
            }
        } catch let error as PostgrestError {
            self.errorMessage = "Failed to add entry: \(error.message)"
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                self.errorMessage = "Request timed out. Please try again."
            case .notConnectedToInternet:
                self.errorMessage = "No internet connection. Please check your network."
            default:
                self.errorMessage = "Network error. Please try again."
            }
        } catch DataStoreError.userNotFound {
            self.errorMessage = "Please log in to add entries."
        } catch {
            self.errorMessage = "Failed to add entry. Please try again."
        }
    }
    
    // MARK: - Delete Entry
    func deleteEntry(_ entry: CigaretteEntry) async {
        errorMessage = nil
        do {
            try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .delete()
                .eq("id", value: entry.id.uuidString)
                .execute()
            self.allEntries.removeAll { $0.id == entry.id }
            self.totalCount = max(0, self.totalCount - 1)  // Decrement total count, but don't go below 0
        } catch let error as PostgrestError {
            self.errorMessage = "Failed to delete entry: \(error.message)"
        } catch {
            self.errorMessage = "Failed to delete entry. Please try again."
        }
    }
    
    // MARK: - Refresh
    func refresh() async {
        await loadEntries()
    }
    
    enum DataStoreError: Error, LocalizedError {
        case userNotFound
        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "User not authenticated"
            }
        }
    }
} 
