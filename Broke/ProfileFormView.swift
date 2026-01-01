//
//  EditProfileView.swift
//  Broke
//
//  Created by Oz Tamir on 23/08/2024.
//

import SwiftUI
import SFSymbolsPicker
import FamilyControls

struct ProfileFormView: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var profileName: String
    @State private var profileIcon: String
    @State private var showSymbolsPicker = false
    @State private var showAppSelection = false
    @State private var activitySelection: FamilyActivitySelection
    @State private var showDeleteConfirmation = false
    @State private var dailyLimitHours: Int
    @State private var dailyLimitMinutes: Int
    let profile: Profile?
    let onDismiss: () -> Void
    
    private var isFormValid: Bool {
        return !profileName.isEmpty && (dailyLimitHours > 0 || dailyLimitMinutes > 0)
    }
    
    private var hasActiveUsage: Bool {
        guard let profile = profile else { return false }
        return profile.usageMinutes > 0
    }
    
    init(profile: Profile? = nil, profileManager: ProfileManager, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.profileManager = profileManager
        self.onDismiss = onDismiss
        _profileName = State(initialValue: profile?.name ?? "")
        _profileIcon = State(initialValue: profile?.icon ?? "bell.slash")
        
        var selection = FamilyActivitySelection()
        selection.applicationTokens = profile?.appTokens ?? []
        selection.categoryTokens = profile?.categoryTokens ?? []
        _activitySelection = State(initialValue: selection)
        
        // Initialize daily limit states - limits are now mandatory
        let limitMinutes = profile?.dailyLimitMinutes ?? 120 // Default to 2 hours
        _dailyLimitHours = State(initialValue: limitMinutes / 60)
        _dailyLimitMinutes = State(initialValue: limitMinutes % 60)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Details")) {
                    VStack(alignment: .leading) {
                        Text("Profile Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter profile name", text: $profileName)
                    }
                    
                    Button(action: { showSymbolsPicker = true }) {
                        HStack {
                            Image(systemName: profileIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text("Choose Icon")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Daily Limit (Required)")) {
                    Text("All profiles must have a daily usage limit.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if hasActiveUsage {
                        Text("Daily limit cannot be changed while there is active usage. Quota can only be modified on the following day when usage resets.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Hours:")
                        Spacer()
                        Picker("Hours", selection: $dailyLimitHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        .disabled(hasActiveUsage)
                    }
                    
                    HStack {
                        Text("Minutes:")
                        Spacer()
                        Picker("Minutes", selection: $dailyLimitMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        .disabled(hasActiveUsage)
                    }
                    
                    if dailyLimitHours == 0 && dailyLimitMinutes == 0 {
                        Text("Please set a limit greater than 0")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("When Broke is activated, ALL profiles are monitored simultaneously. Once a profile's daily limit is reached, you can unlock immediately but it will consume tomorrow's quota. You'll receive notifications when usage is running out.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("App Configuration")) {
                    Button(action: { showAppSelection = true }) {
                        Text("Configure Blocked Apps")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blocked Apps:")
                            Spacer()
                            Text("\(activitySelection.applicationTokens.count)")
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("Blocked Categories:")
                            Spacer()
                            Text("\(activitySelection.categoryTokens.count)")
                                .fontWeight(.bold)
                        }
                        Text("Broke can't list the names of the apps due to privacy concerns, it is only able to see the amount of apps selected in the configuration screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if profile != nil {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Profile")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(profile == nil ? "Add Profile" : "Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel", action: onDismiss),
                trailing: Button("Save", action: handleSave)
                    .disabled(!isFormValid)
            )
            .sheet(isPresented: $showSymbolsPicker) {
                SymbolsPicker(selection: $profileIcon, title: "Pick an icon", autoDismiss: true)
            }
            .sheet(isPresented: $showAppSelection) {
                NavigationView {
                    FamilyActivityPicker(selection: $activitySelection)
                        .navigationTitle("Select Apps")
                        .navigationBarItems(trailing: Button("Done") {
                            showAppSelection = false
                        })
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Profile"),
                    message: Text("Are you sure you want to delete this profile?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let profile = profile {
                            profileManager.deleteProfile(withId: profile.id)
                        }
                        onDismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func handleSave() {
        // Calculate limit value - always required, must be > 0
        let totalMinutes = dailyLimitHours * 60 + dailyLimitMinutes
        
        if let existingProfile = profile {
            profileManager.updateProfile(
                id: existingProfile.id,
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                dailyLimitMinutes: totalMinutes
            )
        } else {
            let newProfile = Profile(
                name: profileName,
                appTokens: activitySelection.applicationTokens,
                categoryTokens: activitySelection.categoryTokens,
                icon: profileIcon,
                dailyLimitMinutes: totalMinutes
            )
            profileManager.addProfile(newProfile: newProfile)
        }
        onDismiss()
    }
}
