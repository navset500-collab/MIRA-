# MIRA Demo Video Script

**Target length: about 2 minutes 45 seconds.** Keep the recording focused on the real app. Do not add unmeasured accuracy, FPS, or latency claims.

| Time | Picture | Voiceover / live audio |
|---|---|---|
| 0:00-0:22 | Camera on you writing notes while music plays; the Mac is slightly out of reach. | "Computers assume our hands are always free. When I'm taking notes, reaching over to pause something interrupts what I'm doing. We built MIRA for that small but constant gap." |
| 0:22-0:40 | Open MIRA's simplified welcome screen, point out the local-processing note, and start hand setup. | "MIRA is Motion Interface for Real-Time Access, a native computer app. It learns my own hand instead of requiring one perfect pose." |
| 0:40-1:15 | Grant camera permission if prompted. Show one calibration pose through its front, farther, and slight-angle passes; use quick cuts between the remaining prompted poses. | "Apple Vision estimates the hand's joints on this Mac. MIRA samples each pose from three views, compares normalized finger geometry, and saves numeric templates, not camera footage." |
| 1:15-1:32 | Finish setup and show the dashboard. Move the hand; show the connected finger and palm skeleton following the joints. | "Vision provides up to 21 internal joints. The connecting lines follow the actual wrist, knuckles, and finger joints; they aren't a decorative effect." |
| 1:32-1:50 | Show the binding list. Use the play button beside one binding to test its macOS action. Show the result or permission message. | "Each gesture has an editable action. The test control checks the macOS action separately, so I can tell a permission issue from a recognition issue." |
| 1:50-2:15 | Turn on Actions. Make thumbs up, then point left or right, waiting for each stability bar; show the selected action opening. Release between gestures. | "Actions are opt-in. I hold a pose, MIRA waits for a stable match, then performs my chosen action. I release before the next command, so a held pose doesn't repeat." |
| 2:15-2:30 | Show an ambiguous or neutral hand and the Unknown state. Then make one clear calibrated pose. | "When the hand is unclear, the right answer is unknown, not a guess that might trigger the wrong command." |
| 2:30-2:45 | Show the action confirmation and privacy footer, then cut back to the notebook. | "Recognition runs through Apple's on-device Vision API. There is no cloud inference in the gesture path. MIRA doesn't replace the keyboard; it helps in the moments your hands are busy." |

## Recording notes

- Rehearse all twelve poses and their three calibration passes in the same room, lighting, and camera framing used for the video.
- Grant camera permission before recording. Turn on Screen Recording or Automation only if the demonstrated action requests it.
- Test the chosen action with its Test button first, then demonstrate the same binding with a gesture.
- Keep the hand fully in view and at a distance where Vision maintains a stable skeleton. Never claim "all angles" or a specific response time unless tested.
- If a gesture is misread, show the unknown state and try again; don't edit in a fake successful action.
- Avoid showing performance numbers as claims. The FPS field is a live measurement, and one demo session is not a benchmark.
- Record the actual application. Do not use the uploaded SayHi screenshot as a MIRA screen.
- Add a public GitHub URL to the Devpost entry after publishing the repository; a local folder path is not a public source link.