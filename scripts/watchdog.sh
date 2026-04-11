#!/bin/bash

BASE="/opt/smart-cctv-recorder/recordings"
DATE=$(date -d "yesterday" +%F)

# load secrets
source /opt/smart-cctv-recorder/secrets/credentials.env

EXPECTED_CAMERAS=("roof_cam" "front_cam" "side_cam")

MISSING=0
REPORT="📹 CCTV Daily Report ($DATE)%0A%0A"

FFMPEG_COUNT=$(pgrep -c ffmpeg)
RECORDER_COUNT=$(pgrep -c recorder.sh)

REPORT+="%0A"
REPORT+="🎬 ffmpeg running: $FFMPEG_COUNT%0A"
REPORT+="🧠 recorder loops: $RECORDER_COUNT%0A"