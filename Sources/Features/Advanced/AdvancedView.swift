import SwiftUI

struct AdvancedView: View {
    @EnvironmentObject private var ble: IQOSBLEClient

    @State private var rawHex = ""
    @State private var expectsResponse = true
    @State private var resultText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Comando raw HEX") {
                    TextEditor(text: $rawHex)
                        .frame(minHeight: 120)
                        .font(.system(.body, design: .monospaced))
                    Toggle("Attendi risposta", isOn: $expectsResponse)

                    Button("Invia comando") {
                        Task {
                            do {
                                let result = try await ble.sendRawCommand(hex: rawHex, expectsResponse: expectsResponse)
                                resultText = result
                            } catch {
                                resultText = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Risposta") {
                    if resultText.isEmpty {
                        Text("Nessuna risposta.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("Nota") {
                    Text("Usa questa sezione solo se sai esattamente cosa stai inviando. Un comando non valido può far disconnettere il dispositivo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Avanzate")
        }
    }
}
