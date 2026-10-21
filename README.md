# MIRA
### Motion Interface for Real-Time Access

Your hands. Your commands. Your computer.

MIRA is a native macOS application that turns hand gestures into computer controls using a camera. It combines hand tracking, geometric gesture classification, personal calibration, and configurable shortcuts with a dedicated mode for moving, clicking, and scrolling.

---

## Why MIRA?

A small interaction can interrupt an entire task.

Following a recipe with messy hands. Eating beside a laptop without wanting to touch the trackpad. Stepping away during a presentation and needing to adjust something on screen.

In each case, the intention is simple. Reaching for the computer is the inconvenient part.

MIRA explores another way to interact: show a familiar hand gesture and use it to request a command.

The goal is not to replace every keyboard or mouse interaction. It is to make common controls available when touching the computer gets in the way.

## At a glance

- 13 recognized hand gestures.
- 17 assignable actions, plus a Disabled option.
- Guided calibration for personal hand measurements.
- Separate Actions and Cursor Control modes.
- Pointer movement, single-clicking, and vertical scrolling.
- Brief feedback identifying the gesture and action result.
- Camera-based interaction without a wearable controller.
- Native macOS integration for application, window, browser, and audio controls.

## How it works

### Hand tracking and geometry

The camera provides hand-tracking input. Landmarks describe finger joints and fingertips.

MIRA derives features such as finger extension, joint geometry, fingertip contact, and direction. These features distinguish poses such as a fist, an open palm, two extended fingers, and directional pointing.

### Personal calibration

The welcome flow guides users through capturing the supported poses. These measurements form a personal hand profile. Personal templates contribute to the classifier's confidence calculation.

### Stable activation

Recognizing a pose does not immediately execute a shortcut.

A temporal stabilizer checks that the gesture remains consistent before activation. After an action triggers, the pose must be released before it can trigger again.

### Execution and feedback

MIRA routes the gesture to its configured action or reserved cursor behavior.

Floating notices identify the initiating gesture and describe the result reported by the executor. Where an operation is only requested, the notice should describe the request rather than imply another application completed it.

## The 13 gestures

Assignments are configurable in Personalization. This table describes the recognized shapes, not a universal shortcut layout.

| Gesture | How to form it |
| --- | --- |
| ✊ Fist | Curl all four fingers into a comfortable closed hand. |
| ✋ Open Palm | Extend all four fingers with the hand clearly visible. |
| 👍 Thumbs Up | Extend Thumb upward; curl the other fingers. |
| 👎 Thumbs Down | Extend Thumb downward; curl the other fingers. |
| ✌️ Peace | Extend Index and Middle; curl Ring and Little. |
| 🖖 Three Fingers | Extend Index, Middle, and Ring; curl Little. |
| ☝️ Point Up | Extend only Index and point upward. |
| 👇 Point Down | Extend only Index and point downward. |
| 👈 Point Left | Extend only Index and point left in the tracking view. |
| 👉 Point Right | Extend only Index and point right in the tracking view. |
| 👌 OK | Bring Thumb and Index fingertips together; extend Middle, Ring, and Little. |
| 🤘 Rock | Extend Index and Little; curl Middle and Ring. |
| 🤙 Shaka | Extend Thumb and Little; curl Index, Middle, and Ring. |

Keep the hand inside the camera view with the relevant fingers visible. Tracking depends on lighting, camera placement, distance, and pose clarity.

## The 17 actions

Gestures are inputs. Actions are the commands assigned to them.

The selection displayed beside each gesture in Personalization determines its shortcut in Actions mode.

### Modes

| # | Action | Behavior |
| --- | --- | --- |
| 1 | Cursor Control On/Off | Enables or disables pointer-control mode. Assign this toggle to a gesture other than Open Palm, Fist, or Peace, which have reserved cursor-mode roles. |
| 2 | Actions On/Off | Enables or pauses gesture shortcuts without requiring the camera to stop. |

### Windows and capture

| # | Action | Behavior |
| --- | --- | --- |
| 3 | Minimize Window | Requests minimization of the target application's window. Requires Accessibility permission. |
| 4 | Maximize / Restore Window | Resizes a supported target window to its display's usable area. A subsequent activation restores remembered bounds. This is distinct from macOS full-screen mode. |
| 5 | Take Screenshot | Captures the primary display and saves a PNG to the Desktop. Requires Screen Recording permission and permission to save the file. |

### Audio and Spotify

| # | Action | Behavior |
| --- | --- | --- |
| 6 | Volume Up | Requests a 10-point increase in system output volume, capped at 100. |
| 7 | Volume Down | Requests a 10-point decrease in system output volume, bounded at 0. |
| 8 | Open/Close Spotify | Opens Spotify, or requests that the running application quit. |
| 9 | Play/Pause Spotify | Sends Spotify its play/pause command. Requires Spotify desktop and Automation permission. |

Playback controls target Spotify, not Apple Music. System volume controls are independent of Spotify playback.

### Chrome

| # | Action | Behavior |
| --- | --- | --- |
| 10 | Open/Close Chrome Tab | Opens a tab managed by MIRA. Repeating the action is intended to close that tracked tab rather than an unrelated tab. |
| 11 | Open/Close Stock Market in Chrome | Opens Google Finance in a managed Chrome tab and uses the browser controller's open/close behavior. |
| 12 | Open/Close Gmail | Opens Gmail in a managed Chrome tab and uses the browser controller's open/close behavior. |
| 13 | Open/Close YouTube | Opens YouTube in a managed Chrome tab and uses the browser controller's open/close behavior. |
| 14 | Open/Close ChatGPT | Opens the ChatGPT website in a managed Chrome tab. This is a website shortcut, not an AI integration inside MIRA. |
| 15 | Open/Close Instagram | Opens Instagram in a managed Chrome tab and uses the browser controller's open/close behavior. |

Browser controls require Google Chrome and Automation permission. Website shortcuts do not sign users in or bypass authentication.

Browser open/close behavior remains under active on-device validation.

### Applications

| # | Action | Behavior |
| --- | --- | --- |
| 16 | Open/Close Notes | Opens Apple Notes, or requests that the running application quit. |
| 17 | Open/Close Calendar | Opens Apple Calendar, or requests that the running application quit. |

Application open/close controls request application launch or termination. They are not equivalent to closing a single document window. The target application may present its own confirmation.

### Disabled

Disabled is an additional dropdown option, not an eighteenth action. It removes the shortcut assignment for a gesture.

There are more actions than gesture categories, so not every action needs to be assigned at once.

## Using Actions mode

1. Open Personalization.
2. Find the desired gesture.
3. Select its action.
4. Return to the camera workspace.
5. Enable Actions.
6. Hold the gesture steadily until activation.
7. Release the pose before repeating it.

The interface rejects assigning the same non-disabled action to multiple gestures.

Assign Volume Up and Volume Down separately. Their direction is determined by the selected action, not by the gesture used.

## Using Cursor Control

Cursor Control reserves specific gestures for direct pointer interaction.

| Gesture | Cursor behavior |
| --- | --- |
| Open Palm | Move the pointer. |
| Hold Fist | Click once after first showing Open Palm. |
| Peace: Index and Middle extended, Ring and Little curled | Enter scrolling; move the hand vertically while maintaining the pose. |

### Moving

Show Open Palm and move the hand while keeping it visible.

### Clicking

Show Open Palm first, then hold Fist. Clicking is rearmed by showing Open Palm before the next Fist click.

### Scrolling

Place the pointer over scrollable content. Show the two-finger pose, hold briefly, then move the hand vertically.

Returning the hand to its scrolling origin stops scroll input. Showing Open Palm returns to pointer movement.

### Switching modes

Ordinary shortcuts are paused while Cursor Control is active. A separately assigned Cursor Control toggle can exit the mode. Shaka is one possible assignment.

Do not assign that toggle to Open Palm, Fist, or Peace: those gestures have reserved roles inside cursor mode.

This separation prevents scrolling from also opening a tab or clicking from also requesting a screenshot.

## Hover feedback

Brief notices connect an interaction with its result.

For example, feedback can identify the gesture that enabled Cursor Control, report a volume adjustment request, or explain a permission failure.

| Actions | Cursor Control | Feedback |
| --- | --- | --- |
| Off | Off | Hidden |
| On | Off | Enabled |
| Off | On | Enabled |

Individual notices use a three-second dismissal timer. New feedback may replace a notice already visible.

Notices are suppressed when both modes are off, including a notice that would otherwise appear after disabling the final active mode.

## Installation

MIRA is currently distributed as source code for a local macOS build.

### Requirements

- macOS 14 or later.
- A working camera.
- Xcode with a Swift toolchain supporting Swift 6 package manifests.
- Google Chrome for browser actions.
- Spotify desktop for Spotify actions.

Chrome and Spotify are required only for their associated controls.

### 1. Download

```bash
git clone [https://github.com/navset500-collab/MIRA-.git](https://github.com/navset500-collab/MIRA-.git)
cd MIRA-
```

Alternatively, select Code → Download ZIP on GitHub, extract the archive, and open Terminal in the extracted project directory.

### 2. Build

```bash
MIRA_SIGN_IDENTITY=- zsh build.sh
```

The build produces:

```text
build/MIRA.app
```

This requests local ad-hoc signing without an Apple Developer signing certificate. It is a development build, not a notarized public installer.

### 3. Launch

```bash
open build/MIRA.app
```

Quit an already-running copy before opening a newly rebuilt version.

### 4. Grant permissions

Enable the permissions requested by the features being used in System Settings → Privacy & Security.

| Permission | Purpose |
| --- | --- |
| Camera | Hand tracking |
| Accessibility | Pointer and window control |
| Automation → Google Chrome | Browser actions |
| Automation → Spotify | Spotify playback |
| Screen Recording | Screenshot capture |

Saving screenshots may also require Desktop-folder access.

Locally signed rebuilds can require renewed permission approval. Quit and reopen MIRA after changing permissions if a feature remains unavailable.

### 5. Set up the hand profile

1. Select Set up my hand on the welcome screen.
2. Keep the hand visible and follow the pose prompts.
3. Capture the requested gestures.
4. Select Open MIRA when the profile is complete.
5. Start the camera if it is not running.
6. Choose assignments in Personalization.
7. Enable Actions or Cursor Control.

## Screenshot output

The screenshot action uses ScreenCaptureKit to capture the primary display.

Successful captures are saved locally to the Desktop with names beginning with `MIRA-` and ending in `.png`.

The screenshot action does not upload the image.

## Development

### Build the application target

```bash
swift build --product MIRA
```

### Run the tests

With Xcode installed at its standard location:

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  /usr/bin/xcrun swift test
```

The core test suite covers:

- Supported gesture classification.
- Personal-template recognition.
- Low-confidence and ambiguous-input rejection.
- Explicit thumb direction.
- Three-finger recognition.
- Hold-duration boundaries.
- Release and retrigger behavior.
- Action-menu structure.

Core tests do not replace on-device testing of camera tracking, permissions, browser automation, screenshots, or window management.

### Repository structure

```text
Sources/
├── MIRACore/       Gesture features, classification, stabilization, and actions
└── MIRA/           Application UI, camera integration, and action execution

Tests/
└── MIRACoreTests/  Core automated tests

Support/           Application configuration
Helpers/           Tracking helper source
Scripts/           Development utilities
build.sh           Local application packaging
```

## Troubleshooting

### A gesture is recognized but no shortcut runs

Check that Actions is enabled and the gesture has an assignment.

Ordinary shortcuts are paused during Cursor Control. Hold the pose steadily, release it, and try again.

### The pointer does not move or click

Check Accessibility permission for the current build.

Show Open Palm before holding Fist. Another Open Palm is required before the next click.

### Scrolling does not start

Place the pointer over scrollable content. Extend Index and Middle, curl Ring and Little, hold briefly, then move the hand vertically.

### Chrome opens a tab but does not close it

Check Automation permission and confirm the latest rebuilt MIRA is running.

Browser tab management remains under active validation. Passing core tests does not verify Chrome automation.

### Spotify playback does not work

Confirm that Spotify desktop is installed and Automation permission is enabled.

Open/Close Spotify and Play/Pause Spotify are separate controls.

### A window does not maximize

Check Accessibility permission. Some applications and window types restrict external resizing.

Exit macOS full-screen mode before using Maximize / Restore.

### A screenshot is not saved

Check Screen Recording permission and Desktop-folder access, then quit and reopen MIRA.

Review the action result for the reported capture or saving error.

### Tests cannot import XCTest

Use the full Xcode toolchain with the test command above.

### Hover notices do not appear

Feedback is hidden when both modes are off.

Enable Actions or Cursor Control and execute a supported interaction. Notices follow action results and relevant state changes rather than every camera frame.

## Current scope and limitations

MIRA is a macOS hackathon prototype.

- Tracking depends on visibility, lighting, camera placement, and pose clarity.
- Windows and Linux support are not implemented.
- Some applications restrict external window control.
- Maximize/restore history resets when MIRA quits.
- Browser open/close behavior remains under active validation.
- Browser actions and screenshots require on-device permission and behavior checks.
- Local development builds may require renewed permissions after rebuilding.
- Gestures are an alternative input method, not a universal accessibility solution.

A screen-aware local AI assistant is a future direction, not an implemented feature of this release. Current gesture controls do not require an AI-provider API key.
