# MIRA
Motion Interface for Real-Time Access

MIRA is a native macOS prototype that turns hand gestures into
configurable computer controls. It uses Apple's Vision framework
to recognize hand poses from the camera.

## Features

- Configurable gesture-to-action bindings
- Hand setup using captured pose measurements
- Open/close controls for supported applications and Chrome websites
- Spotify playback controls
- Screenshot and volume controls
- Window minimize/maximize requests
- Cursor Control: open palm moves; fist clicks
- Separate Cursor Control and Actions modes

Features depend on recognition quality, permissions, and the
target application's support.

## Requirements

- macOS 14 or later
- A Mac with a camera
- Swift tools supporting a Swift 6 package manifest
- Google Chrome for website/tab controls
- Spotify's desktop app for Spotify controls

## Build and run

From the repository folder:

```bash
MIRA_SIGN_IDENTITY=- zsh build.sh --run
```

This creates and launches `build/MIRA.app`.

The command above uses local ad-hoc signing. For an installed
development signing identity, provide its name or fingerprint:

```bash
MIRA_SIGN_IDENTITY="YOUR INSTALLED SIGNING IDENTITY" zsh build.sh --run
```

Launch the app bundle, not the bare executable. Development builds
are not notarized public installers.

## First run and permissions

1. Approve Camera access and complete hand setup.
2. Assign your preferred controls in the dashboard.
3. Enable Actions to run assigned gestures, or enable Cursor Control
   for mouse movement and clicking. Only one mode runs at a time.

Approve only the permissions needed for your selected features:

| Permission | Used for |
| --- | --- |
| Camera | Hand tracking |
| Accessibility | Cursor input and window controls |
| Screen Recording / Screen & System Audio Recording | Screenshots |
| Automation: Google Chrome | Website and tab controls |
| Automation: Spotify or Music | Playback controls |

Find these under System Settings > Privacy & Security.
macOS may request system authentication when changing permissions.
MIRA itself has no account or password requirement.

After changing permissions, completely quit and reopen the same
MIRA app. If permission appears enabled but the app reports it
unavailable, confirm the entry belongs to the current build.
Rebuilding or changing signing can require reauthorization.

## Using Cursor Control

- Start the camera and enable Cursor Control.
- Show an open palm to move the cursor.
- Close your hand into a fist briefly to click once.
- Show an open palm before the next click.
- Turn Cursor Control off before enabling assigned Actions.

Cursor Control currently targets the primary display and does not
implement scrolling or dragging.

## Open/close behavior

App toggles launch an application or request a normal quit.
Unsaved-work prompts are not bypassed.

Website toggles use Chrome. They close their tracked tab, or one
matching site tab when tracking is unavailable; otherwise they open
the site. Tab tracking is session-local.

Relax or remove your hand between repeated action gestures.

## Privacy

Hand recognition runs locally. The camera pipeline processes
frames without saving camera video. Website actions intentionally
open external services in Chrome; those services have their own
privacy policies.

## Limitations

MIRA is a prototype. Rule-based recognition can confuse similar
poses or poor lighting. Calibration adjusts confidence using saved
measurements; it does not train a new machine-learning model.

One hand is analyzed at a time. Bindings are shared between hands.
Some apps do not support external window resizing, and sending a
command does not guarantee the target app performs it.

## Tests

```bash
swift test
```

XCTest-based tests require a suitable Xcode toolchain. If XCTest
cannot be found, select full Xcode under
Xcode > Settings > Locations > Command Line Tools.

