import SwiftUI

struct ContentView: View {
    @State private var tab = 0
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var adsManager: AdsManager

    var body: some View {
        TabView(selection: $tab) {
            StudioView()
                .tabItem { Label("Studio", systemImage: "flame") }
                .tag(0)

            GalleryView(goToStudio: tabBinding(0))
                .tabItem { Label("Gallery", systemImage: "square.grid.2x2") }
                .tag(1)

            ShowcaseView(goToStudio: tabBinding(0))
                .tabItem { Label("Showcase", systemImage: "sparkles") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .preferredColorScheme(.dark)
        .tint(.orange)
        // Keep the ads manager in sync with the Remove Ads purchase.
        .onChange(of: storeManager.isRemoveAdsPurchased) { _, owned in
            if owned { adsManager.disableAds() }
        }
    }

    /// Maps a `Binding<Bool>` (set true = jump to the studio tab) onto tab selection.
    private func tabBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { tab == index },
            set: { if $0 { tab = index } }
        )
    }
}
