
#!/bin/bash

#------------------------------------------
# Base directory
#------------------------------------------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NETWORK_PREFIX="$BAE_DIR/config/network.conf"
DEVICE_CONF="$BASE_DIR/secrets/device.conf"
CAM_CONF="$BASE_DIR/config/cameras.conf"

#------------------------------------------
# Logging setup (shared)
#------------------------------------------
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/recorder_$(date +%F).log"

# Delete log older than 7 days
find "$LOG_DIR" -name "recorder_*.log" -mtime +7 -delete

log() {
	LEVEL="$1"
    CAM="$2"
    EVENT="$3"
    MSG="$4"
    
    echo "$(date '+%F %T') | $LEVEL | $CAM | $EVENT | $MSG" >> "$LOG"
}

log INFO SYSTEM IP_UPDATE "Starting IP updated"

#------------------------------------------
# Populate ARP table
#------------------------------------------
log INFO SYSTEM ARP_SCAN "Scanning netwrok"

for i in {1..254}; do
	ping -c 1 -w 1 "$NETWORK_PREFIX.$i" >/dev/null 2>&1 &
done

wait

log INFO SYSTEM ARP_SCAN "Scan complete"

#------------------------------------------
# Update camera IPs
#------------------------------------------
while IFS=',' read -r NAME MAC; do

	MAC_UPPER=$(echo "$MAC" | tr '[:lower:]' '[:upper:]')
    
    IP=$(ip neigh | awk -v  mac="$MAC_UPPER" 'tolower($5)==tolower(mac) {print $1}' | head -n1)
    
    if [ -z "$IP" ]; then
    	log ERROR "$NAME" IP_NOT_FOUND "MAC=$MAC"
        continue
    fi
    
    OLD_IP=$(grep "^$NAME " "$CAM_CONF" | awk '{print $2}')
    
    if [ "$OLD_IP" != "$IP" ]; then
    	sed -i "s/^$NAME .*/$NAME $IP/" "$CAM_CONF"
        log WARN "$NAME" IP_CHANGED "Old=$OLD_IP New=$IP"
    else
      	log INFO "$NAME" IP_OK "IP=$IP"
     fi
     
  done < "$DEVICE_CONF"
  
  log INFO SYSTEM IP_UPDATE "Completed"
