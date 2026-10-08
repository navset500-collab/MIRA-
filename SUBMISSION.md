# ImpactHack 2026 Submission Draft

## Project name

MIRA — Motion Interface for Real-Time Access

## Project description

MIRA is a native macOS prototype that lets people use a handful of personalized hand poses to control their computer when their hands are busy. It uses Apple's Vision hand-pose model on-device, learns numeric gesture templates during a short setup, and maps steady gestures to user-selected macOS actions. Camera frames are processed locally and discarded.

## Problem

Computer controls assume a person can reach a keyboard or trackpad at any moment. That interruption is inconvenient when writing notes, presenting, cooking, or working with both hands. MIRA explores a small, optional hands-free control layer for those moments; it is a supplement, not a replacement for standard input or assistive technology.

## How it works

1. AVFoundation captures camera frames locally.
2. Apple's Vision `VNDetectHumanHandPoseRequest` detects up to 21 anatomical hand joints.
3. MIRA derives scale-normalized finger and thumb geometry from those real landmarks and draws a confidence-aware connected skeleton over the hand.
4. A first-run flow captures three short passes of twelve poses at different distances/angles and stores averaged numeric features.
5. A conservative classifier can return unknown instead of firing on a weak or ambiguous pose. A short temporal hold prevents one-frame triggers, and release is required before the same gesture can fire again.
6. The user chooses bindings and explicitly enables gesture actions. A per-binding Test button helps verify macOS actions and permissions independently of recognition.

## Technologies and AI

- Swift and SwiftUI for the native macOS interface.
- AVFoundation for camera capture.
- Apple Vision hand-pose recognition through `VNDetectHumanHandPoseRequest`.
- SayHi-style wrist-normalized PIP extension rules, personal numeric templates, and temporal stabilization.
- AppKit and macOS system services for app launching, screenshots, and Music control.
- No remote model, API key, cloud inference, or recognition network request. Apple Vision is the on-device AI API; adding an unrelated cloud API would increase privacy and demo risk without improving the core interaction.

## Current prototype scope

The current build supports one hand at a time and twelve poses: fist, open palm, thumbs up/down, peace, point up/down/left/right, OK, rock, and shaka. It does not yet provide left/right-specific bindings, app-aware context, or custom gestures. The camera and action flow must be tested on the demo Mac before making claims about reliability, latency, or accuracy.

## Source code

Local project: `Documents/GitHub/MIRA`.

Add the public GitHub repository URL here after publishing the source. Do not submit a placeholder as though it were a live repository link.

## Screenshots to capture from the real app

- The welcome and use-case selection screen.
- A calibration step with the live camera skeleton visible.
- The dashboard with the actual hand overlay and motion trail.
- A completed, user-enabled action with its confirmation shown.

Use real MIRA captures only. Do not use the earlier SayHi screenshot as if it were MIRA.

## Demo video

Use the 2–4 minute script in [DEMO_SCRIPT.md](DEMO_SCRIPT.md). Keep the majority of the video on the actual running application; only claim behavior that succeeds on the recording Mac.