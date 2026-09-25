# Minder

Turns your phone into a pair of eyes that watch you work: a body-doubling focus timer for iPhone.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Swift%205-orange) ![Built on GitHub Actions](https://img.shields.io/badge/built%20on-GitHub%20Actions%20macOS-2088FF)

**Coming to the App Store.**

<p align="center">
  <img src="fastlane/screenshots/en-US/01_iPhone.png" width="250" alt="Minder screenshot">
  <img src="fastlane/screenshots/en-US/02_iPhone.png" width="250" alt="Minder screenshot">
  <img src="fastlane/screenshots/en-US/03_iPhone.png" width="250" alt="Minder screenshot">
</p>

Body doubling helps people with ADHD, and anyone who works better when someone is watching. Minder has no lists, no feeds and no streak guilt: prop the phone up, slide to focus, and two expressive eyes keep you company and get suspicious if you pick the phone up mid-session.

## Features

- Eyes that blink, look around and react with a dozen expressions: attentive, focused, happy, proud, curious, suspicious, stern, sleepy
- Notices when the phone is picked up or moved during a session (Core Motion)
- Optional face following with the front camera (Vision face rectangles, about ten reads a second, frames dropped immediately)
- Check-ins every 15, 25, 45 or 60 minutes with a proud look and a gentle buzz
- An eye designer: iris colours or odd eyes, eye and pupil shapes, brows, whites, size, spacing, glow, lashes, presets
- Keeps the screen awake; tracks focus minutes per day, the week at a glance and a streak

## Price

A paid app: one price, no in-app purchases, no subscription, no ads.

## Privacy

No network code at all: Minder makes no requests and collects no data. The camera is optional; frames are read on the device and discarded, never recorded or saved. Settings and focus minutes live in `UserDefaults`. The privacy manifest (`Resources/PrivacyInfo.xcprivacy`) declares no tracking and no collected data types.

## Built without a Mac

This app was written on a Windows PC. No Mac is involved at any point: every build, signature, screenshot and App Store submission runs on GitHub Actions macOS runners, driven by the App Store Connect API.

- **`project.yml`** is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated on the runner and never committed, so the repo can be edited on any OS and there are no `.pbxproj` merge conflicts.
- **`.github/workflows/build.yml`** runs on every push: picks the newest Xcode 26 and iPhone simulator on the runner, builds, then launches the app once per screen with `-shot <screen>` (sample data, fixed 9:41 status bar) and captures the store screenshots with `simctl`, uploaded as a workflow artifact.
- **`.github/workflows/appstore.yml`** (manual) has three modes: `compile`, `dry_run` (build, sign, upload, do not submit) and `release` (also submits for review). The distribution certificate is imported from a secret into a throwaway keychain; [fastlane](https://fastlane.tools) (`fastlane/Fastfile`) fetches the App Store profile with the API key, sets the build number one above the latest on TestFlight, archives, and uploads the binary with `fastlane/metadata` and the committed `fastlane/screenshots`.
- **`.github/workflows/review-video.yml`** records the App Review screen recording: the app is launched with `-demoAutoplay` and drives its own real screens.
- **`Store/*.py`** talk to the App Store Connect API directly from Windows (Python, `requests` + `PyJWT`): `asc.py` registers the bundle id and pushes metadata, `listing.py` sets the age rating, review details, price and screenshots, and `signing.py` creates the distribution certificate locally so its private key is never stranded on a disposable runner.

Only one step is manual: Apple's API will not create the app record itself, so that is made once in the App Store Connect web UI.

## Build and run

With a Mac and Xcode 26 (the version CI uses; the app targets iOS 17+):

```bash
brew install xcodegen
xcodegen generate
open Minder.xcodeproj
```

Run the `Minder` scheme on any iPhone simulator. No signing is needed for the simulator; from the command line:

```bash
xcodebuild build -project Minder.xcodeproj -scheme Minder \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

To see it filled with sample data, launch with a screenshot argument, e.g. `xcrun simctl launch booted com.mattbusel.minder -shot work`.

Without a Mac: fork the repo and push. The Build workflow compiles it on a GitHub macOS runner and attaches the screenshots as an artifact.

Shipping your own build needs these repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (base64 of the `.p8`), `DEVELOPMENT_TEAM`, `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, plus your own bundle id in `project.yml` and `fastlane/Fastfile`.

## Code map

All app code is in `Sources/` (SwiftUI, Observation, no third-party dependencies).

| File | What it does |
| --- | --- |
| `MinderApp.swift` | entry point, focus-minute tracking |
| `RootView.swift` | the main screen, `-shot` handling and the App Review autoplay |
| `Brain.swift` | decides what the eyes feel and where they look, frame by frame |
| `EyesView.swift` | draws the eyes |
| `Face.swift` | the shape of one eye and its brow |
| `Look.swift` | every appearance setting, persisted key by key |
| `EyeDesigner.swift` | the customisation panel with live preview and presets |
| `Sensors.swift` | front camera face tracking (Vision) and motion (Core Motion) |
| `Controls.swift` | slide to start, slide back to stop |

`Store/` holds the App Store Connect scripts, `fastlane/` the lanes, listing text and screenshots, `Resources/` the asset catalog and privacy manifest.

---

**More apps built the same way:** [Chain](https://github.com/Mattbusel/chain), [Ironbook](https://github.com/Mattbusel/ironbook), [Quiver](https://github.com/Mattbusel/quiver), [Race Fuel](https://github.com/Mattbusel/race-fuel), [Baseline Ledger](https://github.com/Mattbusel/baseline-ledger), [Fairway Ledger](https://github.com/Mattbusel/fairway-ledger), [Odometer](https://github.com/Mattbusel/odometer), [Rooms](https://github.com/Mattbusel/rooms), [Clockout](https://github.com/Mattbusel/clockout), [Curve](https://github.com/Mattbusel/curve), [Pricebook](https://github.com/Mattbusel/pricebook), [Chores](https://github.com/Mattbusel/chores), [Pawprint](https://github.com/Mattbusel/pawprint), [Pocket Beings](https://github.com/Mattbusel/pocket-beings), [Glyphstorm](https://github.com/Mattbusel/glyphstorm), [Clear the Strait](https://github.com/Mattbusel/clear-the-strait).


## Hire the author

I designed, built and shipped this app myself. **Want one like it for your business?** I build native iOS apps from prototype to App Store launch, fixed price. [Services and pricing](https://mattbusel.github.io/) · [Email](mailto:mattbusel@gmail.com) · [LinkedIn](https://www.linkedin.com/in/matthewbusel/)
