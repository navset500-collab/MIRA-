# MIRA: Setup and Demo

MIRA is a macOS hand-gesture interface built with Swift, Vision,
AVFoundation, and SwiftUI. Hand recognition runs locally. Website
actions deliberately open external services in the user's browser.

## Requirements

- macOS 14 or later
- A working camera
- Swift tools compatible with this package's Swift 6 manifest
- Full Xcode selected for running XCTest-based tests

## Build and run

From the repository root:

```bash
zsh build.sh --run
```

This builds and launches `build/MIRA.app`. Launch the app bundle,
not the bare executable.

## First run

1. Grant Camera access when prompted.
2. Complete the hand setup using the same hand and good lighting.
3. Choose actions in the dashboard.
4. Keep Actions off while practising.
5. Enable Actions when ready.

If the validation patch is installed, each capture requires the
requested gesture to be recognized. Wrong or unclear poses reset
capture progress; a capture times out after 20 seconds.

## Permissions

Open System Settings > Privacy & Security.

- Camera: needed to detect hands.
- Screen Recording / Screen & System Audio Recording:
  needed for screenshots.
- Accessibility: needed for synthetic keyboard shortcuts.
- Automation > Music: needed for controlling Apple Music.

After granting an action permission, completely quit MIRA and
reopen the same app bundle before retesting.

If access still appears unavailable, confirm the permission belongs
to the current `build/MIRA.app`, not another copy. Local rebuilding
and signing can affect permission recognition.

The build script supports an optional installed signing identity:

```bash
MIRA_SIGN_IDENTITY="YOUR INSTALLED SIGNING IDENTITY" zsh build.sh --run
```

Do not publish signing certificates or private keys.

## Controls

Website controls open Gmail, Google Docs, Google Drive,
Google Calendar, YouTube, GitHub, and ChatGPT in the default browser.
Login and internet access may be required. Browser behavior determines
whether an existing tab is reused or a new tab is created.

If the expanded-controls patch is installed:
- Keyboard controls target the frontmost app.
- Music controls target Apple Music, not every media player.
- Pause / Resume Actions works even while other actions are paused.
- Remove or relax the gesture before repeating it.

## Known limitations

- Rule-based recognition can confuse similar or poorly tracked poses.
- Calibration adjusts confidence using saved measurements; it does
  not train a new machine-learning model.
- One hand is analyzed at a time.
- A command being sent does not prove the receiving app performed it.
- Browser actions open services; they do not automate logged-in tasks.
- The screenshot implementation uses the macOS screencapture utility.
- Development builds are not a notarized public installer.

## Demo checklist

- Build before recording.
- Test the exact gestures and actions used in the video.
- Use non-sensitive browser tabs and sample content.
- Demonstrate one wrong-pose rejection during setup.
- Demonstrate two useful website actions.
- Demonstrate one screenshot only if permission is confirmed working.
- Demonstrate Pause / Resume if the expanded-controls patch is installed.
- Avoid claiming untested features or guaranteed accessibility outcomes.

## Tests

```bash
swift test
```

If XCTest cannot be found, select full Xcode in
Xcode > Settings > Locations > Command Line Tools, then retry.

## Prototype pointer and browser controls

Turn on the camera, then enable Pointer in the dashboard.
Accessibility permission is required.

- Extend the index finger to move the pointer.
- Pinch thumb and index finger briefly, then release, to click.
- Hold the pinch while moving to drag; separate fingers to release.
- Losing hand tracking releases the mouse button.
- Turning Pointer off or stopping the camera releases the mouse button.
- Pointer mode suppresses ordinary gesture-triggered actions.
- Pointer movement currently targets the primary display only.
- Sensitivity and pinch thresholds are fixed prototype settings,
  not personalized cursor calibration.

New Safari Tab and Close Safari Tab explicitly activate Safari.
Other keyboard actions use the frontmost app, or the last active
non-MIRA app when MIRA is frontmost. Open the desired target app
once if no previous target is available.

Copy, Paste, Undo, and Select All are hidden from the action menu.
If a saved binding used one of them, reassign it in the dashboard.

Test pointer control with harmless content before recording.
Closing a tab can discard content depending on the website.

## Current action menu

The current menu excludes Safari, Drive, Docs, Google Calendar,
GitHub, mute, clipboard controls, and separate tab-navigation actions.

Website open/close actions use Google Chrome and require Automation
permission. Each action tracks its own created tab during the current
MIRA session; repeating it closes that tab. Tracking resets when
MIRA restarts. If the tracked tab was already closed, the next trigger
opens a replacement.

Notes, Calendar, and Spotify open/close actions launch or request
normal application termination. Unsaved-work prompts are not bypassed.

Volume Up / Down increases volume for most gestures and decreases
it for Thumbs Down or Point Down. Assign the same action to an up
and a down gesture.

Cursor Control toggles pointer mode. Use a distinct gesture such as
Shaka, not the pointing or pinch poses used for mouse movement.
Entering cursor mode by gesture requires Actions on; leaving it
remains available. Pausing actions also stops pointer mode.

Accessibility checks do not request a warning on every gesture.
Use the Permissions menu to open Settings. MacOS can still request
Automation approval when an app is controlled for the first time.

## Current Cursor Control mode

Cursor Control is a toolbar switch, not an assignable action.

- Cursor Control and Actions cannot be enabled together.
- Open Palm moves the cursor across the primary display.
- Fist clicks once at the last cursor position.
- Hold an open palm briefly before another click.
- Holding a fist does not repeat clicks.
- Cursor mode does not implement dragging or scrolling.
- Turn Cursor Control off, then enable Actions to use gesture bindings.
- Accessibility approval is required for cursor input.

This section supersedes earlier index-finger/pinch instructions.
