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
  check script fails the build if one appears).
- Fully playable offline — no network code at all.
- Zero data collection: no analytics/tracking SDKs (also enforced by the check
  script). Gallery persists to local UserDefaults only.
- `ITSAppUsesNonExemptEncryption = false` declared (no crypto).
- Every button on screen works; no placeholder or dead UI.

## Roadmap

- **M2 — Kiln & economy:** anneal with real-time cooling, variable-reward
  reveal (common/rare finishes, crack risk), sell prices, furnace/kiln upgrades,
  coin balance.
- **M3 — Retention & monetization:** daily commissions + streaks, 120-piece
  catalog, prestige, AdMob rewarded/interstitial, IAP (remove ads, color packs),
  "Master Pass" subscription.
- **M4 — Polish & submit:** App Store metadata, screenshots, 1024px icon,
  TestFlight, review submission.

## License

All rights reserved — Henry / OverlordLoader.
