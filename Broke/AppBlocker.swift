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
    
    init() {
        loadBlockingState()
        Task {
            await requestAuthorization()
        }
    }
    
    // Call this from BrokerView's onAppear to restore usage tracking if blocking
    func restoreUsageTrackingIfNeeded(for profile: Profile, profileManager: ProfileManager) {
        if isBlocking {
            startUsageTracking(for: profile.id, profileManager: profileManager)
            NSLog("Restored usage tracking for profile: \(profile.name)")
        }
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
    
    func toggleBlocking(for profile: Profile, profileManager: ProfileManager, isUnlockingForNextDay: Bool = false) {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }
        
        // Check if trying to unblock but limit is reached
        if isBlocking && profile.isLimitReached && !isUnlockingForNextDay {
            NSLog("Cannot unlock - daily limit reached. Use unlock for next day instead.")
            return
        }
        
        isBlocking.toggle()
        saveBlockingState()
        
        if isBlocking {
            startUsageTracking(for: profile.id, profileManager: profileManager)
        } else {
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
    
    private func startUsageTracking(for profileId: UUID, profileManager: ProfileManager) {
        stopUsageTracking() // Stop any existing timer
        
        currentProfileId = profileId
        
        // Track usage every minute
        usageTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self, weak profileManager] _ in
            guard let self = self, let profileManager = profileManager else { return }
            
            if self.isBlocking, let currentId = self.currentProfileId {
                profileManager.addUsageTime(minutes: 1, for: currentId)
                
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
    
    deinit {
        stopUsageTracking()
    }
}