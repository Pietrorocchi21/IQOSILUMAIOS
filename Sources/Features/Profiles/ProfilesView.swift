import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var ble: IQOSBLEClient
    @EnvironmentObject private var store: ProfileStore

    @State private var profileName = ""
    @State private var brightness: BrightnessLevel = .high
    @State private var autostart = false
    @State private var smartGesture = false
    @State private var vibration: VibrationSettings = .default
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Nuovo profilo") {
                    TextField("Nome profilo", text: $profileName)
                    Picker("Luminosità", selection: $brightness) {
                        ForEach(BrightnessLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    Toggle("Auto Start", isOn: $autostart)
                    Toggle("Smart Gesture", isOn: $smartGesture)
                    Toggle("Vibrazione: inizio riscaldamento", isOn: $vibration.heatingStart)
                    Toggle("Vibrazione: inizio utilizzo", isOn: $vibration.startingToUse)
                    Toggle("Vibrazione: fine puff", isOn: $vibration.puffEnd)
                    Toggle("Vibrazione: stop manuale", isOn: $vibration.manuallyTerminated)

                    Button("Carica valori dallo stato corrente") {
                        prefillFromSnapshot()
                    }
                    .buttonStyle(.bordered)

                    Button("Salva profilo") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Profili salvati") {
                    if store.profiles.isEmpty {
                        Text("Nessun profilo salvato.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.profiles) { profile in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profileSummary(profile))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Applica profilo al dispositivo") {
                                    Task {
                                        do {
                                            try await ble.applyProfile(profile)
                                            infoMessage = "Profilo '\(profile.name)' applicato."
                                        } catch {
                                            infoMessage = error.localizedDescription
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Elimina", role: .destructive) {
                                    store.delete(profile)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let infoMessage {
                    Section("Stato operazione") {
                        Text(infoMessage)
                    }
                }
            }
            .navigationTitle("Profili")
        }
    }

    private func prefillFromSnapshot() {
        if let value = ble.snapshot.brightness {
            brightness = value
        }
        if let value = ble.snapshot.autostartEnabled {
            autostart = value
        }
        if let value = ble.snapshot.smartGestureEnabled {
            smartGesture = value
        }
        if let value = ble.snapshot.vibration {
            vibration = value
        }
    }

    private func saveProfile() {
        let cleanedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            infoMessage = "Inserisci un nome profilo."
            return
        }

        let profile = ControlProfile(
            name: cleanedName,
            brightness: brightness,
            autostartEnabled: autostart,
            smartGestureEnabled: smartGesture,
            vibration: vibration
        )
        store.upsert(profile)
        profileName = ""
        infoMessage = "Profilo salvato."
    }

    private func profileSummary(_ profile: ControlProfile) -> String {
        let vibrationSummary = [
            profile.vibration.heatingStart ? "Heat" : nil,
            profile.vibration.startingToUse ? "StartUse" : nil,
            profile.vibration.puffEnd ? "PuffEnd" : nil,
            profile.vibration.manuallyTerminated ? "StopManuale" : nil
        ]
            .compactMap { $0 }
            .joined(separator: ", ")

        return """
        Lum: \(profile.brightness.displayName) • AutoStart: \(profile.autostartEnabled ? "ON" : "OFF") • SmartGesture: \(profile.smartGestureEnabled ? "ON" : "OFF")
        Vibrazione: \(vibrationSummary.isEmpty ? "OFF" : vibrationSummary)
        """
    }
}
