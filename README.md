<div align="center">

# MIRA

### Your hands. Another way to control your Mac.

A camera-based gesture-control prototype for shortcuts, cursor movement,
clicking, and scrolling—without reaching for the trackpad.

Built for Next Byte Hacks V5.

[Get started](#get-started) · [Using MIRA](#using-mira) ·
[Troubleshooting](#troubleshooting) · [Project status](#project-status)

</div>

---

## Why MIRA?

Sometimes the keyboard and trackpad are the interruption.

You might be following a recipe with messy hands, eating beside your laptop,
or stepping away during a presentation. You know what you want the computer
to do; touching it just is not convenient.

MIRA explores another option: use a visible hand gesture to request an action.

It is not a replacement for every keyboard or mouse interaction. It is a
prototype for the moments when another input method helps.

## What it does

- Recognizes hand gestures from a camera feed.
- Provides a calibration flow for capturing personal gesture examples.
- Lets you assign shortcuts to gestures.
- Offers a separate Cursor Control mode for movement, clicking, and scrolling.
- Displays brief feedback describing the gesture and the action result.

### Actions and shortcuts

The action menu includes:

| Category | Controls |
| --- | --- |
| Modes | Cursor Control On/Off; Actions On/Off |
| Windows | Minimize; Maximize / Restore |
| Capture | Take Screenshot |
| Audio | Volume Up; Volume Down |
| Spotify | Open/Close Spotify; Play/Pause Spotify |
| Chrome | Open/Close Chrome Tab; Stock Market; Gmail; YouTube; ChatGPT; Instagram |
| Applications | Open/Close Notes; Open/Close Calendar |

There are 17 selectable actions plus a Disabled option.

Chrome controls require Google Chrome. Spotify controls require the Spotify
desktop app. Browser actions manage their own tracked tabs; they are not
intended to close arbitrary tabs you opened yourself.

## Get started

### Requirements

- A Mac running macOS 14 or later.
- A working camera.
- Xcode with its command-line tools configured for Swift development.
- Google Chrome and Spotify only if you want their associated actions.

This repository is currently a source-build prototype, not a one-click
installer. Review `build.sh` for the build and packaging steps used by this
version.

### 1. Download the project

On this repository's GitHub page:

1. Select **Code**.
2. Select **Download ZIP**.
3. Extract the ZIP.
4. Open Terminal and type `cd `, including the space.
5. Drag the extracted project folder into Terminal and press Return.

Alternatively, clone this repository and enter its project directory.

### 2. Run the tests

With Xcode installed at its usual location:

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  /usr/bin/xcrun swift test
```

These tests cover core recognition, timing behavior, and action-menu structure.
They do not replace live testing of the camera, Chrome automation, screenshots,
or window management.

### 3. Build MIRA

From the project directory:

```bash
MIRA_SIGN_IDENTITY=- zsh build.sh
```

This requests a local ad-hoc build without an Apple Developer signing
certificate. It is not a notarized distribution build.

### 4. Open the app

```bash
open build/MIRA.app
```

If MIRA was already running during the build, quit it completely before
opening the rebuilt app.

### 5. Allow the required permissions

In **System Settings → Privacy & Security**, enable the permissions requested
by the features you use:

| Permission | Purpose |
| --- | --- |
| Camera | Hand tracking |
| Accessibility | Cursor and window control |
| Automation → Google Chrome | Browser tab actions |
| Automation → Spotify | Spotify playback |
| Screen Recording | Screenshots |

Screenshot saving may also require Desktop-folder access.

macOS can require permission approval again after a locally signed rebuild.
If permission changes do not take effect, quit and reopen MIRA.

### 6. Calibrate and start

1. Follow the welcome screen into calibration.
2. Keep your hand visible and follow the requested poses.
3. Start the camera if it is not already running.
4. Open Personalization to choose gesture assignments.
5. Enable either Actions or Cursor Control.

## Using MIRA

### Actions mode

Assign an action to a gesture, then hold the pose steadily.

After an action triggers, release the pose before repeating it. Holding a pose
continuously is not intended to repeatedly execute the same shortcut.

Assign Volume Up and Volume Down separately.

### Cursor Control mode

| Gesture | Behavior |
| --- | --- |
| Open Palm | Move the pointer |
| Hold Fist | Click once after first showing Open Palm |
| Index + Middle extended; Ring + Little curled | Enter scrolling; move the hand vertically to scroll |

Show Open Palm again to return to pointer movement and rearm clicking.

Choose a separate gesture, such as Shaka, for the Cursor Control toggle.
Do not assign the toggle to Open Palm, Fist, or the two-finger scrolling pose.

Ordinary shortcut actions are paused while Cursor Control is active.

### Hover feedback

Feedback names the initiating gesture and describes the action result.

Notices are enabled when Actions or Cursor Control is on. They are hidden
when both modes are off, and individual notices use a three-second timer.

A result such as “request sent” is not the same as confirming that another
application completed the requested operation.

## How it works

MIRA's gesture classifier uses hand features such as finger extension,
joint geometry, and direction.

A temporal stabilizer checks that a pose is held consistently before it can
trigger an action. Release-and-rearm behavior helps prevent a held pose from
executing the same action continuously.

The project separates shared recognition logic from macOS application code:

```text
Sources/
├── MIRACore/   Gesture features, classification, stabilization, action definitions
└── MIRA/       Camera interface, application UI, cursor control, action execution

Tests/
└── MIRACoreTests/   Core recognition and action-menu tests
```

## Troubleshooting

### The camera recognizes my gesture, but nothing happens

Check that Actions is enabled. In Cursor Control mode, ordinary shortcut
actions are intentionally paused.

Hold the gesture steadily, release it, then try again.

### Cursor control does not move or click

Check Accessibility permission for the current MIRA build.

For clicking, first show Open Palm, then hold Fist. Another Open Palm is
required before the next click.

### Scrolling does not start

Extend index and middle, curl ring and little, and hold briefly. Then move
your hand vertically while keeping the pose.

Place the pointer over a scrollable area first.

### Chrome opens a tab but does not close it

Check Automation permission and confirm the latest rebuilt MIRA is running.

The tab toggle must be tested in the installed build. A passing core test suite
does not verify Chrome's AppleScript behavior.

### Screenshots do not save

Enable Screen Recording permission, quit MIRA, and reopen it.

Check the action result and Desktop-folder access. A successful capture saves
a PNG named `MIRA-…png` to the Desktop.

### Tests cannot find XCTest

Use the full Xcode toolchain shown in the test command above. A standalone
command-line-tools configuration may not provide the required test framework.

## Project status

MIRA is a macOS hackathon prototype.

Core automated tests have passed during development. Live camera behavior,
permissions, application automation, and window compatibility require
on-device verification.

Known limitations:

- macOS only; Windows and Linux support are not implemented.
- Hand visibility, lighting, and camera placement affect tracking.
- Some windows do not support external resizing.
- Maximize/restore history is held in memory.
- Locally signed builds may require renewed permissions.
- Browser open/close behavior remains under active validation.
- A local screen-aware AI assistant is planned, not implemented.

MIRA does not require an AI-provider API key for its current gesture controls.

## Development

```bash
swift build --product MIRA
```

Run the core tests before proposing changes. For changes to cursor control,
browser actions, screenshots, or permissions, also include a manual test
description.

## Before a demo

- Test the exact app build you will present.
- Confirm permissions before recording.
- Prepare a scrollable page and safe click target.
- Check both volume directions.
- Verify browser and screenshot actions before including them in the demo.
- Close duplicate test tabs.
- Describe only features that work in the demonstrated build.

---

Built by Navraj for Next Byte Hacks V5.
