#!/bin/bash

CAM_NAME="$1"
CAM_IP="$2"
CAM_USER="$3"
CAM_PASS="$4"

LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/ffmpeg_${CAM_NAME}_$(date +%F_%H-%M-%S).log"

echo "Starting raw ffmpeg log for ${CAM_NAME}"
echo "Log file: $LOG_FILE"

ffmpeg -hide_banner -nostats -loglevel verbose \
-rtsp_transport tcp \
-i "rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1" \
-f null - \
2>&1 | tee "$LOG_FILE"
