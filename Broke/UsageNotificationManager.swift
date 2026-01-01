//
//  UsageNotificationManager.swift
//  Broke
//
//  Manages notifications for usage warnings
//

import Foundation
import UserNotifications

class UsageNotificationManager {
    static let shared = UsageNotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                NSLog("Notification permission granted")
            } else if let error = error {
                NSLog("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleUsageWarning(for profile: Profile, percentageUsed: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Usage Warning"
        content.sound = .default
        
        let minutesRemaining = profile.dailyLimitMinutes - profile.usageMinutes
        
        if percentageUsed >= 0.9 {
            content.body = "Only \(minutesRemaining) minutes remaining for \(profile.name)!"
        } else if percentageUsed >= 0.8 {
            content.body = "\(Int(percentageUsed * 100))% of your daily limit used for \(profile.name). \(minutesRemaining) minutes remaining."
        }
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "usage-warning-\(profile.id.uuidString)-\(Int(percentageUsed * 100))", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error scheduling notification: \(error)")
            }
        }
    }
    
    func scheduleLimitReachedNotification(for profile: Profile) {
        let content = UNMutableNotificationContent()
        content.title = "Daily Limit Reached"
        content.body = "You've reached your daily limit for \(profile.name). You can unlock using tomorrow's quota."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "limit-reached-\(profile.id.uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error scheduling notification: \(error)")
            }
        }
    }
    
    func scheduleBothQuotasExhaustedNotification(for profile: Profile) {
        let content = UNMutableNotificationContent()
        content.title = "Both Quotas Exhausted"
        content.body = "You've used both today's and tomorrow's quota for \(profile.name). Apps will remain blocked until the day after tomorrow."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "both-quotas-\(profile.id.uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
