#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG="$BASE_DIR/config/cameras.conf"
LOG="$BASE_DIR/logs/recorder.log"
OUTPUT="$BASE_DIR/recordings"

mkdir -p "$OUTPUT"
mkdir -p "$BASE_DIR/logs"

# Rotate log
if [ -f "$LOG" ]; then
    mv "$LOG" "$LOG.old"
fi
touch "$LOG"

# Load credentials
source "$BASE_DIR/secrets/credentials.env"

# Update IPs before start
"$BASE_DIR/scripts/ip_update.sh"

echo "===================================" >> "$LOG"
echo "$(date '+%F %T') - Recorder started" >> "$LOG"

# Function to get credentials
get_credentials() {
    case "$1" in
        roof_cam)
            CAM_USER="$ROOF_CAM_USER"
            CAM_PASS="$ROOF_CAM_PASS"
            ;;
        front_cam)
            CAM_USER="$FRONT_CAM_USER"
            CAM_PASS="$FRONT_CAM_PASS"
            ;;
        side_cam)
            CAM_USER="$SIDE_CAM_USER"
            CAM_PASS="$SIDE_CAM_PASS"
            ;;
        *)
            echo "$(date '+%F %T') - Unknown camera: $1" >> "$LOG"
            return 1
            ;;
    esac
}

# Start recording per camera
while read -r NAME IP; do

    get_credentials "$NAME"

    # Freeze values for subshell
    CAM_NAME="$NAME"
    CAM_IP="$IP"
    CAM_USER_LOCAL="$CAM_USER"
    CAM_PASS_LOCAL="$CAM_PASS"

    (
        while true; do

            DATE=$(date +%Y-%m-%d)
            CAM_DIR="$OUTPUT/$DATE/$CAM_NAME"
            mkdir -p "$CAM_DIR"

            echo "$(date '+%F %T') - [$CAM_NAME $CAM_IP] Recording started" >> "$LOG"

            ffmpeg -rtsp_transport tcp -fflags +genpts -use_wallclock_as_timestamps 1 \
            -i "rtsp://$CAM_USER_LOCAL:$CAM_PASS_LOCAL@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1" \
            -c copy \
            -f segment \
            -segment_time 300 \
            -segment_atclocktime 1 \
            -reset_timestamps 1 \
            -strftime 1 \
            "$CAM_DIR/${CAM_NAME}_%Y%m%d_%H%M%S.mp4" >> "$LOG" 2>&1

            echo "$(date '+%F %T') - [$CAM_NAME] ffmpeg stopped, restarting..." >> "$LOG"
            sleep 5

        done
    ) &

done < "$CONFIG"

wait