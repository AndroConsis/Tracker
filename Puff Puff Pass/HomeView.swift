import SwiftUI

struct CigaretteEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let timestamp: Date
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case timestamp = "smoked_at"
        case reason
    }
}

struct HomeView: View {
    @AppStorage("lastSmokedTime") private var lastSmokedTime: Double = Date().timeIntervalSince1970
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasShownWelcomeBox") private var hasShownWelcomeBox = false
    
    @State private var showProfile = false
    @State private var todayCount = 0
    @State private var allEntries: [CigaretteEntry] = []
    @State private var animatedCount: Int = 0
    @State private var isAddingEntry = false
    @State private var showWelcomeBox = false
    @State private var showReasonSelection = false
    @State private var lastLoggedReason: SmokingReason?
    @State private var isDataLoaded = false
    
    @StateObject private var dataStore = CigaretteDataStore.shared
    @StateObject private var userManager = UserManager.shared

    private var todayEntries: [CigaretteEntry] {
        let calendar = Calendar.current
        return dataStore.allEntries.filter {
            calendar.isDateInToday($0.timestamp)
        }.sorted { $0.timestamp > $1.timestamp } // Most recent first
    }

    private var totalCigarettes: Int {
        // Use backend all-time count when available; otherwise fall back to local list count
        return dataStore.totalCount > 0 ? dataStore.totalCount : dataStore.allEntries.count
    }

    private var totalPacks: Int {
        guard totalCigarettes > 0 else { return 0 }
        return totalCigarettes / 20
    }

    private var totalSpent: Double {
        guard totalCigarettes > 0 else { return 0.0 }
        // Prefer the user's current/effective price if set; fall back to profile value
        let effectivePricePerCig = userManager.userCigarettePrice > 0
            ? userManager.userCigarettePrice
            : (userManager.userProfile?.price_per_cigarette ?? 0)
        guard effectivePricePerCig > 0 else { return 0.0 }
        return Double(totalCigarettes) * effectivePricePerCig
    }
    
    // Get the most recent cigarette entry (not just today's)
    private var mostRecentEntry: CigaretteEntry? {
        dataStore.allEntries.sorted { $0.timestamp > $1.timestamp }.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Cigr")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Circle Counter
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: 200, height: 200)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .shadow(color: Color.white.opacity(0.2), radius: 1, x: 0, y: -1)

                    VStack {
                        Text("\(animatedCount)")
                            .font(.system(size: 48, weight: .bold))
                        Text("Today's Count")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                // Time since last cigarette - FIXED
                Group {
                    if let mostRecent = mostRecentEntry {
                        let timeAgo = timeSince(mostRecent.timestamp)
                        Text("⏱️ Last smoked: \(timeAgo) ago")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else if dataStore.isLoading {
                        Text("⏳ Loading...")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else {
                        Text("🚭 No smoking history yet!")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }

                // Welcome Box - Show for first-time users or users with no cigarette history
                if showWelcomeBox {
                    WelcomeBoxView(
                        hasCigaretteHistory: !dataStore.allEntries.isEmpty
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Add Cigarette Button - FIXED
                Button(action: {
                    guard !isAddingEntry else { return } // Prevent double-tap
                    
                    isAddingEntry = true
                    Task {
                        await dataStore.addEntry()
                        
                        await MainActor.run {
                            // Update last smoked time only on success
                            if dataStore.errorMessage == nil {
                                lastSmokedTime = Date().timeIntervalSince1970
                                animateCount(to: todayEntries.count)
                                
                                // Hide welcome box after first cigarette is logged
                                if showWelcomeBox {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showWelcomeBox = false
                                        hasShownWelcomeBox = true
                                    }
                                }
                                
                                // Show reason selection after cigarette is logged
                                print("🎯 [HOME VIEW] Showing reason selection")
                                // showReasonSelection = true  // DISABLED: Hide reason selection to prevent blocking count display
                            }
                            isAddingEntry = false
                        }
                    }
                }) {
                    HStack {
                        if isAddingEntry {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isAddingEntry ? "Adding..." : "Add Cigarette")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isAddingEntry ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .disabled(isAddingEntry)

                // Error Message Display - NEW
                if let errorMessage = dataStore.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                // Stats Tabs - FIXED
                HStack(spacing: 20) {
                    CubeView(title: "Total", dataStore: dataStore, userManager: userManager)
                    PacksCubeView(title: "Packs", dataStore: dataStore, userManager: userManager)
                    SpentCubeView(title: "Spent", dataStore: dataStore, userManager: userManager)
                }
                .padding(.horizontal)

                NavigationLink(destination: StatisticsView()) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Statistics")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                NavigationLink(destination: CigaretteLogView()) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("View Log")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheet(onLogout: {
                    Task {
                        // Clear UserManager cache first
                        UserManager.shared.clearUserData()
                        
                        // Sign out from Supabase
                        try? await AuthManager.shared.signOut()
                        
                        // Clear all user-related AppStorage
                        isLoggedIn = false
                        UserDefaults.standard.removeObject(forKey: "appleUserId")
                        UserDefaults.standard.removeObject(forKey: "appleEmail")
                        UserDefaults.standard.removeObject(forKey: "appleFullName")
                        UserDefaults.standard.removeObject(forKey: "pricePerCig")
                        // Optionally: clear any other sensitive data
                    }
                })
            }
            .overlay(
                // Reason Selection Modal
                Group {
                    if showReasonSelection {
                        ReasonSelectionView { reason in
                            lastLoggedReason = reason
                            showReasonSelection = false
                            
                            // Update the most recent cigarette entry with the selected reason
                            if let reason = reason {
                                print("Selected reason: \(reason.title)")
                                Task {
                                    await updateLastEntryWithReason(reason.title)
                                }
                            } else {
                                print("No reason selected (skipped)")
                            }
                        }
                    }
                }
            )

            .onAppear {
                Task {
                    // Load user profile first
                    await userManager.loadUserProfile()
                    
                    // Then load cigarette entries
                    await dataStore.loadEntries()
                    await dataStore.loadTotalCount()
                    
                    // Mark data as loaded and animate count after entries are loaded
                    await MainActor.run {
                        isDataLoaded = true
                        // Only animate if loading was successful
                        if dataStore.errorMessage == nil {
                            animateCount(to: todayEntries.count)
                        }
                        
                        // Show welcome box for users with no cigarette history
                        if dataStore.allEntries.isEmpty {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showWelcomeBox = true
                            }
                        }
                    }
                }
            }
            .refreshable {
                // Disable refresh when reason selection is active
                guard !showReasonSelection else { return }
                
                await userManager.refreshUserProfile()
                await dataStore.refresh()
                await dataStore.loadTotalCount()
                await MainActor.run {
                    isDataLoaded = true
                    if dataStore.errorMessage == nil {
                        animateCount(to: todayEntries.count)
                    }
                }
            }
        }
    }

    // FIXED: Better currency formatting with currency detection
    func formattedSpent() -> String {
        guard totalSpent > 0 else { 
            return userManager.currentCurrencyInfo?.symbol ?? "$" + "0"
        }
        
        // Check if the decimal part is zero
        let isWholeNumber = totalSpent.truncatingRemainder(dividingBy: 1) == 0
        
        if isWholeNumber {
            // For whole numbers, show without decimal places
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = userManager.currentCurrencyInfo?.code ?? "USD"
            formatter.currencySymbol = userManager.currentCurrencyInfo?.symbol ?? "$"
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            
            return formatter.string(from: NSNumber(value: totalSpent)) ?? "\(userManager.currentCurrencyInfo?.symbol ?? "$")\(Int(totalSpent))"
        } else {
            // For decimal numbers, show with 2 decimal places
            return CurrencyManager.shared.formatPrice(totalSpent)
        }
    }

    func animateCount(to newCount: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            animatedCount = newCount
        }
    }

    // FIXED: Better time formatting with more precise handling
    func timeSince(_ date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        
        // Handle edge cases
        guard interval >= 0 else { return "just now" }
        
        let days = interval / 86400
        let hours = (interval % 86400) / 3600
        let minutes = (interval % 3600) / 60
        
        if days > 0 {
            if days == 1 {
                return "1 day"
            } else {
                return "\(days) days"
            }
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if interval > 30 {
            return "\(interval)s"
        } else {
            return "just now"
        }
    }

    // MARK: - REMOVED DUPLICATE METHODS
    // Removed saveEntries() and loadEntries() as they duplicate viewModel functionality
    
    // Update the most recent cigarette entry with the selected reason
    func updateLastEntryWithReason(_ reason: String) async {
        guard let mostRecentEntry = mostRecentEntry else {
            print("❌ [HOME VIEW] No recent entry found to update")
            return
        }
        
        do {
            print("🔄 [HOME VIEW] Updating entry \(mostRecentEntry.id) with reason: \(reason)")
            
            // Update the entry in the database
            try await SupabaseManager.shared.client
                .from("cigarette_entries")
                .update(["reason": reason])
                .eq("id", value: mostRecentEntry.id.uuidString)
                .execute()
            
            // Update the local entry
            if let index = dataStore.allEntries.firstIndex(where: { $0.id == mostRecentEntry.id }) {
                dataStore.allEntries[index] = CigaretteEntry(
                    id: mostRecentEntry.id,
                    userId: mostRecentEntry.userId,
                    timestamp: mostRecentEntry.timestamp,
                    reason: reason
                )
            }
            
            print("✅ [HOME VIEW] Successfully updated entry with reason")
            
        } catch {
            print("❌ [HOME VIEW] Failed to update entry with reason: \(error.localizedDescription)")
        }
    }
}

// MARK: - StatCard View - FIXED
struct StatCard: View {
    var title: String
    var value: String
    var systemIcon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemIcon)
                .font(.title2) // Slightly smaller for better proportions
                .foregroundColor(.blue)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.5) // Allow more scaling if needed
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 80) // Consistent height
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct Previews_HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
