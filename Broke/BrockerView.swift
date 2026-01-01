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
                Button("Unlock for Tomorrow") {
                    unlockForNextDay()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've reached your daily limit. You can unlock the quota for tomorrow, but apps will remain blocked for today.")
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
                Text("\(currentProfile.usageMinutes) / \(limit) minutes")
                    .font(.caption)
                    .opacity(0.75)
                    .transition(.scale)
            }
            
            Text(isBlocking ? (currentProfile.isLimitReached ? "Tap to unlock for tomorrow" : "Tap to unblock") : "Tap to block")
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
                
                // Check if limit is reached and trying to unblock
                if appBlocker.isBlocking && currentProfile.isLimitReached {
                    showLimitReachedAlert = true
                } else {
                    appBlocker.toggleBlocking(for: profileManager.currentProfile, profileManager: profileManager)
                }
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag!\nPayload: \(payload)")
            }
        }
    }
    
    private func unlockForNextDay() {
        profileManager.unlockForNextDay(profileId: currentProfile.id)
        // Apps remain blocked for today
        NSLog("Unlocked for tomorrow - apps remain blocked today")
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