import SwiftUI

struct PacksCubeView: View {
    let title: String
    @ObservedObject var dataStore: CigaretteDataStore
    @ObservedObject var userManager: UserManager
    
    @State private var rotationAngle: Double = 0
    @State private var isDragging = false
    
    // Cube faces: 0 = Total, 1 = Weekly, 2 = Monthly, 3 = Yearly
    @State private var currentFace: Int = 0
    
    private let cubeHeight: CGFloat = 80
    private let cubeWidth: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Cube container with 3D rotation
            VStack(spacing: 6) {
                // Icon
                Image(systemName: getIconForFace(currentFace))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                // Value
                Text(getValueForFace(currentFace))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.primary)
                
                // Title
                Text(getTitleForFace(currentFace))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(width: cubeWidth, height: cubeHeight)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.3
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        
                        // Calculate rotation based on vertical drag
                        let dragDistance = value.translation.height
                        let maxDragDistance: CGFloat = 100
                        let rotationMultiplier = 90.0 / Double(maxDragDistance)
                        
                        let newRotation = -Double(dragDistance) * rotationMultiplier
                        rotationAngle = newRotation
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        // Determine which face to snap to based on rotation
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let shouldSnapForward = abs(velocity) > 50 ? velocity > 0 : rotationAngle > 45
                        
                        let targetFace: Int
                        if shouldSnapForward {
                            targetFace = (currentFace + 1) % 4
                        } else {
                            targetFace = (currentFace - 1 + 4) % 4
                        }
                        
                        // Animate to target face
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentFace = targetFace
                            rotationAngle = 0
                        }
                    }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getIconForFace(_ face: Int) -> String {
        switch face {
        case 0: return "cube.box"           // Total
        case 1: return "calendar.badge.clock" // Weekly
        case 2: return "calendar"         // Monthly
        case 3: return "calendar.badge.plus" // Yearly
        default: return "cube.box"
        }
    }
    
    private func getTitleForFace(_ face: Int) -> String {
        switch face {
        case 0: return "Total"
        case 1: return "Weekly"
        case 2: return "Monthly"
        case 3: return "Yearly"
        default: return "Total"
        }
    }
    
    @MainActor
    private func getValueForFace(_ face: Int) -> String {
        // Show 0 if data hasn't been loaded yet (will update when data loads)
        switch face {
        case 0: return "\(getTotalPacks())"
        case 1: return "\(getWeeklyPacks())"
        case 2: return "\(getMonthlyPacks())"
        case 3: return "\(getYearlyPacks())"
        default: return "\(getTotalPacks())"
        }
    }
    
    @MainActor
    private func getTotalPacks() -> Int {
        return Int(ceil(Double(dataStore.totalCount) / 20.0))
    }
    
    @MainActor
    private func getWeeklyPacks() -> Int {
        let weeklyCount = getWeeklyCount()
        return Int(ceil(Double(weeklyCount) / 20.0))
    }
    
    @MainActor
    private func getMonthlyPacks() -> Int {
        let monthlyCount = getMonthlyCount()
        return Int(ceil(Double(monthlyCount) / 20.0))
    }
    
    @MainActor
    private func getYearlyPacks() -> Int {
        let yearlyCount = getYearlyCount()
        return Int(ceil(Double(yearlyCount) / 20.0))
    }
    
    @MainActor
    private func getWeeklyCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return dataStore.allEntries.filter { entry in
            entry.timestamp >= weekStart
        }.count
    }
    
    @MainActor
    private func getMonthlyCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return dataStore.allEntries.filter { entry in
            entry.timestamp >= monthStart
        }.count
    }
    
    @MainActor
    private func getYearlyCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
        
        return dataStore.allEntries.filter { entry in
            entry.timestamp >= yearStart
        }.count
    }
}

#Preview {
    PacksCubeView(
        title: "Packs",
        dataStore: CigaretteDataStore.shared,
        userManager: UserManager.shared
    )
}
