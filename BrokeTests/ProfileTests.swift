//
//  ProfileTests.swift
//  BrokeTests
//

import XCTest
@testable import Broke

final class ProfileTests: XCTestCase {
    
    func testProfileInitialization() {
        let profile = Profile(
            name: "Test Profile",
            appTokens: [],
            categoryTokens: [],
            icon: "bell",
            dailyLimitMinutes: 60
        )
        
        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertEqual(profile.icon, "bell")
        XCTAssertEqual(profile.dailyLimitMinutes, 60)
        XCTAssertEqual(profile.usageMinutes, 0)
        XCTAssertTrue(profile.appTokens.isEmpty)
        XCTAssertTrue(profile.categoryTokens.isEmpty)
        XCTAssertNil(profile.lastResetDate)
    }
    
    func testProfileDefaultInitialization() {
        let profile = Profile(
            name: "Default",
            appTokens: [],
            categoryTokens: []
        )
        
        XCTAssertEqual(profile.name, "Default")
        XCTAssertEqual(profile.dailyLimitMinutes, 120) // Default value
        XCTAssertTrue(profile.isDefault)
    }
    
    func testIsDefault() {
        let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [])
        let customProfile = Profile(name: "Custom", appTokens: [], categoryTokens: [])
        
        XCTAssertTrue(defaultProfile.isDefault)
        XCTAssertFalse(customProfile.isDefault)
    }
    
    func testIsLimitReached() {
        var profile = Profile(
            name: "Test",
            appTokens: [],
            categoryTokens: [],
            dailyLimitMinutes: 60
        )
        
        XCTAssertFalse(profile.isLimitReached)
        
        profile.usageMinutes = 59
        XCTAssertFalse(profile.isLimitReached)
        
        profile.usageMinutes = 60
        XCTAssertTrue(profile.isLimitReached)
        
        profile.usageMinutes = 61
        XCTAssertTrue(profile.isLimitReached)
    }
    
    func testIsTomorrowQuotaExhausted() {
        var profile = Profile(
            name: "Test",
            appTokens: [],
            categoryTokens: [],
            dailyLimitMinutes: 60
        )
        
        profile.usageMinutes = 59
        XCTAssertFalse(profile.isTomorrowQuotaExhausted)
        
        profile.usageMinutes = 60
        XCTAssertFalse(profile.isTomorrowQuotaExhausted)
        
        profile.usageMinutes = 119
        XCTAssertFalse(profile.isTomorrowQuotaExhausted)
        
        profile.usageMinutes = 120
        XCTAssertTrue(profile.isTomorrowQuotaExhausted)
    }
    
    func testCanUnlockUsingTomorrowQuota() {
        var profile = Profile(
            name: "Test",
            appTokens: [],
            categoryTokens: [],
            dailyLimitMinutes: 60
        )
        
        profile.usageMinutes = 59
        XCTAssertFalse(profile.canUnlockUsingTomorrowQuota)
        
        profile.usageMinutes = 60
        XCTAssertTrue(profile.canUnlockUsingTomorrowQuota)
        
        profile.usageMinutes = 119
        XCTAssertTrue(profile.canUnlockUsingTomorrowQuota)
        
        profile.usageMinutes = 120
        XCTAssertFalse(profile.canUnlockUsingTomorrowQuota)
    }
    
    func testUsagePercentage() {
        var profile = Profile(
            name: "Test",
            appTokens: [],
            categoryTokens: [],
            dailyLimitMinutes: 100
        )
        
        profile.usageMinutes = 0
        XCTAssertEqual(profile.usagePercentage, 0.0, accuracy: 0.01)
        
        profile.usageMinutes = 50
        XCTAssertEqual(profile.usagePercentage, 0.5, accuracy: 0.01)
        
        profile.usageMinutes = 100
        XCTAssertEqual(profile.usagePercentage, 1.0, accuracy: 0.01)
        
        profile.usageMinutes = 150
        XCTAssertEqual(profile.usagePercentage, 1.5, accuracy: 0.01)
    }
    
    func testShouldNotifyUsageWarning() {
        var profile = Profile(
            name: "Test",
            appTokens: [],
            categoryTokens: [],
            dailyLimitMinutes: 100
        )
        
        profile.usageMinutes = 79
        XCTAssertFalse(profile.shouldNotifyUsageWarning)
        
        profile.usageMinutes = 80
        XCTAssertTrue(profile.shouldNotifyUsageWarning)
        
        profile.usageMinutes = 90
        XCTAssertTrue(profile.shouldNotifyUsageWarning)
        
        profile.usageMinutes = 99
        XCTAssertTrue(profile.shouldNotifyUsageWarning)
        
        profile.usageMinutes = 100
        XCTAssertFalse(profile.shouldNotifyUsageWarning)
    }
}
