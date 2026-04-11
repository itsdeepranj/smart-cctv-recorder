#!/bin/bash

# --------------------------------------------------
# Run the programe one time only
# --------------------------------------------------
exec 200>/tmp/recorder.lock
flock -n 200 || { echo "Recorder already running"; exit 1; }

# --------------------------------------------------
# Base directory
# --------------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG="$BASE_DIR/config/cameras.conf"
OUTPUT="$BASE_DIR/recordings"

# --------------------------------------------------
# Logging (shared)
# --------------------------------------------------
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/recorder_$(date +%F).log"

log() {
    LEVEL="$1"
    CAM="$2"
    EVENT="$3"
    MSG="$4"
    echo "$(date '+%F %T') | $LEVEL | $CAM | $EVENT | $MSG" >> "$LOG"
}

log INFO SYSTEM RECORDER "Started"

# --------------------------------------------------
# Load credentials
# --------------------------------------------------
source "$BASE_DIR/secrets/credentials.env"

# --------------------------------------------------
# Running Status Sent to Telegram
# --------------------------------------------------
MSG="🚀 Smart CCTV Recorder started%0AHost: $(hostname)%0ATime: $(date)"

curl -s \
"https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$MSG" >/dev/null

# --------------------------------------------------
# Initial IP update
# --------------------------------------------------
log INFO SYSTEM IP_UPDATE "Initial scan"
"$BASE_DIR/scripts/ip_update.sh"

# --------------------------------------------------
# Start cameras
# --------------------------------------------------
while read -r CAM_NAME CAM_IP; do

    # freeze values
    CAM_NAME_LOCAL="$CAM_NAME"
    CAM_IP_LOCAL="$CAM_IP"

(
    CAM_NAME="$CAM_NAME_LOCAL"
    CAM_IP="$CAM_IP_LOCAL"

    # credentials mapping
    case "$CAM_NAME" in
        roof_cam)
            CAM_USER_LOCAL="$ROOF_CAM_USER"
            CAM_PASS_LOCAL="$ROOF_CAM_PASS"
            ;;
        front_cam)
            CAM_USER_LOCAL="$FRONT_CAM_USER"
            CAM_PASS_LOCAL="$FRONT_CAM_PASS"
            ;;
        side_cam)
            CAM_USER_LOCAL="$SIDE_CAM_USER"
            CAM_PASS_LOCAL="$SIDE_CAM_PASS"
            ;;
        *)
            log ERROR "$CAM_NAME" UNKNOWN_CAMERA "No credentials defined"
            exit 1
            ;;
    esac

    # validate credentials
    if [ -z "$CAM_USER_LOCAL" ] || [ -z "$CAM_PASS_LOCAL" ]; then
        log ERROR "$CAM_NAME" AUTH_CONFIG "Missing username/password"
        exit 1
    fi

    # freeze credentials
    CAM_USER="$CAM_USER_LOCAL"
    CAM_PASS="$CAM_PASS_LOCAL"

    trap "kill 0" EXIT

    LAST_IP_UPDATE=0

    # Create folder continuously for current and next hour to avoid ffmpeg issues

    (
    while true; do

        for h in 0 1 2; do
        DATE=$(date -d "+$h hour" +%Y-%m-%d)
        HOUR=$(date -d "+$h hour" +%H)
        mkdir -p "$OUTPUT/$DATE/$HOUR/$CAM_NAME"
    	done
        sleep 5
    done
    ) &

    # Recorder loop
    while true; do

        log INFO "$CAM_NAME" START "Recording started (IP=$CAM_IP)"

        ffmpeg -rtsp_transport tcp -fflags +genpts -use_wallclock_as_timestamps 1 \
        -i "rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1" \
        -c copy \
        -f segment \
        -segment_time 300 \
        -reset_timestamps 1 \
        -strftime 1 \
        "$OUTPUT/%Y-%m-%d/%H/$CAM_NAME/${CAM_NAME}_%Y%m%d_%H%M%S.mp4" 2>&1 | while read line; do

            echo "$line" >> "$LOG"

            if echo "$line" | grep -qi "Connection refused"; then
                log ERROR "$CAM_NAME" STREAM "Connection refused"

                NOW=$(date +%s)
                if (( NOW - LAST_IP_UPDATE > 60 )); then
                    log WARN SYSTEM IP_UPDATE "Triggered by $CAM_NAME"
                    "$BASE_DIR/scripts/ip_update.sh"
                    LAST_IP_UPDATE=$NOW

                    CAM_IP=$(grep "^$CAM_NAME " "$CONFIG" | awk '{print $2}')
                    log INFO "$CAM_NAME" IP_REFRESH "New IP=$CAM_IP"
                fi
            fi

            if echo "$line" | grep -qi "timed out"; then
                log ERROR "$CAM_NAME" STREAM "Timeout"
            fi

            if echo "$line" | grep -qi "404"; then
                log ERROR "$CAM_NAME" STREAM "RTSP 404"
            fi

        done

        RET=$?

        if [ $RET -ne 0 ]; then
            log ERROR "$CAM_NAME" FFMPEG "Exited code $RET"

            NOW=$(date +%s)
            if (( NOW - LAST_IP_UPDATE > 60 )); then
                log WARN SYSTEM IP_UPDATE "Triggered by ffmpeg exit ($CAM_NAME)"
                "$BASE_DIR/scripts/ip_update.sh"
                LAST_IP_UPDATE=$NOW

                CAM_IP=$(grep "^$CAM_NAME " "$CONFIG" | awk '{print $2}')
                log INFO "$CAM_NAME" IP_REFRESH "New IP=$CAM_IP"
            fi
        fi

        log INFO "$CAM_NAME" HEARTBEAT "Alive"
        log WARN "$CAM_NAME" RETRY "Restarting in 5s"

        sleep 20

    done

) &

done < "$CONFIG"

wait