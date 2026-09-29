import SwiftUI

/// Settings & store screen: Remove Ads, color packs, restore purchases.
/// Every row is functional — no dead UI (App Store review requirement).
struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdsManager
    @State private var showNotice = false

    var body: some View {
        NavigationStack {
            List {
                premiumSection
                colorPacksSection
                purchasesSection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.05).ignoresSafeArea())
            .tint(.orange)
            .task { await store.requestProducts() }
            .alert("Store", isPresented: $showNotice, presenting: store.notice) { _ in
                Button("OK") { store.notice = nil }
            } message: { notice in
                Text(notice)
            }
            .onChange(of: store.notice) { _, new in showNotice = new != nil }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Premium

    private var premiumSection: some View {
        Section {
            Button {
                guard !store.isRemoveAdsPurchased else { return }
                Haptics.medium()
                Task { await store.purchase(productID: StoreManager.removeAdsID) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "nosign")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Remove Ads")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("No interstitial or rewarded ads, ever")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    removeAdsTrailing
                }
                .padding(.vertical, 6)
            }
            .disabled(store.isRemoveAdsPurchased || store.isPurchasing)
        } header: {
            Text("Premium")
        } footer: {
            Text("Payments are processed securely by Apple. No account needed.")
        }
    }

    @ViewBuilder
    private var removeAdsTrailing: some View {
        if store.isRemoveAdsPurchased {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
        } else if store.isPurchasing {
            ProgressView()
        } else {
            Text(store.priceString(for: StoreManager.removeAdsID, fallback: "$4.99"))
                .font(.headline.weight(.semibold))
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    // MARK: - Color packs

    private var colorPacksSection: some View {
        Section {
            ForEach(ColorPack.allCases) { pack in
                Button {
                    guard !store.isPackOwned(pack) else { return }
                    Haptics.medium()
                    Task { await store.purchase(productID: pack.productID) }
                } label: {
                    HStack(spacing: 14) {
                        HStack(spacing: -8) {
                            ForEach(pack.colors) { color in
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                            }
                        }
                        .frame(width: 64, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pack.displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(pack.colors.map(\.displayName).joined(separator: " + ")) · \(pack.tagline)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        packTrailing(pack)
                    }
                    .padding(.vertical, 6)
                }
                .disabled(store.isPackOwned(pack) || store.isPurchasing)
            }
        } header: {
            Text("Color Packs")
        } footer: {
            Text("Each pack permanently unlocks 2 new glass colors in the Studio, on all your devices.")
        }
    }

    @ViewBuilder
    private func packTrailing(_ pack: ColorPack) -> some View {
        if store.isPackOwned(pack) {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
        } else if store.isPurchasing {
            ProgressView()
        } else {
            Text(store.priceString(for: pack.productID, fallback: pack.fallbackPrice))
                .font(.headline.weight(.semibold))
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    // MARK: - Purchases

    private var purchasesSection: some View {
        Section {
            Button {
                Haptics.medium()
                Task { await store.restore() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Restore Purchases")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Re-download purchases made with your Apple ID")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    if store.isPurchasing {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.vertical, 6)
            }
            .disabled(store.isPurchasing)
        } header: {
            Text("Purchases")
        }
    }
}
