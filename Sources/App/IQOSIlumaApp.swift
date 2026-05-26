import SwiftUI

@main
struct IQOSIlumaApp: App {
    @StateObject private var bleClient = IQOSBLEClient()
    @StateObject private var profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(bleClient)
                .environmentObject(profileStore)
        }
    }
}
