//
//  AppBlocker.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import ManagedSettings
import FamilyControls
import Combine

class AppBlocker: ObservableObject {
    let store = ManagedSettingsStore()
    @Published var isBlocking = false
    @Published var isAuthorized = false
    
    private var usageTimer: Timer?
    private var activeProfileIds: Set<UUID> = [] // Track all active profiles
    private var blockingStartTime: Date?
    private var lastNotificationCheck: [UUID: Date] = [:] // Track last notification time per profile
    
    private let usageTrackingInterval: TimeInterval = 60 // Track usage every 60 seconds
    private let notificationManager = UsageNotificationManager.shared
    
    init() {
        loadBlockingState()
        loadBlockingStartTime()
        notificationManager.requestAuthorization()
        Task {
            await requestAuthorization()
        }
    }
    
    // Call this from BrokerView's onAppear to restore usage tracking if blocking
    func restoreUsageTrackingIfNeeded(allProfiles: [Profile], profileManager: ProfileManager) {
        // Only restore if blocking and timer is not already running
        guard isBlocking, usageTimer == nil else { return }
        
        // Add any elapsed time since last app open for all active profiles
        for profile in allProfiles {
            addElapsedUsageTime(for: profile.id, profileManager: profileManager)
        }
        startUsageTracking(allProfiles: allProfiles, profileManager: profileManager)
        NSLog("Restored usage tracking for all profiles")
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        } catch {
            print("Failed to request authorization: \(error)")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    // Toggle blocking for ALL profiles at once
    func toggleBlockingAllProfiles(allProfiles: [Profile], profileManager: ProfileManager) {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }
        
        isBlocking.toggle()
        saveBlockingState()
        
        if isBlocking {
            blockingStartTime = Date()
            saveBlockingStartTime()
            startUsageTracking(allProfiles: allProfiles, profileManager: profileManager)
        } else {
            // Add final elapsed time before stopping for all profiles
            for profile in allProfiles {
                addElapsedUsageTime(for: profile.id, profileManager: profileManager)
            }
            blockingStartTime = nil
            clearBlockingStartTime()
            stopUsageTracking()
        }
        
        applyBlockingSettingsForAllProfiles(allProfiles: allProfiles)
    }
    
    func applyBlockingSettingsForAllProfiles(allProfiles: [Profile]) {
        if isBlocking {
            // Combine all apps and categories from all profiles
            var allApps: Set<ApplicationToken> = []
            var allCategories: Set<ActivityCategoryToken> = []
            
            for profile in allProfiles {
                allApps.formUnion(profile.appTokens)
                allCategories.formUnion(profile.categoryTokens)
            }
            
            NSLog("Blocking \(allApps.count) apps and \(allCategories.count) categories from all profiles")
            store.shield.applications = allApps.isEmpty ? nil : allApps
            store.shield.applicationCategories = allCategories.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(allCategories)
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        }
    }
    
    private func addElapsedUsageTime(for profileId: UUID, profileManager: ProfileManager) {
        guard let startTime = blockingStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let elapsedMinutes = Int(elapsed / 60)
        
        if elapsedMinutes > 0 {
            profileManager.addUsageTime(minutes: elapsedMinutes, for: profileId)
            // Reset start time to now
            blockingStartTime = Date()
            saveBlockingStartTime()
        }
    }
    
    private func startUsageTracking(allProfiles: [Profile], profileManager: ProfileManager) {
        stopUsageTracking() // Stop any existing timer
        
        activeProfileIds = Set(allProfiles.map { $0.id })
        
        // Track usage every minute for all profiles
        usageTimer = Timer.scheduledTimer(withTimeInterval: usageTrackingInterval, repeats: true) { [weak self, weak profileManager] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            guard let profileManager = profileManager else {
                self.stopUsageTracking()
                return
            }
            
            if self.isBlocking {
                // Update usage for all active profiles
                for profileId in self.activeProfileIds {
                    self.addElapsedUsageTime(for: profileId, profileManager: profileManager)
                    
                    // Check for notifications
                    if let profile = profileManager.profiles.first(where: { $0.id == profileId }) {
                        self.checkAndSendNotifications(for: profile)
                    }
                }
                
                // Check if any profile has reached limit
                for profile in profileManager.profiles where self.activeProfileIds.contains(profile.id) {
                    if profile.isLimitReached {
                        NSLog("Daily limit reached for profile: \(profile.name)")
                    }
                }
            }
        }
    }
    
    private func checkAndSendNotifications(for profile: Profile) {
        let percentage = profile.usagePercentage
        let now = Date()
        
        // Check if we should send a notification
        if profile.shouldNotifyUsageWarning {
            // Check if we haven't sent a notification in the last 5 minutes
            if let lastNotification = lastNotificationCheck[profile.id] {
                if now.timeIntervalSince(lastNotification) < 300 { // 5 minutes
                    return
                }
            }
            
            notificationManager.scheduleUsageWarning(for: profile, percentageUsed: percentage)
            lastNotificationCheck[profile.id] = now
        }
        
        // Send notification when limit is reached
        if profile.isLimitReached && !profile.isTomorrowQuotaExhausted {
            if lastNotificationCheck[profile.id] == nil {
                notificationManager.scheduleLimitReachedNotification(for: profile)
                lastNotificationCheck[profile.id] = now
            }
        }
        
        // Send notification when both quotas are exhausted
        if profile.isTomorrowQuotaExhausted {
            if lastNotificationCheck[profile.id] == nil {
                notificationManager.scheduleBothQuotasExhaustedNotification(for: profile)
                lastNotificationCheck[profile.id] = now
            }
        }
    }
    
    private func stopUsageTracking() {
        usageTimer?.invalidate()
        usageTimer = nil
        activeProfileIds.removeAll()
    }
    
    private func loadBlockingState() {
        isBlocking = UserDefaults.standard.bool(forKey: "isBlocking")
    }
    
    private func saveBlockingState() {
        UserDefaults.standard.set(isBlocking, forKey: "isBlocking")
    }
    
    private func loadBlockingStartTime() {
        if let timestamp = UserDefaults.standard.object(forKey: "blockingStartTime") as? Date {
            blockingStartTime = timestamp
        }
    }
    
    private func saveBlockingStartTime() {
        if let startTime = blockingStartTime {
            UserDefaults.standard.set(startTime, forKey: "blockingStartTime")
        }
    }
    
    private func clearBlockingStartTime() {
        UserDefaults.standard.removeObject(forKey: "blockingStartTime")
    }
    
    deinit {
        stopUsageTracking()
    }
}