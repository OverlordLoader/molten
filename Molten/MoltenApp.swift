import SwiftUI

@main
struct MoltenApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var adsManager = AdsManager()

    init() {
        AdsManager.bumpSessionCount()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(storeManager)
                .environmentObject(adsManager)
                .task {
                    // Restore purchases first so the ads manager starts in the
                    // correct state (Remove Ads owners never load ads).
                    await storeManager.load()
                    if storeManager.isRemoveAdsPurchased {
                        adsManager.disableAds()
                    }
                    adsManager.start()
                }
        }
    }
}
