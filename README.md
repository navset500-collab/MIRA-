# MIRA

## First run: approve the required permissions

MIRA is a native macOS prototype, not a hosted website.

1. Build and launch with `zsh build.sh --run`.
2. Approve **Camera** access to detect hands.
3. For cursor control and window controls, enable this MIRA app under
   System Settings > Privacy & Security > **Accessibility**.
4. For screenshots, enable **Screen Recording / Screen & System Audio Recording**.
5. When Chrome, Spotify, or Music is controlled, approve the corresponding
   **Automation** request. Review the named app before approving.
6. Completely quit and reopen the same MIRA app after changing permissions.

Approve only permissions needed for the actions you intend to use.
No permission bypass is built into MIRA. If access appears enabled but
MIRA reports it unavailable, verify that the entry belongs to the current
`build/MIRA.app`, not an older build or another copy.

### Current prototype behavior

- Website toggles use Google Chrome.
- A website toggle closes its tracked tab, or one matching site tab if
  tracking is unavailable; otherwise it opens the site.
- Generic Chrome-tab toggles track the created tab during this MIRA session.
- Cursor control moves across the primary display, not all connected monitors.
- Pinching clicks or drags; releasing the pinch releases the mouse button.
- Maximize requests primary-display window dimensions, not fullscreen mode.
  Some applications do not permit external resizing.
- App close actions request normal termination and do not bypass unsaved-work dialogs.
- Recognition and pointer control are prototypes and can misread poor tracking.
- Only describe features as working after testing them on your machine.


**Motion Interface for Real-Time Access** is a native macOS prototype for using a few steady hand gestures as configurable computer controls.

## What works today

- AVFoundation 720p camera capture with late frames discarded and recognition work capped to keep the interface responsive.
- On-device Vision hand-pose detection using its 21 anatomical joint estimates.
- A confidence-aware hand skeleton connecting the Vision joints across the palm and five fingers, with small joint points and no decorative trails.
- Geometry-based recognition for all twelve core gestures: fist, open palm, thumbs up/down, peace, point up/down/left/right, OK, rock, and shaka.
- An explicit unknown state, confidence and class-separation thresholds, a four-frame/200 ms minimum hold, and release-to-rearm behavior.
- A guided twelve-pose setup with three 36-frame passes per pose (front, farther away, and slightly angled). It averages hand geometry and stores numeric templates locally; calibrated templates help reject rule matches that do not resemble the user's captured pose.
- Editable gesture bindings for screenshots, Music play/pause, Notes, Safari, and Calendar. Bindings persist locally, and each row has a direct action-test button.
- A live measured processing rate. It is a reading, not a performance guarantee.

Vision currently supplies at most 21 hand joints; MIRA does not fabricate extra joints. It selects the strongest plausible hand observation and fades low-confidence joints independently, but no vision system can promise zero face-like false detections. This build uses one hand at a time and does not yet include left/right-specific bindings, custom profiles, per-app context, or macros. The geometry thresholds still need testing and tuning across people, lighting, hand angles, and camera distances. Do not present gesture accuracy, latency, or false-trigger rates as measured results yet.

## Build and run

Requirements: macOS 14 or later and Swift 6.3 or later. From this directory:

```sh
swift build
zsh build.sh --run
```

The bundle is important: macOS camera permission prompts require an application with `NSCameraUsageDescription`. On first launch, click **Start hand test**, then grant camera access. Capture each of the twelve poses three times as prompted; the test is designed to take about 2–5 minutes. The dashboard opens after the full calibration set is complete. If permission was denied, use the in-app button to open Camera settings.

## Signing and Apple Developer accounts

Building and running MIRA from source does not require an Apple Developer account or account password. `build.sh` ad-hoc signs the local app. macOS may show a Gatekeeper warning when an ad-hoc-signed app is copied from another Mac; opening it may require Control-click → **Open** or approving it in Privacy & Security. A Developer ID certificate and notarization are only needed for smoother public distribution and are not needed for this local prototype. SayHi's separate build script can select an installed signing certificate, which may prompt for its Keychain password while signing; that is not an app-launch requirement.

Actions start disabled. Turn on **Actions** in the dashboard when you are ready. Use the play button beside a gesture to test its selected action independently. App launching needs no Accessibility permission; screenshots require Screen Recording permission, and Music control requires Automation permission for Music. MIRA reports action failures in the dashboard.

## Privacy

Frames pass from AVFoundation to Vision in memory and are not written to disk or sent over a network. The screenshot action is separate and only runs after a recognized gesture has remained stable and the user has assigned that action.

## Recognition approach

Gesture recognition follows an ordered, geometric rule system. Finger extension is measured as the fingertip's distance beyond its PIP joint, relative to wrist-to-middle-knuckle hand scale. Thumb spread/rise, fingertip pinch, and index-finger direction distinguish the remaining gestures. This makes the thresholds largely independent of camera distance. Calibration templates add a user-specific similarity check; weak matches remain unknown. A stable gesture fires once and must leave the frame before it can fire again.

## ImpactHack submission

See [SUBMISSION.md](SUBMISSION.md) for the project description, problem, technical explanation, and screenshot checklist. See [DEMO_SCRIPT.md](DEMO_SCRIPT.md) for the required 2–4 minute product-first video plan.

Automated unit tests are in `Tests/MIRACoreTests`. Running `swift test` requires a full Xcode installation with XCTest; this machine currently has Command Line Tools only, so that test runner is not available here. The dependency-free recognition smoke check can be run with `swiftc -o /tmp/MIRA-GestureSmoke Sources/MIRACore/GestureRecognition.swift Scripts/gesture-smoke/main.swift && /tmp/MIRA-GestureSmoke`. Live camera behavior, trigger reliability, and action permissions must still be rehearsed on the submission Mac.

## Setup, permissions, and demo

See [Setup and Demo](SETUP_AND_DEMO.md) for build instructions,
required macOS privacy approvals, troubleshooting, and limitations.
