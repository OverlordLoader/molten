# molten


## September 30, 2026 - Independent source verification

Declared the app-scoped UserDefaults required-reason API (CA92.1), based on the app's actual preferences and local save calls. This does not certify App Store privacy answers or third-party SDK behavior. Final signed archive privacy reports and actual-device/network behavior remain release gates.
Added the missing app privacy manifest and Resources build entry. App-owned state remains local; the Google Mobile Ads SDK privacy manifest, collection, consent, and release configuration still require a combined archive/privacy review before distribution. An empty app-owned collection list is not a zero-collection claim about the SDK.

Corrected the ad manager to use the GAD-prefixed Swift names and method labels required by the already-pinned Google Mobile Ads 11.x package. Google documents the prefix removal as a 12.x change; no package upgrade or ad activation was made. Xcode compilation remains unverified on Windows.
