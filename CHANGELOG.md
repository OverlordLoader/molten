## 2026-09-29 — Add guarded Apple release workflow

Added manual-only main-branch signing with a repository-specific protected environment, immutable action versions, release-safety checks and opt-in TestFlight upload. No workflow dispatch or store submission performed. Apple app records, signed-device QA and truthful advertising/privacy metadata remain required.

# CHANGELOG — Molten

Running log of every change, kept current per Henry's standing rule so his
other AI tools can see what changed and what was added.

## 2026-09-29 — Milestone 2: monetization (ads + in-app purchases)

### Added
- `Game/AdsManager.swift` — Google Mobile Ads wrapper (`@MainActor`,
  `ObservableObject`): SDK start, rewarded ads with earned-reward callback,
  interstitial ads throttled to max 1 per 3 finished pieces (only from the
  result screen, never mid-mini-game, never on first app session), graceful
  offline failure (loads just fail, game unaffected). `disableAds()` kills
  everything the moment Remove Ads is purchased. DEBUG builds use Google's
  official test ad units; Release builds use empty TODO(Henry)-marked
  constants (no ads until Henry pastes real IDs — safe default).
- `Game/StoreManager.swift` — StoreKit 2 purchases: product IDs
  `app.molten.studio.removeads` ($4.99 non-consumable),
  `app.molten.studio.colorpack.{aurora,inferno,abyss}` ($1.99 non-consumable
  each); transaction verification + `finish()`; live transaction listener
  (handles refunds/revokes/family sharing); `AppStore.sync()` restore;
  single-use rewarded-ad color unlock persisted across launches.
- `Game/Models.swift` — 6 new premium `PieceColor` cases (aurora, opal,
  magma, solar, abyss, void) with SwiftUI/SpriteKit/glow colors; new
  `ColorPack` enum (productID, display name, tagline, colors, fallback price).
  `PieceColor.pack` returns nil for the 6 always-free base colors.
- `Views/SettingsView.swift` — new Settings tab (gear icon): Remove Ads row
  (live App Store price or "Owned"), 3 color-pack rows with color-dot
  previews, working Restore Purchases with result message. All rows
  functional; purchasing shows spinner; errors surface via alert.
- `Views/StudioView.swift` — color picker now shows all 12 colors; locked
  premium colors show a lock badge; tapping opens `UnlockColorSheet` (watch
  rewarded ad to use once, or buy the pack — ad option hidden entirely when
  Remove Ads is owned); ad unlock consumed when the piece starts.
  "Add to Gallery" now also triggers the throttled interstitial check.
- `MoltenApp.swift` / `ContentView.swift` — new `StoreManager` +
  `AdsManager` state objects injected as environment objects; purchases
  restore before ads start; Remove Ads purchase immediately disables ads.
- `Molten/Info.plist` — `GADApplicationIdentifier` with Google's official
  test App ID + TODO comment (Henry must replace before release).
- `tools/gen_pbxproj.py` — 18 Swift sources; adds the Google Mobile Ads
  Swift package (upToNextMajorVersion from 11.0.0) via
  XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency, linked
  into the Frameworks phase. `project.pbxproj` regenerated and verified
  (all file refs resolve).
- `scripts/apple-release-check.py` — GoogleMobileAds removed from banned
  imports (now the intentional ad network); new check that
  `GADApplicationIdentifier` is present in Info.plist. All 13 checks PASS.
- `README.md` — new "Monetization setup" section: exact IAP product ID
  table for App Store Connect, AdMob account/ad-unit checklist with the
  exact code locations to paste real IDs, one-time banking/tax steps for
  Apple + Google payouts; review-safety section updated (AdMob is the only
  network SDK); roadmap updated (M2 done, kiln/economy now M3).

### Deliberately NOT in milestone 2
- Kiln/anneal, economy, commissions, catalog, prestige, Master Pass
  (unchanged from M1 roadmap).
- Real AdMob IDs (Henry's AdMob account) and App Store Connect IAP products
  (Henry's developer account) — documented in README, cannot be delegated.
- The `AdsManager.Reward.rushKiln` case is implemented in the manager API
  but has no UI yet — the kiln milestone will call it. No dead buttons.

### Notes
- First Xcode/SPM build will resolve the Google Mobile Ads package from
  GitHub (needs network on the Mac runner — standard for SPM).
- `import GoogleMobileAds` will fail to compile until Xcode resolves the
  package — expected, not a code error.

## 2026-09-29 — Milestone 1: scaffold + visual core + gather/shape mini-games

### Added
- New repo scaffold: `Molten.xcodeproj` (hand-generated, Xcode 16 format),
  15 Swift sources, `Info.plist` (display name "Molten", portrait-only,
  `ITSAppUsesNonExemptEncryption=false`), bundle ID `app.molten.studio`,
  iOS 17+ deployment target.
- `Game/GlassRenderer.swift` — the visual core, all drawn in code (no image
  assets): `studioBackground` (dark gradient + furnace glow + vignette +
  ambient embers), `moltenBlobNode` (white-hot core + 2 additive bloom layers +
  ember emitter + heat-shimmer "breathing"), `finishedPieceNode` (translucent
  gradient silhouette + drop shadow + inner glow + caustic highlight streak +
  rim-light crescent), `emberEmitter`, one-shot `burst`, and `previewScene`
  for gallery/showcase thumbnails. Silhouettes: vase, orb, teardrop, twist.
- `Game/DemoScene.swift` — showcase scene: 4 finished pieces
  (Ember Vase, Ocean Orb, Violet Teardrop, Forest Twist) on pedestals, slow
  camera drift, bob/sway, tap-a-piece pulse + burst + haptic + title flash.
- `Game/GatherScene.swift` — heat-meter timing tap; needle oscillation ramps
  2.4→4.6 rad/s; sweet window 64–78%; quality by centeredness (floor 0.55 on
  hit, 0.2 on miss); success/error haptics + particles.
- `Game/BlowScene.swift` — press-hold-release pressure gauge; 0.5/s fill with
  needle wobble; target zone 0.60–0.80; overfill pops the glass (quality 0.15);
  centeredness scoring; zone-entry tick haptic.
- `Game/SpinScene.swift` — 12s round; tap reverses needle direction; keep it
  in the 75° glowing zone; quality = in-zone time (55% earns perfect);
  motion trail + streak-brightened zone.
- `Game/CarveScene.swift` — trace 1 of 3 glowing patterns (wave/spiral/zigzag);
  30pt snap radius; live progress %; quality = 45% accuracy + 55% coverage;
  throttled tick haptics per carved segment.
- `Game/Models.swift` — `PieceShape`, `PieceColor` (6 colors with SwiftUI +
  SpriteKit colors), `GlassPiece` (gather/shape quality, overall = 35/65
  blend, 1–3 stars, title).
- `Game/GameStore.swift` — `@MainActor ObservableObject` gallery, newest
  first, JSON persistence to local UserDefaults (`molten.gallery.v1`).
  No cloud, no analytics.
- `Game/Haptics.swift` — `UIFeedbackGenerator` wrapper
  (light/medium/heavy/success/error/selection).
- `Views/StudioView.swift` — crafting flow: pick shape+color → gather →
  pick technique (Blow/Spin/Carve) → shape → result (live piece preview,
  stars, quality bars, working Add-to-Gallery / Discard).
- `Views/GalleryView.swift` — 2-column grid of live piece previews, detail
  sheet with stats + working Delete, empty state with working CTA.
- `Views/ShowcaseView.swift` — full-screen demo scene + working CTA.
- `Views/MiniGameHost.swift` — `SpriteView` wrapper: HUD title/hint overlay,
  working Quit, result flash → completion callback.
- `ContentView.swift` / `MoltenApp.swift` — dark tab bar
  (Studio / Gallery / Showcase), orange accent.
- `.github/workflows/apple-release.yml` — signed-IPA pipeline mirroring
  Henry's other apps, adapted for native Swift (`xcodebuild archive` +
  export); dedicated `app-store-release-molten` environment (per-bundle-ID
  provisioning profile); workflow_dispatch with build_number + upload inputs.
- `scripts/apple-release.py` — macOS signer: temp keychain, profile
  validation (team 5U37FQG3VS, App Store profile for app.molten.studio,
  distribution-cert pin), pbxproj patch → archive → export → altool
  validate (+ optional upload), manifest, cleanup. Never prints secrets.
- `scripts/apple-release-check.py` — ubuntu safety job: bundle ID, display
  name, deployment target ≥ 17.0, no http:// URLs, no analytics/tracking
  imports, no external-open calls, encryption flag, workflow environment.

### Deliberately NOT in milestone 1 (later milestones)
- Kiln/anneal (real-time cooling + reveal), economy (coins, prices, upgrades)
- Daily commissions, streaks, 120-piece catalog, prestige
- Ads (AdMob) and IAP (remove ads, color packs, Master Pass)
- App Store metadata, screenshots, 1024px app icon
- Sound effects / music (haptics only for now)

### Fixed during review (2026-09-29)
- Added missing `import UIKit` to Gather/Blow/Spin/Carve scenes (they use
  `UIBezierPath`/`UIGraphicsImageRenderer`; `import SpriteKit` alone does not
  expose UIKit symbols — would have failed compilation).
- Fixed `actions/upload-artifact` pin to the exact SHA used by Henry's other
  repos (was a misremembered SHA; never guess action SHAs).

### Blockers / notes
- 2026-09-29: GitHub App integration cannot create repositories
  (`POST /user/repos` → 403 "Resource not accessible by integration").
  Henry must create the empty public `molten` repo under OverlordLoader and
  grant the Muse GitHub App access to it; then all files here can be pushed.
- Henry must create the `app-store-release-molten` GitHub environment with an
  App Store provisioning profile for `app.molten.studio` before the first
  signed release (see README).
