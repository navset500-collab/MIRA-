# MIRA
### Motion Interface for Real-Time Access

MIRA is a native macOS prototype that uses camera-based hand tracking
to control everyday tasks through configurable gestures.

## For judges

- Source code: this repository.
- Supported platform: macOS 14 or later.
- Windows/Linux: not supported by the current implementation.
- No MIRA account or paid Apple Developer membership is required
  for the default local build.
- Review the demonstration video if you do not have a compatible Mac.
- This is a development prototype, not a notarized public installer.

## What it does

- Configurable gesture-to-action bindings
- Hand-setup measurements
- Supported application and Chrome website open/close controls
- Spotify playback controls
- Screenshot and volume controls
- Window minimize/maximize requests
- Cursor Control: open palm moves, fist clicks once

Operation depends on tracking quality, permissions, and target-app support.

## Requirements

- macOS 14 or later and a camera
- Swift tools compatible with a Swift 6 package manifest
- Git
- Google Chrome for website/tab actions
- Spotify desktop app for Spotify actions

## Install and launch

### 1. Install the tools if needed

Open Terminal and run:

```bash
xcode-select --install
```

Follow the system installer. If the tools are already installed,
you do not need to reinstall them.

Check the Swift version:

```bash
swift --version
```

This package requires tools supporting a Swift 6 manifest.
If your tools are older, update Xcode or the Command Line Tools.

### 2. Download and build MIRA

```bash
git clone [https://github.com/navset500-collab/MIRA-.git](https://github.com/navset500-collab/MIRA-.git)
cd MIRA-
zsh build.sh --run
```

The script builds and launches `build/MIRA.app`.

The default build uses ad-hoc signing, not a personal development
certificate. It does not request access to a developer signing key.

If your Terminal already has MIRA_SIGN_IDENTITY set and you want
the default certificate-free build, run:

```bash
MIRA_SIGN_IDENTITY=- zsh build.sh --run
```

### 3. Launch it again later

Double-click `build/MIRA.app` in Finder, or run from the repository folder:

```bash
open build/MIRA.app
```

You only need to rebuild after changing the source.

## Permissions

Approve only permissions required by the features you use.

| Permission | Purpose |
| --- | --- |
| Camera | Hand tracking |
| Accessibility | Cursor input and window controls |
| Screen Recording / Screen & System Audio Recording | Screenshots |
| Automation: Google Chrome | Website/tab controls |
| Automation: Spotify or Music | Playback controls |

Find these in System Settings > Privacy & Security.
After changing permissions, completely quit and reopen the same app.

MIRA does not ask for your Apple Account password or have its own login.
macOS may require system authentication to change protected settings.
The app does not bypass those protections.

Ad-hoc signing does not guarantee permissions persist across rebuilds.
If MIRA reports unavailable access despite an enabled entry, check
that the entry belongs to the current build.

## Cursor Control

Start the camera, then enable Cursor Control in the toolbar.

- Open palm moves the cursor.
- Fist clicks once at its last position.
- Open your palm again before another click.
- Holding a fist does not repeatedly click.
- Cursor Control and assigned Actions are mutually exclusive.
- Movement targets the primary display.
- Scrolling and dragging are not implemented.

## Open/close behavior

Website actions use Google Chrome. They close the tracked tab or one
matching site tab when tracking is unavailable; otherwise they open it.

Application close actions request a normal quit. They do not bypass
unsaved-work dialogs. Relax your hand between repeated gestures.

## Troubleshooting

- Accessibility blocked: approve the current MIRA build and relaunch.
- Camera off: start it in the toolbar.
- No landmarks: keep the whole hand visible with good lighting.
- Pose unclear: show a clear open palm or fist.
- Chrome command failed: check Automation permission.
- Window resize rejected: some apps restrict external resizing.

Test the exact recording setup before making your demo. Another camera
application adds a variable; use a separate phone for face footage if needed.

## Privacy and limitations

Hand recognition runs locally. The camera pipeline does not save video.
Website actions intentionally open external services.

Recognition is rule-based. Setup measurements adjust confidence;
they do not train a new neural network.

This is a prototype, not a guaranteed mouse replacement or validated
accessibility solution. Bindings are shared between hands, and one hand
is analyzed at a time.

## Tests

```bash
swift test
```

XCTest tests may require full Xcode selected under
Xcode > Settings > Locations > Command Line Tools.
