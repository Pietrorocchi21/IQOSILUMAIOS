import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ConnectionView()
                .tabItem {
                    Label("Connessione", systemImage: "antenna.radiowaves.left.and.right")
                }

            ControlsView()
                .tabItem {
                    Label("Controlli", systemImage: "switch.2")
                }

            ProfilesView()
                .tabItem {
                    Label("Profili", systemImage: "slider.horizontal.3")
                }

            AdvancedView()
                .tabItem {
                    Label("Avanzate", systemImage: "terminal")
                }
        }
    }
}
