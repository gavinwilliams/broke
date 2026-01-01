# Screen Time API Integration Guide

## Overview
This document explains how to integrate the iOS Screen Time API (`DeviceActivityMonitor`) for actual app usage tracking in the Broke app.

## Current Implementation
The app currently uses a timer-based approach that tracks elapsed time while apps are blocked. This is a fallback until the Screen Time API is fully integrated.

## Required Components

### 1. DeviceActivityMonitor Extension
Create a new app extension target in Xcode:

```swift
// DeviceActivityMonitorExtension.swift
import DeviceActivity
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Apps became available - start tracking usage
        NSLog("Device activity started: \(activity)")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Usage period ended
        NSLog("Device activity ended: \(activity)")
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Usage threshold reached - update usage counters
        NSLog("Threshold reached for event: \(event)")
        
        // Update usage in shared container
        if let defaults = UserDefaults(suiteName: "group.com.broke.app") {
            let currentUsage = defaults.integer(forKey: "currentUsage")
            defaults.set(currentUsage + 1, forKey: "currentUsage")
        }
    }
}
```

### 2. Xcode Project Setup

#### Create Extension Target
1. File → New → Target → Device Activity Monitor Extension
2. Name it "BrokeActivityMonitor"
3. Set the bundle identifier to `com.broke.app.activitymonitor`

#### Configure Info.plist
Add to extension's Info.plist:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.monitor</string>
</dict>
```

#### Add Entitlements
Both main app and extension need:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.developer.device-activity</key>
<true/>
```

#### App Groups
Enable App Groups for data sharing:
1. Select main app target → Signing & Capabilities
2. Add "App Groups" capability
3. Create group: `group.com.broke.app`
4. Repeat for extension target

### 3. Main App Integration

Update `AppBlocker.swift` to use Device Activity:

```swift
import DeviceActivity

class AppBlocker: ObservableObject {
    private let deviceActivityCenter = DeviceActivityCenter()
    
    func startMonitoring(for profiles: [Profile]) {
        // Create schedule for each profile
        for profile in profiles {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            
            // Create events for usage thresholds
            let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
                .warningAt80: DeviceActivityEvent(
                    applications: profile.appTokens,
                    threshold: DateComponents(minute: Int(Double(profile.dailyLimitMinutes) * 0.8))
                ),
                .warningAt90: DeviceActivityEvent(
                    applications: profile.appTokens,
                    threshold: DateComponents(minute: Int(Double(profile.dailyLimitMinutes) * 0.9))
                ),
                .limitReached: DeviceActivityEvent(
                    applications: profile.appTokens,
                    threshold: DateComponents(minute: profile.dailyLimitMinutes)
                )
            ]
            
            do {
                try deviceActivityCenter.startMonitoring(
                    .init(rawValue: profile.id.uuidString),
                    during: schedule,
                    events: events
                )
            } catch {
                NSLog("Failed to start monitoring: \(error)")
            }
        }
    }
    
    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring()
    }
}
```

### 4. Usage Data Synchronization

Create shared storage helper:

```swift
// SharedUsageStorage.swift
import Foundation

class SharedUsageStorage {
    static let shared = SharedUsageStorage()
    private let defaults: UserDefaults?
    
    private init() {
        defaults = UserDefaults(suiteName: "group.com.broke.app")
    }
    
    func updateUsage(for profileId: UUID, minutes: Int) {
        let key = "usage-\(profileId.uuidString)"
        let currentUsage = defaults?.integer(forKey: key) ?? 0
        defaults?.set(currentUsage + minutes, forKey: key)
    }
    
    func getUsage(for profileId: UUID) -> Int {
        let key = "usage-\(profileId.uuidString)"
        return defaults?.integer(forKey: key) ?? 0
    }
    
    func resetUsage(for profileId: UUID) {
        let key = "usage-\(profileId.uuidString)"
        defaults?.set(0, forKey: key)
    }
}
```

### 5. Testing

1. Build and run the main app
2. Build the extension (it won't run standalone)
3. Grant Family Controls permission when prompted
4. Use apps in monitored profiles
5. Check console logs for extension activity

### 6. Common Issues

**Extension Not Running**
- Verify bundle identifier is correct
- Check extension is included in build phases
- Ensure entitlements are configured for both targets

**No Usage Events**
- Verify apps are properly selected in FamilyActivityPicker
- Check schedule is active (00:00 to 23:59)
- Ensure device time is within schedule range

**Data Not Syncing**
- Verify App Groups are enabled on both targets
- Check group identifier matches exactly
- Use same group in both app and extension

## Migration Path

1. **Phase 1** (Current): Timer-based tracking as fallback
2. **Phase 2**: Add extension target and basic monitoring
3. **Phase 3**: Migrate to Screen Time API exclusively
4. **Phase 4**: Remove timer-based tracking

## References

- [DeviceActivity Documentation](https://developer.apple.com/documentation/deviceactivity)
- [FamilyControls Documentation](https://developer.apple.com/documentation/familycontrols)
- [WWDC 2021: Meet Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/)
