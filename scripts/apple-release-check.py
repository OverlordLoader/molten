#!/usr/bin/env python3
"""Pre-release safety checks for Molten (runs on ubuntu-latest).

Verifies the release-critical invariants without touching Apple signing:
bundle identity, platform floor, App-Store-review safety (no http:// URLs,
no analytics/tracking SDK imports, no external-open calls), and the
non-exempt-encryption declaration. Fails loudly on any violation.
"""

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPECTED_BUNDLE = "app.molten.studio"
EXPECTED_DISPLAY_NAME = "Molten"
MIN_DEPLOYMENT = (17, 0)

# Third-party SDKs that would violate the zero-data-collection promise.
BANNED_IMPORTS = [
    "Firebase",
    "GoogleMobileAds",
    "AppTrackingTransparency",
    "AdSupport",
    "Facebook",
    "Amplitude",
    "Mixpanel",
]

failures = []


def check(condition, message):
    print(("PASS" if condition else "FAIL") + ": " + message)
    if not condition:
        failures.append(message)


def main():
    info_path = ROOT / "Molten" / "Info.plist"
    check(info_path.exists(), "Molten/Info.plist exists")
    if info_path.exists():
        with info_path.open("rb") as fh:
            info = plistlib.load(fh)
        check(info.get("CFBundleDisplayName") == EXPECTED_DISPLAY_NAME,
              f"CFBundleDisplayName == {EXPECTED_DISPLAY_NAME}")
        check(info.get("ITSAppUsesNonExemptEncryption") is False,
              "ITSAppUsesNonExemptEncryption is false (no export-compliance prompt)")
        orientations = info.get("UISupportedInterfaceOrientations", [])
        check(orientations == ["UIInterfaceOrientationPortrait"],
              "portrait-only orientations declared")

    pbx = ROOT / "Molten.xcodeproj" / "project.pbxproj"
    check(pbx.exists(), "Molten.xcodeproj/project.pbxproj exists")
    if pbx.exists():
        text = pbx.read_text()
        check(f"PRODUCT_BUNDLE_IDENTIFIER = {EXPECTED_BUNDLE};" in text,
              f"bundle identifier {EXPECTED_BUNDLE} present in project")
        m = re.search(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9]+)\.([0-9]+);", text)
        if m:
            ver = (int(m.group(1)), int(m.group(2)))
            check(ver >= MIN_DEPLOYMENT, f"deployment target {ver} >= 17.0")
        else:
            check(False, "IPHONEOS_DEPLOYMENT_TARGET found in project")

    swift_files = sorted((ROOT / "Molten").rglob("*.swift"))
    check(len(swift_files) > 0, f"Swift sources present ({len(swift_files)} files)")
    for path in swift_files:
        rel = path.relative_to(ROOT)
        src = path.read_text()
        for banned in BANNED_IMPORTS:
            if re.search(rf"^\s*import\s+{re.escape(banned)}\b", src, re.M):
                check(False, f"{rel}: banned import {banned}")
        for match in re.finditer(r"https?://[^\s\"']+", src):
            url = match.group(0)
            if url.startswith("http://"):
                check(False, f"{rel}: non-https URL {url}")
        if "UIApplication.shared.open" in src:
            check(False, f"{rel}: external URL open() call (no web links allowed)")

    workflow = ROOT / ".github" / "workflows" / "apple-release.yml"
    check(workflow.exists(), ".github/workflows/apple-release.yml exists")
    if workflow.exists():
        wf = workflow.read_text()
        check("environment: app-store-release-molten" in wf,
              "workflow uses the dedicated app-store-release-molten environment")
        check("APP_BUNDLE_ID: app.molten.studio" in wf,
              "workflow signs bundle app.molten.studio")

    if failures:
        print(f"\nMOLTEN-RELEASE-CHECK: {len(failures)} FAILURE(S)")
        sys.exit(1)
    print("\nMOLTEN-RELEASE-CHECK: PASS")


if __name__ == "__main__":
    main()
