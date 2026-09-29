# CHANGELOG — Molten

Running log of every change, kept current per Henry's standing rule so his
other AI tools can see what changed and what was added.

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
