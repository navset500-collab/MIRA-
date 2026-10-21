import json
import sys
import time
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

MODEL = Path(sys.argv[1]).resolve()

JOINTS = [
    (0, "wrist"),
    (1, "thumbCMC"), (2, "thumbMP"), (3, "thumbIP"), (4, "thumbTip"),
    (5, "indexMCP"), (6, "indexPIP"), (7, "indexDIP"), (8, "indexTip"),
    (9, "middleMCP"), (10, "middlePIP"), (11, "middleDIP"), (12, "middleTip"),
    (13, "ringMCP"), (14, "ringPIP"), (15, "ringDIP"), (16, "ringTip"),
    (17, "littleMCP"), (18, "littlePIP"), (19, "littleDIP"), (20, "littleTip"),
]

options = vision.HandLandmarkerOptions(
    base_options=python.BaseOptions(model_asset_path=str(MODEL)),
    running_mode=vision.RunningMode.VIDEO,
    num_hands=1,
    min_hand_detection_confidence=0.5,
    min_hand_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)

def confidence(landmark):
    visibility = getattr(landmark, "visibility", 1.0)
    presence = getattr(landmark, "presence", 1.0)
    try:
        return float(max(0.0, min(1.0, visibility * presence)))
    except TypeError:
        return 1.0

def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()

with vision.HandLandmarker.create_from_options(options) as tracker:
    timestamp_ms = -1
    while True:
        header = sys.stdin.buffer.read(12)
        if len(header) != 12:
            break

        width, height, length = np.frombuffer(header, dtype="<u4")
        data = sys.stdin.buffer.read(int(length))
        if len(data) != int(length):
            break

        frame = np.frombuffer(data, dtype=np.uint8).reshape(
            int(height), int(width), 4
        )
        rgb = np.ascontiguousarray(cv2.cvtColor(frame, cv2.COLOR_BGRA2RGB))
        timestamp_ms += 1

        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = tracker.detect_for_video(image, timestamp_ms)

        landmarks = []
        if result.hand_landmarks:
            hand = result.hand_landmarks[0]
            for index, name in JOINTS:
                point = hand[index]
                landmarks.append({
                    "id": name,
                    "x": float(point.x),
                    "y": float(1.0 - point.y),
                    "confidence": confidence(point),
                })

        emit({
            "ok": True,
            "timestamp_ms": timestamp_ms,
            "landmarks": landmarks,
        })
