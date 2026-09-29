# Molten — Glassblowing Studio

A native iOS glassblowing studio game. Gather molten glass, shape it through
touch mini-games, and build a gallery of glass art. Built with SwiftUI +
SpriteKit, iOS 17+, bundle ID `app.molten.studio`.

**Status: Milestone 1** — repo scaffold, glass-rendering engine, gather/shape
mini-games, gallery. See [CHANGELOG.md](CHANGELOG.md) for the running log of
every change (kept current per Henry's standing rule).

## The game (vision)

Core loop: **Gather** molten glass (timing tap) → **Shape** it (blow / spin /
carve mini-games) → **Anneal** in the kiln (real-time wait, variable-reward
reveal) → **Sell** to collectors / fulfill daily commissions → **Reinvest** in
a hotter furnace and more kilns. Idle layer: kilns keep cooling while you're
away. Collection catalog (~120 pieces), streaks, and a prestige system keep
players coming back.

Milestone 1 ships the visual core and the skill-based front half of that loop.
The kiln, economy, commissions, ads, and IAP arrive in later milestones.

## Requirements

- Xcode 16+ on macOS, iOS 17+ device or simulator
- No third-party dependencies — pure SwiftUI + SpriteKit, zero SDKs

## Run it

1. Open `Molten.xcodeproj` in Xcode.
2. Pick a simulator (iPhone 16, iOS 18) or your device.
3. Press Run. No signing setup needed for simulator; for a device, set your
   personal team under Signing & Capabilities.

The **Showcase** tab opens on a live demo scene: four finished pieces on
pedestals in a dark studio with drifting embers. Tap a piece. Then go to
**Studio** to craft: pick a shape and color → gather → pick a technique →
shape → add the piece to your **Gallery**.

## Project structure

```
Molten/
  MoltenApp.swift            @main entry, owns GameStore
  ContentView.swift           TabView: Studio / Gallery / Showcase
  Info.plist                 display name, portrait-only, encryption flag
  Game/
    Models.swift             PieceShape, PieceColor, GlassPiece (Codable)
    GameStore.swift           gallery state, UserDefaults persistence (offline)
    Haptics.swift             UIFeedbackGenerator wrapper
    GlassRenderer.swift        ★ the visual core: molten blobs, finished pieces,
                              studio backgrounds, ember particles (all drawn in code)
    DemoScene.swift           showcase scene (4 sample pieces)
    GatherScene.swift         mini-game: heat-meter timing tap
    BlowScene.swift           mini-game: press-hold-release pressure gauge
    SpinScene.swift           mini-game: tap to keep the needle in the glow
    CarveScene.swift          mini-game: trace the glowing pattern
  Views/
    StudioView.swift          crafting flow: pick → gather → technique → shape → result
    GalleryView.swift         grid + detail of crafted pieces
    ShowcaseView.swift        full-screen demo scene
    MiniGameHost.swift        SpriteView wrapper with HUD overlay + Quit
.github/workflows/
  apple-release.yml          signed IPA build + optional App Store Connect upload
scripts/
  apple-release.py           macOS signing/upload (mirrors Henry's other apps)
  apple-release-check.py     ubuntu pre-release safety checks
```

## Release pipeline

Same pattern as Henry's other apps (`apple-release.yml`): PRs and pushes run a
5-minute safety job on ubuntu; an explicit **workflow_dispatch on `main`** runs
the signed release on a macOS runner.

Differences from the other apps (Molten is native Swift, not Capacitor):
- Builds with `xcodebuild -project Molten.xcodeproj -target Molten archive`
  instead of the Capacitor sync steps.
- Uses a **dedicated environment `app-store-release-molten`** (not the shared
  `app-store-release`), because the App Store provisioning profile is
  per-bundle-ID.

### Henry's one-time setup before the first release

1. Create the `molten` repo under OverlordLoader (public) — the GitHub App
   integration cannot create repositories itself.
2. Install/allow the Muse GitHub App on the `molten` repo (Select repositories).
3. In the Apple Developer portal: register App ID `app.molten.studio`, create an
   **App Store** provisioning profile for it.
4. In GitHub repo settings → Environments → new environment
   `app-store-release-molten`, add secrets: `APPLE_DISTRIBUTION_P12_BASE64`,
   `APPLE_DISTRIBUTION_P12_PASSWORD`, `APPLE_PROFILE_BASE64` (the Molten
   profile), `APP_STORE_CONNECT_KEY_BASE64`.
5. Actions → "Apple App Store release" → Run workflow on `main`, set build
   number, choose upload or validation-only.

## Monetization setup (milestone 2)

The game ships with ads + in-app purchases fully wired. Two dashboards need
Henry's input — **nothing here can be done by anyone but the account owner.**

### A. App Store Connect — create 4 in-app purchase products

App Store Connect → Molten → In-App Purchases. Product IDs must match
**exactly** (the code references these strings):

| Product ID | Type | Price | Display name |
|---|---|---|---|
| `app.molten.studio.removeads` | Non-Consumable | $4.99 | Remove Ads |
| `app.molten.studio.colorpack.aurora` | Non-Consumable | $1.99 | Aurora Pack |
| `app.molten.studio.colorpack.inferno` | Non-Consumable | $1.99 | Inferno Pack |
| `app.molten.studio.colorpack.abyss` | Non-Consumable | $1.99 | Abyss Pack |

Each color pack permanently unlocks 2 glass colors (Aurora+Opal,
Magma+Solar, Abyss+Void). "Remove Ads" disables all rewarded and
interstitial ads immediately, on all devices (restorable via the in-app
"Restore Purchases" button, which Apple requires).

Until the products exist, the Settings screen shows fallback prices and
purchases fail gracefully with a "not available" message — the game itself
is unaffected.

### B. AdMob — replace test IDs with real ones

1. Create an AdMob account at https://admob.com, add app "Molten"
   (iOS, bundle `app.molten.studio`) → copy the **App ID**.
2. Create two ad units: one **Rewarded**, one **Interstitial** → copy their IDs.
3. In code, replace:
   - `Molten/Info.plist` → `GADApplicationIdentifier` (currently Google's
     official test ID, marked with a TODO comment)
   - `Molten/Game/AdsManager.swift` → `rewardedAdUnitID` /
     `interstitialAdUnitID` in the `#else` (Release) block, marked
     `TODO(Henry)`
4. Debug builds always use Google's official test IDs — safe to develop with.

While the Release IDs are empty, Release builds simply show no ads (safe
default — never test ads in production).

### C. Get paid (one-time, covers all Henry's apps)

- **App Store:** App Store Connect → Agreements → sign the **Paid
  Applications** agreement; add bank account + tax forms under
  "Agreements, Tax, and Banking". Apple pays monthly (~33 days after month
  end). Enroll in the **App Store Small Business Program** to keep 85%
  instead of 70% (under $1M/year).
- **AdMob:** AdMob → Payments → verify identity, add bank account. Google
  pays monthly once earnings pass $100.

### How it behaves

- **Rewarded ads** (player opts in): "Watch Ad to Use Once" on locked
  premium colors; "Rush kiln" reward is implemented in `AdsManager.Reward`
  for the kiln milestone to consume — no UI for it yet (no dead buttons).
- **Interstitials:** at most 1 per 3 finished pieces, only from the result
  screen (never mid-mini-game), never on the first session, never with
  Remove Ads owned.
- **Offline:** ad loads fail silently; the game is fully playable.
- **Privacy:** AdMob is the only network SDK. No analytics, no tracking,
  no ATT prompt, no sign-in.

## Game-feel tuning notes (milestone 1)

Feel is the product in casual games, so these were tuned deliberately:

- **Gather:** needle oscillation ramps 2.4 → 4.6 rad/s over 8s — starts readable,
  ends tense. Sweet window at 64–78% of the track (upper-middle, where eyes
  rest). Success quality floors at 0.55 so a near-miss still feels okay;
  perfect (>0.92) gets its own label and a bigger burst.
- **Blow:** fill rate 0.5/s means ~1.4s of holding to reach the zone — long
  enough to feel risky, short enough to stay snappy. ±0.025 needle wobble keeps
  eyes locked. Zone 0.60–0.80 with centeredness scoring rewards precision.
- **Spin:** tap-to-reverse (not tap-to-brake) — reversal is instantly
  understandable and forgiving. Perfect threshold at 55% in-zone time, so most
  players "win" while skilled players max out.
- **Carve:** 30pt snap radius is generous on purpose; quality blends accuracy
  (45%) and coverage (55%) so finishing always beats perfectionism.
- **Every touch gets feedback:** haptics on all outcomes (success/error/ticks),
  particles on all successes, result labels within 100ms of the action.
- **Rendering:** molten glass = white-hot core + 2 additive bloom layers +
  ember particles + slow scale/alpha "breathing". Finished pieces = translucent
  gradient + caustic highlight streak + rim-light crescent. Dark studio +
  vignette makes the glow do the work — the same trick Smash Hit uses.

## Apple-review safety (non-negotiable, enforced)

- No sign-in of any kind. No accounts, no Game Center.
- No external billing, no web links, no `openURL` calls anywhere (the release
  check script fails the build if one appears). All purchases via StoreKit 2.
- Fully playable offline — no required network calls. AdMob is the only
  network SDK; ad loads fail gracefully offline and the game is unaffected.
- Zero data collection beyond AdMob's own ad serving: no analytics/tracking
  SDKs (also enforced by the check script; GoogleMobileAds is explicitly
  allow-listed as the ad network). No ATT prompt, no sign-in. Gallery and
  purchase cache persist to local UserDefaults only.
- `ITSAppUsesNonExemptEncryption = false` declared (no crypto).
- Every button on screen works; no placeholder or dead UI.

## Roadmap

- **M2 — Monetization (done 2026-09-29):** AdMob via SPM (rewarded +
  throttled interstitial, test IDs in DEBUG, TODO-marked Release IDs),
  StoreKit 2 (Remove Ads $4.99 + 3 color packs $1.99, verified transactions,
  restore purchases), Settings store screen, premium-color lock/unlock flow
  in the Studio (watch-ad single use or pack purchase), 6 new premium colors.
- **M3 — Kiln & economy:** anneal with real-time cooling, variable-reward
  reveal (common/rare finishes, crack risk), sell prices, furnace/kiln upgrades,
  coin balance. Consumes the existing `AdsManager.Reward.rushKiln` reward.
- **M4 — Retention:** daily commissions + streaks, 120-piece catalog,
  prestige, "Master Pass" subscription.
- **M5 — Polish & submit:** App Store metadata, screenshots, 1024px icon,
  TestFlight, review submission.

## License

All rights reserved — Henry / OverlordLoader.
