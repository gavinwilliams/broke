//
//  BrockerView.swift
//  Broke
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

struct BrokerView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @StateObject private var nfcReader = NFCReader()
    private let tagPhrase = "BROKE-IS-GREAT"
    
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    @State private var showLimitReachedAlert = false
    @State private var showBothQuotasExhaustedAlert = false
    
    private var isBlocking : Bool {
        get {
            return appBlocker.isBlocking
        }
    }
    
    private var currentProfile: Profile {
        profileManager.currentProfile
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) {
                        blockOrUnblockButton(geometry: geometry)
                        
                        if !isBlocking {
                            Divider()
                            
                            ProfilesPicker(profileManager: profileManager)
                                .frame(height: geometry.size.height / 2)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
                }
            }
            .navigationBarItems(trailing: createTagButton)
            .alert(isPresented: $showWrongTagAlert) {
                Alert(
                    title: Text("Not a Broker Tag"),
                    message: Text("You can create a new Broker tag using the + button"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Create Broker Tag", isPresented: $showCreateTagAlert) {
                Button("Create") { createBrokerTag() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to create a new Broker tag?")
            }
            .alert("Tag Creation", isPresented: $nfcWriteSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(nfcWriteSuccess ? "Broker tag created successfully!" : "Failed to create Broker tag. Please try again.")
            }
            .alert("Daily Limit Reached", isPresented: $showLimitReachedAlert) {
                Button("Use Tomorrow's Quota") {
                    unlockUsingTomorrowQuota()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've reached your daily limit of \(currentProfile.dailyLimitMinutes ?? 0) minutes. You can unblock now, but any additional time used today will consume tomorrow's quota.")
            }
            .alert("Both Quotas Exhausted", isPresented: $showBothQuotasExhaustedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've used both today's and tomorrow's quota (\(currentProfile.usageMinutes) / \(currentProfile.dailyLimitMinutes ?? 0) minutes). Apps will remain blocked until the day after tomorrow.")
            }
            .onAppear {
                // Check for daily reset on app start
                profileManager.checkAndResetDailyUsage(for: currentProfile.id)
                
                // Restore usage tracking if app was already blocking
                appBlocker.restoreUsageTrackingIfNeeded(for: currentProfile, profileManager: profileManager)
            }
        }
        .animation(.spring(), value: isBlocking)
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            // Show usage info if daily limit is set
            if let limit = currentProfile.dailyLimitMinutes {
                if currentProfile.isTomorrowQuotaExhausted {
                    Text("\(currentProfile.usageMinutes) / \(limit * 2) minutes (both quotas used)")
                        .font(.caption)
                        .opacity(0.75)
                        .transition(.scale)
                } else {
                    Text("\(currentProfile.usageMinutes) / \(limit) minutes")
                        .font(.caption)
                        .opacity(0.75)
                        .transition(.scale)
                }
            }
            
            Text(isBlocking ? (currentProfile.isTomorrowQuotaExhausted ? "Blocked until day after tomorrow" : (currentProfile.isLimitReached ? "Tap to use tomorrow's quota" : "Tap to unblock")) : "Tap to block")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                withAnimation(.spring()) {
                    scanTag()
                }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height / 3)
            }
            .transition(.scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isBlocking ? geometry.size.height : geometry.size.height / 2)
        .animation(.spring(), value: isBlocking)
    }
    
    private func scanTag() {
        nfcReader.scan { payload in
            if payload == tagPhrase {
                NSLog("Toggling block")
                
                // Check if trying to unblock when limit is reached
                if appBlocker.isBlocking && currentProfile.isLimitReached {
                    // Check if tomorrow's quota is also exhausted
                    if currentProfile.isTomorrowQuotaExhausted {
                        showBothQuotasExhaustedAlert = true
                    } else if currentProfile.canUnlockUsingTomorrowQuota {
                        showLimitReachedAlert = true
                    }
                } else {
                    appBlocker.toggleBlocking(for: profileManager.currentProfile, profileManager: profileManager)
                }
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag!\nPayload: \(payload)")
            }
        }
    }
    
    private func unlockUsingTomorrowQuota() {
        profileManager.unlockUsingTomorrowQuota(profileId: currentProfile.id)
        // Now unblock the apps - usage will count against tomorrow's quota
        appBlocker.toggleBlocking(for: currentProfile, profileManager: profileManager)
        NSLog("Unlocked using tomorrow's quota - additional usage will deplete tomorrow's quota")
    }
    
    private var createTagButton: some View {
        Button(action: {
            showCreateTagAlert = true
        }) {
            Image(systemName: "plus")
        }
        .disabled(!NFCNDEFReaderSession.readingAvailable)
    }
    
    private func createBrokerTag() {
        nfcReader.write(tagPhrase) { success in
            nfcWriteSuccess = !success
            showCreateTagAlert = false
        }
    }
}