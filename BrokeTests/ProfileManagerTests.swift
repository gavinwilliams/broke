//
//  ProfileManagerTests.swift
//  BrokeTests
//
//  Created by GitHub Copilot on 01/01/2026.
//

import XCTest
import FamilyControls
@testable import Broke

final class ProfileManagerTests: XCTestCase {
    
    var profileManager: ProfileManager!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "savedProfiles")
        UserDefaults.standard.removeObject(forKey: "currentProfileId")
        profileManager = ProfileManager()
    }
    
    override func tearDown() {
        profileManager = nil
        UserDefaults.standard.removeObject(forKey: "savedProfiles")
        UserDefaults.standard.removeObject(forKey: "currentProfileId")
        super.tearDown()
    }
    
    func testInitializationCreatesDefaultProfile() {
        XCTAssertEqual(profileManager.profiles.count, 1)
        XCTAssertEqual(profileManager.profiles.first?.name, "Default")
        XCTAssertNotNil(profileManager.currentProfileId)
    }
    
    func testAddProfile() {
        let initialCount = profileManager.profiles.count
        
        profileManager.addProfile(name: "Work", icon: "briefcase")
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 1)
        XCTAssertEqual(profileManager.profiles.last?.name, "Work")
        XCTAssertEqual(profileManager.profiles.last?.icon, "briefcase")
        XCTAssertEqual(profileManager.currentProfileId, profileManager.profiles.last?.id)
    }
    
    func testAddProfileWithObject() {
        let newProfile = Profile(name: "Gaming", appTokens: [], categoryTokens: [], icon: "gamecontroller")
        let initialCount = profileManager.profiles.count
        
        profileManager.addProfile(newProfile: newProfile)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount + 1)
        XCTAssertEqual(profileManager.profiles.last?.name, "Gaming")
        XCTAssertEqual(profileManager.currentProfileId, newProfile.id)
    }
    
    func testSetCurrentProfile() {
        profileManager.addProfile(name: "Profile1")
        let profile1Id = profileManager.currentProfileId!
        
        profileManager.addProfile(name: "Profile2")
        let profile2Id = profileManager.currentProfileId!
        
        XCTAssertNotEqual(profile1Id, profile2Id)
        
        profileManager.setCurrentProfile(id: profile1Id)
        XCTAssertEqual(profileManager.currentProfileId, profile1Id)
    }
    
    func testDeleteProfile() {
        profileManager.addProfile(name: "ToDelete")
        let toDeleteId = profileManager.currentProfileId!
        let initialCount = profileManager.profiles.count
        
        profileManager.deleteProfile(withId: toDeleteId)
        
        XCTAssertEqual(profileManager.profiles.count, initialCount - 1)
        XCTAssertNil(profileManager.profiles.first(where: { $0.id == toDeleteId }))
        XCTAssertNotEqual(profileManager.currentProfileId, toDeleteId)
    }
    
    func testDeleteCurrentProfile() {
        profileManager.addProfile(name: "ToDelete")
        let toDeleteId = profileManager.currentProfileId!
        let initialCount = profileManager.profiles.count
        
        profileManager.deleteCurrentProfile()
        
        XCTAssertEqual(profileManager.profiles.count, initialCount - 1)
        XCTAssertNil(profileManager.profiles.first(where: { $0.id == toDeleteId }))
        XCTAssertNotEqual(profileManager.currentProfileId, toDeleteId)
        XCTAssertNotNil(profileManager.currentProfileId)
    }
    
    func testUpdateProfile() {
        profileManager.addProfile(name: "Original")
        let profileId = profileManager.currentProfileId!
        
        profileManager.updateProfile(
            id: profileId,
            name: "Updated",
            icon: "star",
            dailyLimitMinutes: 90
        )
        
        let updatedProfile = profileManager.profiles.first(where: { $0.id == profileId })
        XCTAssertEqual(updatedProfile?.name, "Updated")
        XCTAssertEqual(updatedProfile?.icon, "star")
        XCTAssertEqual(updatedProfile?.dailyLimitMinutes, 90)
    }
    
    func testUpdateCurrentProfile() {
        profileManager.updateCurrentProfile(name: "Modified", iconName: "pencil")
        
        let currentProfile = profileManager.currentProfile
        XCTAssertEqual(currentProfile.name, "Modified")
        XCTAssertEqual(currentProfile.icon, "pencil")
    }
    
    func testSaveAndLoadProfiles() {
        profileManager.addProfile(name: "TestProfile", icon: "flame")
        let savedId = profileManager.currentProfileId
        let savedCount = profileManager.profiles.count
        
        // Create a new ProfileManager instance (simulates app restart)
        let newProfileManager = ProfileManager()
        
        XCTAssertEqual(newProfileManager.profiles.count, savedCount)
        XCTAssertEqual(newProfileManager.currentProfileId, savedId)
        XCTAssertNotNil(newProfileManager.profiles.first(where: { $0.name == "TestProfile" }))
    }
    
    func testAddUsageTime() {
        let profileId = profileManager.currentProfileId!
        
        profileManager.addUsageTime(minutes: 10, for: profileId)
        
        let profile = profileManager.profiles.first(where: { $0.id == profileId })
        XCTAssertEqual(profile?.usageMinutes, 10)
        
        profileManager.addUsageTime(minutes: 5, for: profileId)
        
        let updatedProfile = profileManager.profiles.first(where: { $0.id == profileId })
        XCTAssertEqual(updatedProfile?.usageMinutes, 15)
    }
    
    func testCheckAndResetDailyUsage() {
        let profileId = profileManager.currentProfileId!
        
        profileManager.addUsageTime(minutes: 50, for: profileId)
        
        var profile = profileManager.profiles.first(where: { $0.id == profileId })
        XCTAssertEqual(profile?.usageMinutes, 50)
        
        // Set last reset to yesterday
        if let index = profileManager.profiles.firstIndex(where: { $0.id == profileId }) {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            profileManager.profiles[index].lastResetDate = yesterday
            profileManager.saveProfiles()
        }
        
        profileManager.checkAndResetDailyUsage(for: profileId)
        
        profile = profileManager.profiles.first(where: { $0.id == profileId })
        XCTAssertEqual(profile?.usageMinutes, 0)
    }
    
    func testHasCurrentProfileReachedLimit() {
        let profileId = profileManager.currentProfileId!
        
        // Set a low limit for testing
        profileManager.updateProfile(id: profileId, dailyLimitMinutes: 30)
        
        XCTAssertFalse(profileManager.hasCurrentProfileReachedLimit())
        
        profileManager.addUsageTime(minutes: 30, for: profileId)
        
        XCTAssertTrue(profileManager.hasCurrentProfileReachedLimit())
    }
    
    func testDeleteAllNonDefaultProfiles() {
        profileManager.addProfile(name: "Profile1")
        profileManager.addProfile(name: "Profile2")
        profileManager.addProfile(name: "Profile3")
        
        XCTAssertGreaterThan(profileManager.profiles.count, 1)
        
        profileManager.deleteAllNonDefaultProfiles()
        
        XCTAssertEqual(profileManager.profiles.count, 1)
        XCTAssertTrue(profileManager.profiles.first?.isDefault ?? false)
    }
}
