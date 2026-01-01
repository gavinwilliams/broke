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
    private var currentProfileId: UUID?
    private var blockingStartTime: Date?
    
    private let usageTrackingInterval: TimeInterval = 60 // Track usage every 60 seconds
    
    init() {
        loadBlockingState()
        loadBlockingStartTime()
        Task {
            await requestAuthorization()
        }
    }
    
    // Call this from BrokerView's onAppear to restore usage tracking if blocking
    func restoreUsageTrackingIfNeeded(for profile: Profile, profileManager: ProfileManager) {
        // Only restore if blocking and timer is not already running
        guard isBlocking, usageTimer == nil else { return }
        
        // Add any elapsed time since last app open
        addElapsedUsageTime(for: profile.id, profileManager: profileManager)
        startUsageTracking(for: profile.id, profileManager: profileManager)
        NSLog("Restored usage tracking for profile: \(profile.name)")
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
    
    func toggleBlocking(for profile: Profile, profileManager: ProfileManager) {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }
        
        isBlocking.toggle()
        saveBlockingState()
        
        if isBlocking {
            blockingStartTime = Date()
            saveBlockingStartTime()
            startUsageTracking(for: profile.id, profileManager: profileManager)
        } else {
            // Add final elapsed time before stopping
            addElapsedUsageTime(for: profile.id, profileManager: profileManager)
            blockingStartTime = nil
            clearBlockingStartTime()
            stopUsageTracking()
        }
        
        applyBlockingSettings(for: profile)
    }
    
    func applyBlockingSettings(for profile: Profile) {
        if isBlocking {
            NSLog("Blocking \(profile.appTokens.count) apps")
            store.shield.applications = profile.appTokens.isEmpty ? nil : profile.appTokens
            store.shield.applicationCategories = profile.categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(profile.categoryTokens)
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
    
    private func startUsageTracking(for profileId: UUID, profileManager: ProfileManager) {
        stopUsageTracking() // Stop any existing timer
        
        currentProfileId = profileId
        
        // Track usage every minute
        usageTimer = Timer.scheduledTimer(withTimeInterval: usageTrackingInterval, repeats: true) { [weak self, weak profileManager] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            guard let profileManager = profileManager else {
                self.stopUsageTracking()
                return
            }
            
            if self.isBlocking, let currentId = self.currentProfileId {
                self.addElapsedUsageTime(for: currentId, profileManager: profileManager)
                
                // Check if limit is reached
                if profileManager.hasCurrentProfileReachedLimit() {
                    NSLog("Daily limit reached! Auto-blocking...")
                    DispatchQueue.main.async {
                        // Keep blocking but notify that limit is reached
                        self.applyBlockingSettings(for: profileManager.currentProfile)
                    }
                }
            }
        }
    }
    
    private func stopUsageTracking() {
        usageTimer?.invalidate()
        usageTimer = nil
        currentProfileId = nil
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