//
//  ProfileManager.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//

import Foundation
import FamilyControls
import ManagedSettings

class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var currentProfileId: UUID?
    
    init() {
        loadProfiles()
        ensureDefaultProfile()
    }
    
    var currentProfile: Profile {
        (profiles.first(where: { $0.id == currentProfileId }) ?? profiles.first(where: { $0.name == "Default" }))!
    }
    
    func loadProfiles() {
        if let savedProfiles = UserDefaults.standard.data(forKey: "savedProfiles"),
           let decodedProfiles = try? JSONDecoder().decode([Profile].self, from: savedProfiles) {
            profiles = decodedProfiles
        } else {
            // Create a default profile if no profiles are saved
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash")
            profiles = [defaultProfile]
            currentProfileId = defaultProfile.id
        }
        
        if let savedProfileId = UserDefaults.standard.string(forKey: "currentProfileId"),
           let uuid = UUID(uuidString: savedProfileId) {
            currentProfileId = uuid
            NSLog("Found currentProfile: \(uuid)")
        } else {
            currentProfileId = profiles.first?.id
            NSLog("No stored ID, using \(currentProfileId?.uuidString ?? "NONE")")
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "savedProfiles")
        }
        UserDefaults.standard.set(currentProfileId?.uuidString, forKey: "currentProfileId")
    }
    
    func addProfile(name: String, icon: String = "bell.slash") {
        let newProfile = Profile(name: name, appTokens: [], categoryTokens: [], icon: icon)
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    func addProfile(newProfile: Profile) {
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    func updateCurrentProfile(appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].appTokens = appTokens
            profiles[index].categoryTokens = categoryTokens
            saveProfiles()
        }
    }
    
    func setCurrentProfile(id: UUID) {
        if profiles.contains(where: { $0.id == id }) {
            currentProfileId = id
            NSLog("New Current Profile: \(id)")
            saveProfiles()
        }
    }
    
    func deleteProfile(withId id: UUID) {
//        guard !profiles.first(where: { $0.id == id })?.isDefault ?? false else {
//            // Don't delete the default profile
//            return
//        }
        
        profiles.removeAll { $0.id == id }
        
        if currentProfileId == id {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }

    func deleteAllNonDefaultProfiles() {
        profiles.removeAll { !$0.isDefault }
        
        if !profiles.contains(where: { $0.id == currentProfileId }) {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }
    
    func updateCurrentProfile(name: String, iconName: String) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].name = name
            profiles[index].icon = iconName
            saveProfiles()
        }
    }

    func deleteCurrentProfile() {
        profiles.removeAll { $0.id == currentProfileId }
        if let firstProfile = profiles.first {
            currentProfileId = firstProfile.id
        }
        saveProfiles()
    }
    
    func updateProfile(
        id: UUID,
        name: String? = nil,
        appTokens: Set<ApplicationToken>? = nil,
        categoryTokens: Set<ActivityCategoryToken>? = nil,
        icon: String? = nil,
        dailyLimitMinutes: Int?? = nil
    ) {
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            if let name = name {
                profiles[index].name = name
            }
            if let appTokens = appTokens {
                profiles[index].appTokens = appTokens
            }
            if let categoryTokens = categoryTokens {
                profiles[index].categoryTokens = categoryTokens
            }
            if let icon = icon {
                profiles[index].icon = icon
            }
            // Double optional: nil means "don't change", .some(nil) means "set to nil", .some(value) means "set to value"
            if let limitUpdate = dailyLimitMinutes {
                profiles[index].dailyLimitMinutes = limitUpdate
            }
            
            if currentProfileId == id {
                currentProfileId = profiles[index].id
            }
            
            saveProfiles()
        }
    }
    
    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash")
            profiles.append(defaultProfile)
            currentProfileId = defaultProfile.id
            saveProfiles()
        } else if currentProfileId == nil {
            if let defaultProfile = profiles.first(where: { $0.name == "Default" }) {
                currentProfileId = defaultProfile.id
            } else {
                currentProfileId = profiles.first?.id
            }
            saveProfiles()
        }
    }
    
    // Check if it's a new day and reset usage if needed
    func checkAndResetDailyUsage(for profileId: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        if let lastReset = profiles[index].lastResetDate {
            // Check if it's a new day
            if !calendar.isDate(lastReset, inSameDayAs: now) {
                profiles[index].usageMinutes = 0
                profiles[index].lastResetDate = now
                saveProfiles()
                NSLog("Daily usage reset for profile: \(profiles[index].name)")
            }
        } else {
            // First time tracking, set the reset date
            profiles[index].lastResetDate = now
            saveProfiles()
        }
    }
    
    // Add usage time (in minutes) to current profile
    func addUsageTime(minutes: Int, for profileId: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        
        // Check for daily reset first
        checkAndResetDailyUsage(for: profileId)
        
        profiles[index].usageMinutes += minutes
        saveProfiles()
        NSLog("Added \(minutes) minutes to profile \(profiles[index].name). Total: \(profiles[index].usageMinutes)")
    }
    
    // Unlock quota for the next day only (doesn't reset current day usage)
    func unlockForNextDay(profileId: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        
        // Set usage to 0 and last reset date to start of tomorrow
        // This way, tomorrow the quota will be available
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let startOfTomorrow = calendar.startOfDay(for: tomorrow) {
            profiles[index].usageMinutes = 0
            profiles[index].lastResetDate = startOfTomorrow
            saveProfiles()
            NSLog("Unlocked quota for next day for profile: \(profiles[index].name)")
        }
    }
    
    // Check if current profile has reached its daily limit
    func hasCurrentProfileReachedLimit() -> Bool {
        checkAndResetDailyUsage(for: currentProfile.id)
        return currentProfile.isLimitReached
    }
}

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var appTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var icon: String // New property for icon
    var dailyLimitMinutes: Int? // Daily usage limit in minutes (nil = no limit)
    var usageMinutes: Int // Current day usage in minutes
    var lastResetDate: Date? // Last date when usage was reset

    var isDefault: Bool {
        name == "Default"
    }
    
    var isLimitReached: Bool {
        guard let limit = dailyLimitMinutes else { return false }
        return usageMinutes >= limit
    }

    // New initializer to support default icon
    init(name: String, appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>, icon: String = "bell.slash", dailyLimitMinutes: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.appTokens = appTokens
        self.categoryTokens = categoryTokens
        self.icon = icon
        self.dailyLimitMinutes = dailyLimitMinutes
        self.usageMinutes = 0
        self.lastResetDate = nil
    }
}
