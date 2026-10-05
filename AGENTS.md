# PoseLock

iOS app (Swift / SwiftUI) that scores bodybuilding poses live on-device and lets the user "lock" a photo when the score is high enough. GitHub remote: `https://github.com/Spocsk/PoseLock`.

- Xcode project: `PoseLock.xcodeproj` — targets `PoseLock` and `PoseLockTests`, single scheme `PoseLock`.
- iOS 17.0 minimum, Swift 5, bundle id `com.spocsk.PoseLock`.

## Project layout

```
PoseLock/
├── App/         RootView (TabView Accueil / Journal / Réglages + covers/sheets),
│                AppSession (@Observable navigation state)
├── Design/      Theme (colors, fonts, corners, distanceCueFont for live camera cues),
│                PoseLockHaptics, ShareMark (signature stamped on exported images),
│                PoseReferenceImage (low-poly pose references from local assets)
├── Domain/      Pack, Pose, BodyFrame, PoseTemplate, ScoringEngine, DailyPoseSelector, LockQuota,
│                CompetitionDeadline
├── Data/        Models.swift (SwiftData: AppSettings, LockEntry), PhotoStore
├── Camera/      CaptureSessionController, PoseDetector (Vision), CameraViewModel, CameraHUD,
│                CameraSessionView, PoseCoachView
├── Onboarding/  OnboardingFlow (steps + goal/pack/pain/proof/camera/recap screens),
│                OnboardingSplashView, OnboardingPersonalizationView,
│                OnboardingPaywallView, OnboardingAccountView
├── Home/        HomeView, ScoreTrendView
├── Journal/     JournalView, PoseComparisonSkeleton, PoseRecapView, SocialShare
├── Settings/    SettingsView, PrivacyView, FeedbackSheet, FeedbackMail, ShakeDetector
└── Store/       RevenueCatConfig (identifiers + SDK key), StoreManager (RevenueCat + PlanOffer),
                 PaywallComponents (shared paywall UI), PaywallSheet, TrialReminder,
                 CompetitionReminder, Products.storekit
```

Cloud environment config lives in `.cursor/` (`Dockerfile`, `environment.json`).

The only third-party dependency is `RevenueCat` from
`https://github.com/RevenueCat/purchases-ios`, pinned to 5.88.0 via SPM.
`RevenueCatUI` was removed on purpose — see the paywall invariant.

## Build and test

```bash
xcodebuild -scheme PoseLock -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme PoseLock -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Tests need a concrete simulator. Run `xcodebuild -scheme PoseLock -showdestinations` if the named device does not exist locally.

Pose scoring is pure and unit-tested in `PoseLockTests/ScoringEngineTests.swift`. Prefer putting new domain logic in `Domain/` so it stays testable without a simulator.

## Adding a Swift file — read this first

The project uses **explicit `PBXFileReference` groups**, not `PBXFileSystemSynchronizedRootGroup`. Creating a `.swift` file on disk is not enough: it will not compile until it is registered in `PoseLock.xcodeproj/project.pbxproj` with all four of

1. a `PBXFileReference` entry,
2. a `PBXBuildFile` entry,
3. a child entry in the owning `PBXGroup`,
4. an entry in the target's `Sources` build phase.

Use fresh 24-character uppercase hex object IDs that do not already appear in the file.

## Conventions

- **UI strings are written in French and localized through String Catalogs** — FR (source), EN, ES, DE, PT-BR. `Localizable.xcstrings` holds the UI, `InfoPlist.xcstrings` the permission texts and the quick action, `Cues.xcstrings` the pose cues. Write the French in code, match the terse voice ("Pose. Score. Lock.", "Travailler", "3 locks aujourd'hui"), and add the four translations to the catalog in the same change. `Text("…")`, `Button("…")` and other `LocalizedStringKey` literals are extracted on their own; a literal that travels as a `String` (enum `displayName`, `PaywallCopy`, notification bodies, helper-view parameters) must be wrapped in `String(localized:)`, otherwise it ships in French everywhere. Counts go through plural variants (`"\(n) jours"`), never `n > 1 ? "s" : ""`. Dates use the default locale. Paywall copy included — it is in `PaywallCopy`, not in the dashboard.
- **The catalogs' source language is `fr` (project `developmentRegion = fr`), but the app target sets `DEVELOPMENT_LANGUAGE = en`**, so `CFBundleDevelopmentRegion` is `en` — what an Italian or Japanese user falls back to. Do not flip the project region to `en`: `xcodebuild -exportLocalizations` then refuses catalogs whose source is `fr`. Because of that, every key also carries an explicit `fr` value: without a compiled `fr.lproj` table, iOS would serve English to French users. Tests run in `fr` (scheme TestAction) so French assertions hold; `LocalizationCatalogTests` fails on a missing key, a dropped format specifier or an untranslated cue.
- **Pose cues stay French data in `Domain/`** — `SideWording` mirrors them word by word and the tests read them. They are translated only at display time with `CueText.localized`, a dynamic lookup in `Cues.xcstrings`. A new or reworded cue needs its entry, and its mirrored variant's, in that catalog.
- **Styling goes through `Theme`.** Near-black background, ivory text, a single gold accent, plus `lockGreen` / `frameRed` for pose state. Do not introduce new raw colors or font sizes. The type scale is `title` 22 / `body` 15 / `support` 13 / `caption` 11: supporting prose the user has to read takes `supportFont`, and `captionFont` is reserved for micro-labels — badges, units, legal fineprint. Live camera cues are the other exception besides `scoreFont`: `distanceCueFont` (28 pt semibold) so the line is readable from 2–3 m.
- **State**: `@Observable` classes (`AppSession`, `StoreManager`) injected via `.environment`, SwiftData `@Model` for persistence, `@Query` to read it.
- **Haptics** always go through `PoseLockHaptics` and respect `settings.hapticsEnabled`.
- Tuning values (lock threshold, hold duration, free daily quota, template version) belong in `ScoringConstants`, not inline.

## Invariants

- **Session video never leaves the device.** Vision runs on-device and photos are written to app-local storage by `PhotoStore`. There is no application server. RevenueCat receives purchase history only. The owner approved optional analytics in September 2026 and moved them from Mixpanel to TelemetryDeck (EU, namespace `fr.dylan-cdo`) in October 2026: the allowlisted events in `PoseLockAnalytics` are sent only after consent and when `Info.plist` → `TelemetryDeckAppID` holds a UUID, never an image, video, pose, score, goal or Apple user ID. `clientUser` is the SHA-256 of a random local ID, DEBUG signals carry `isTestMode`. The adapter posts to TelemetryDeck's Ingest API v2 directly (`https://nom.telemetrydeck.com/v2/`, the SwiftSDK default; the namespace is only for queries), without the SwiftSDK or an offline queue, to keep consent withdrawal immediate. It mirrors the SDK's `TelemetryDeck.Session.started` / `Acquisition.newInstallDetected` signals and its app, device, OS and language parameters so the default dashboards fill in. A user-initiated signalement (shake or Réglages → « Un problème ? ») opens Mail.app to `apps@dylan-cdo.fr` with the typed text and the app/iOS versions — never a photo, a frame, a pose or a score. `PrivacyInfo.xcprivacy` reflects purchase history and optional product interactions/usage, not linked to identity, not used for tracking. Do not add further networking, analytics SDKs or crash reporters without the owner explicitly asking.
- **Free tier**: `ScoringConstants.freeLocksPerDay` locks per day and only the pack chosen during onboarding (`Pack.onboardingCases` : Scène, Contenu, Physique). Pro unlocks the quota, those three packs, the 30-day comparison, the deadline reminders, and the Zyzz catalogue — five benefits, and `ProBenefit` must list exactly what Pro still buys. Gating lives in `LockQuota` and `AppSession.requestPackChange`. `Pack.zyzz` is never in `onboardingCases` and is never left as the free pack after an expiry (RootView falls back to the onboarding pack). Since the onboarding paywall is hard, the free tier is the fallback for a subscriber who cancels, not an entry path.
- **Zyzz is a pose name, not a partnership.** The fourth catalogue is Pro-only. UI says « Zyzz », gym vernacular like « front double biceps ». No photo of Aziz Shavershian, no bio, no « officiel ». App Store 5.2.1 : do not suggest affiliation. Vision cannot score an abdominal vacuum ; the cue stays in the coach copy. Static pose previews use the bundled anonymous low-poly references through `PoseReferenceImage`, with plain and guided variants. The live camera overlay stays a stickman: a filled body on jittery Vision joints vibrates.
- **RevenueCat owns the catalogue, not the UI.** Project `PoseLock` (`proj5d61078f`), entitlement `pro`, offering `default`, packages `$rc_monthly` / `$rc_annual`, products `poselock.pro.monthly` (P1M) and `poselock.pro.yearly` (P1Y). Prices and trial change from the dashboard without a build. The identifiers live in `RevenueCatConfig` — a typo in `proEntitlement` compiles fine and locks everyone out.
- **`isPro` reads the entitlement, never a product or a receipt.** `customerInfo.entitlements["pro"]?.isActive` is the only source of truth; expired subscriptions stay in `all` but drop out of `active`. `StoreManager` subscribes to `customerInfoStream`, so a purchase, restore, renewal or expiry propagates without the UI asking.
- **The paywall is native SwiftUI, and deliberately so.** `RevenueCatUI`'s `PaywallView` was tried and dropped: since 5.81.3 ("Avoid decoding legacy paywall components for workflows") the SDK only decodes an offering-attached paywall when remote config is off, which it never is outside custom entitlement computation. With no workflow attached to the offering the components are pruned before they reach the app, and `PaywallView` falls back to its red "No Paywall configured" screen. Re-adding `RevenueCatUI` means re-hitting that. The dashboard's paywall dialect also cannot express two `Theme` traits (letter-spacing on durations, the 1.5 px selected border).
- **Nothing about the offer is hardcoded, paywall in SwiftUI or not.** `PlanOffer` derives period, price, monthly equivalent, discount and trial from the RevenueCat `StoreProduct`; `PaywallCopy` builds every sentence from it. When `introductoryDiscount` is absent — the Test Store case — the copy must and does drop every mention of a trial and hide `TrialTimeline`. Never write a price, a duration or a percentage in the UI. App Store free trials only exist in 3 days, 1 or 2 weeks, 1/2/3/6 months and 1 year.
- **Debug runs on the RevenueCat Test Store**, key `test_…` in `RevenueCatConfig`, so prices show up in the simulator with nothing attached to the scheme — that is why the scheme no longer references `Products.storekit`. Test Store purchases open a dialog where the outcome is picked by hand, renew on a compressed clock, and **cannot express a free trial** (the API has no field for it; it is a dashboard-only toggle). Release reads an `appl_…` key from `Info.plist` → `RCPublicAPIKey`, empty until a paid team exists, which makes `RevenueCatConfig.isConfigured` false and sends the paywall to its fallback instead of showing an empty screen.
- `Store/Products.storekit` is now only the description of what to create in App Store Connect later; nothing reads it at runtime. `StoreConfigurationTests` checks it still carries the same identifiers as `ProProductID` and the same one-week trial.
- **Onboarding is a funnel that ends on a hard paywall**: splash, goal, pack, pain, proof, camera, recap, personalization, paywall, account. The order sells the result before asking for anything — question, reformulate the problem (`OnboardingPainView`, copy per `TrainingGoal`), show the outcome (`OnboardingProofView`), and only then request the camera. Each choice gets an `OnboardingAcknowledgement` naming what the app retained; the pain step ends on a micro-commitment where **both answers advance**, since it exists to be recognised, not to filter. `OnboardingStep.tracked` drives the progress bar and must list every step that shows chrome. The only way out of the paywall is a purchase, except when the offering fails to load — `onUnavailable` exists solely for that case.
- **No invented social proof.** The app has no users and no reviews yet, so the trust signals in `OnboardingPersonalizationView` are only things that are verifiably true of the build: on-device Vision, session video never leaving the iPhone, no account required. Never add a rating, a user count or a testimonial that does not exist — App Store rule 2.3.1, and it would be a lie. The two scores on the proof screen are labelled "Exemple" for the same reason. The account step (Sign in with Apple, no Google, no backend) stays skippable, per App Store rule 5.1.1. **The `com.apple.developer.applesignin` entitlement is deliberately absent**: a personal team cannot sign it and the build fails before launching. Re-add it from Signing & Capabilities once a paid team is in place — until then the Apple button reports "Connexion Apple indisponible" and "Plus tard" carries the step.
- **The trial reminder is a local notification** scheduled by `TrialReminder` at the end of the onboarding, 24 h before `StoreManager.renewalDate`. Apple sends no reliable reminder of its own, so any copy promising one depends on this.
- **Deadline reminders are local too**, scheduled by `CompetitionReminder` (J-7 / J-3 / J-1 at 09:00) when a Pro user enables the toggle in Réglages. Permission is requested there, never at launch. Identifiers are distinct from the trial reminder. Copy names the weakest pose of the active pack from the journal — never an invented score. Expiry of Pro cancels pending requests.
- **Default camera is the Settings picker**, not last-used. `CameraSessionView` starts with `settings.cameraFront` and must not write `isFront` back on dismiss.
- **Every image that leaves the app is signed, Pro included.** `ShareMark` is the single definition of that signature — bottom-trailing corner, gold, sized on the short side — and it is applied in exactly two places: the two share cards via `ShareMarkLabel`, and the copy handed to Photos via `ShareMark.stamped`. The file `PhotoStore` keeps stays clean, because the journal reads it and the cards render from it, so stamping it would show a mark in the app and double it on export. The UIKit path adds a dark outline the SwiftUI one does not need: a card corner is always the near-black background, a photo corner can be a white gym wall. The point is organic reach, so **there is no unbranded tier** — the old `ProBenefit.share` promised "la carte score sans mention PoseLock" and was removed rather than left as a lie. Share sheets offer Story Instagram (`instagram-stories://` + pasteboard background), TikTok (system share sheet), and Autre (`ShareLink`). No Meta or TikTok SDK. `LSApplicationQueriesSchemes` lists `instagram-stories`, `instagram`, `tiktok` so `canOpenURL` is honest.
- **The forced lock is debug-only and its score is stamped, not measured.** `CameraViewModel.debugForceLock` exists so the lock → journal path can be walked without holding a pose. `DebugDemoPose` (photo de démo, tête floutée) is a front double biceps, so its Vision reading is injected only when the selected pose is `DebugDemoPose.poseID` or a ScreenBank demo is running; every other pose gets `BodyFrame.preview(for:)` on a plain backdrop, otherwise the journal would file a double biceps photo under « back lat spread ». The evaluation is overridden to `lockScore + 8` and `lockNow` gets that image — without one `persistLock` gives up and nothing reaches the journal. The number is stamped, not measured: `testEveryPoseTargetLocksAgainstItsOwnTemplate` keeps every target figure above the threshold, but a forced lock must not depend on it, so journal entries created this way carry a real skeleton and a fabricated number. After a forced lock the lock card shows the overlay (photo + skeleton). **An ordinary DEBUG run keeps the real camera**: the demo photo replaces the capture session only under `-ScreenBankScene` / `-VideoDemoMode` (`ScreenBank.usesDemoCamera`). `DevForceLockButton` appears in the HUD and in the camera-denied screen, both behind `#if DEBUG`, so nothing ships. Never lift this into a release path.

## Cursor Cloud specific instructions

Cloud agents run on Ubuntu. They can edit this repository, commit, and open pull requests. They cannot run Xcode, the iOS Simulator, or UIKit/SwiftUI binaries.

When working in the cloud:

- Write and refactor Swift / SwiftUI as usual, including `project.pbxproj` edits.
- Do not try to `xcodebuild`, `xcrun`, `simctl`, or open `.xcodeproj`.
- Prefer small, reviewable diffs and describe how a human would verify on a Mac with Xcode 15+.
- Keep secrets out of the repo. Use Cursor Secrets if credentials are needed later.
- The `install` command in `.cursor/environment.json` is a smoke check only. There is no package install step yet.
