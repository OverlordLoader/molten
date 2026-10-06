#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

/// Wraps the Google Mobile Ads SDK: rewarded ads (opt-in rewards) and
/// throttled interstitial ads. Ads are fully optional — the game works
/// offline and ad loads simply fail silently when there's no connection.
///
/// Ad unit IDs: Google's official TEST IDs are used in DEBUG builds.
/// Release builds use clearly-marked TODO constants that Henry must replace
/// with real IDs from https://admob.com — until then, Release builds load
/// no ads at all (safe default, never test ads in production).
@MainActor
final class AdsManager: NSObject, ObservableObject {
    // MARK: - Ad unit IDs

    #if DEBUG
    /// Google's official test IDs — always safe in debug builds.
    private static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    private static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    // TODO(Henry): Replace with your real AdMob ad unit IDs.
    // AdMob → Apps → Molten → Ad units → create one Rewarded and one
    // Interstitial unit, then paste their IDs here. While these are empty,
    // Release builds simply show no ads.
    private static let rewardedAdUnitID = ""
    private static let interstitialAdUnitID = ""
    #endif

    // MARK: - Reward types

    /// What the player earns from a rewarded ad.
    enum Reward {
        /// Unlock one premium color for the next crafted piece (single use).
        case premiumColor(PieceColor)
        /// Complete the current kiln annealing instantly.
        /// NOTE: the kiln doesn't exist yet (milestone 3) — this reward is
        /// implemented in the manager API now so the kiln UI can call
        /// `earnReward(.rushKiln)` when it lands, with no manager changes.
        case rushKiln
    }

    // MARK: - State

    /// When true, no ad is ever loaded or shown. Driven by the Remove Ads
    /// purchase (StoreManager) — MoltenApp wires the two together.
    var isRemoveAdsEnabled = false

    @Published private(set) var isRewardedReady = false

    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    private var piecesSinceInterstitial = 0
    private var pendingRewardCompletion: ((Bool) -> Void)?

    private static let sessionsKey = "molten.sessions.v1"

    /// Incremented once per app launch (MoltenApp init). Interstitials never
    /// show on the very first session — let the player fall in love first.
    static func bumpSessionCount() {
        let n = UserDefaults.standard.integer(forKey: sessionsKey)
        UserDefaults.standard.set(n + 1, forKey: sessionsKey)
    }

    private var sessionCount: Int {
        UserDefaults.standard.integer(forKey: sessionsKey)
    }

    // MARK: - Lifecycle

    func start() {
        MobileAds.shared.start(completionHandler: nil)
        #if DEBUG
        print("[Ads] SDK started (DEBUG — test ad units)")
        #endif
        loadRewarded()
        loadInterstitial()
    }

    /// Call the moment Remove Ads is purchased: drops any pre-loaded ads
    /// and guarantees nothing loads or shows from here on.
    func disableAds() {
        isRemoveAdsEnabled = true
        rewardedAd = nil
        interstitialAd = nil
        isRewardedReady = false
        pendingRewardCompletion = nil
    }

    // MARK: - Rewarded ads

    func loadRewarded() {
        guard !isRemoveAdsEnabled, !Self.rewardedAdUnitID.isEmpty else {
            isRewardedReady = false
            return
        }
        RewardedAd.load(with: Self.rewardedAdUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                if let ad {
                    self.rewardedAd = ad
                    self.isRewardedReady = true
                } else {
                    self.isRewardedReady = false
                    #if DEBUG
                    print("[Ads] rewarded load failed: \(error?.localizedDescription ?? "unknown")")
                    #endif
                }
            }
        }
    }

    /// Shows a rewarded ad. Calls completion(true) only if the user watched
    /// long enough to earn the reward; completion(false) on dismiss/failure.
    /// The caller decides what the reward does (see Reward).
    func showRewarded(for reward: Reward, completion: @escaping (Bool) -> Void) {
        guard !isRemoveAdsEnabled,
              let ad = rewardedAd,
              let root = Self.rootViewController() else {
            completion(false)
            // Keep an ad warm for next time.
            loadRewarded()
            return
        }
        pendingRewardCompletion = completion
        pendingEarnedFlag = false
        ad.fullScreenContentDelegate = self
        // The reward handler fires later, on the main thread, if the user
        // watches long enough to earn the reward.
        ad.present(from: root) { [weak self] in
            Task { @MainActor in self?.pendingEarnedFlag = true }
        }
    }

    private var pendingEarnedFlag = false

    // MARK: - Interstitial ads

    func loadInterstitial() {
        guard !isRemoveAdsEnabled, !Self.interstitialAdUnitID.isEmpty else { return }
        InterstitialAd.load(with: Self.interstitialAdUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                self.interstitialAd = ad
                #if DEBUG
                if error != nil {
                    print("[Ads] interstitial load failed: \(error!.localizedDescription)")
                }
                #endif
            }
        }
    }

    /// Call when a piece is added to the gallery. Shows an interstitial at
    /// most once per 3 completed pieces, never on the first session, never
    /// when Remove Ads is owned. Only call from non-interactive moments
    /// (e.g. the result screen) — never mid-mini-game.
    func pieceCompleted() {
        guard !isRemoveAdsEnabled else { return }
        piecesSinceInterstitial += 1
        guard piecesSinceInterstitial >= 3,
              sessionCount > 1,
              let ad = interstitialAd,
              let root = Self.rootViewController() else { return }
        piecesSinceInterstitial = 0
        ad.fullScreenContentDelegate = self
        ad.present(from: root)
    }

    // MARK: - Helpers

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - FullScreenContentDelegate

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if ad is RewardedAd {
                let earned = self.pendingEarnedFlag
                self.pendingEarnedFlag = false
                self.pendingRewardCompletion?(earned)
                self.pendingRewardCompletion = nil
                self.rewardedAd = nil
                self.loadRewarded() // pre-load the next one
            } else {
                self.interstitialAd = nil
                self.loadInterstitial() // pre-load the next one
            }
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            #if DEBUG
            print("[Ads] failed to present: \(error.localizedDescription)")
            #endif
            if ad is RewardedAd {
                self.pendingRewardCompletion?(false)
                self.pendingRewardCompletion = nil
                self.rewardedAd = nil
                self.loadRewarded()
            } else {
                self.interstitialAd = nil
                self.loadInterstitial()
            }
        }
    }
}
#else
import UIKit

/// Mac test build: the Google Mobile Ads SDK ships no Mac Catalyst library, so
/// ads are compiled out. Rewarded "ads" grant the reward immediately so every
/// reward path can be tested; interstitials never show.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    enum Reward {
        case premiumColor(PieceColor)
        case rushKiln
    }
    var isRemoveAdsEnabled = false
    @Published private(set) var isRewardedReady = true
    private static let sessionsKey = "molten.sessions.v1"
    static func bumpSessionCount() {
        let n = UserDefaults.standard.integer(forKey: sessionsKey)
        UserDefaults.standard.set(n + 1, forKey: sessionsKey)
    }
    func start() {}
    func disableAds() { isRemoveAdsEnabled = true }
    func loadRewarded() {}
    func showRewarded(for reward: Reward, completion: @escaping (Bool) -> Void) { completion(!isRemoveAdsEnabled) }
    func loadInterstitial() {}
    func pieceCompleted() {}
}
#endif
