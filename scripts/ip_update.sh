#!/bin/bash

DEVICE_CONF="secrets/device.conf"
CAM_CONF="config/cameras.conf"
LOG="logs/ip_update.log"

NETWORK_PREFIX="config/network.conf"

echo "----------------------------------------" >> "$LOG"
echo "$(date) - Updating IPs from MAC" >> "$LOG"

# Clear old camera config
> "$CAM_CONF"

echo "$(date) - Scanning network..." >> "$LOG"

# Scan network to populate ARP
for i in {1..254}; do
    ping -c1 -W1 ${NETWORK_PREFIX}.$i >/dev/null 2>&1 &
done
wait

sleep 2

# Function: get IP from MAC
get_ip_from_mac() {
    local MAC=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    arp -an | while read -r line; do
        IP=$(echo "$line" | awk '{print $2}' | tr -d '()')
        ARP_MAC=$(echo "$line" | awk '{print $4}' | tr '[:upper:]' '[:lower:]')

        if [[ "$ARP_MAC" == "$MAC" ]]; then
            echo "$IP"
            return
        fi
    done
}

# Read device.conf
while IFS='=' read -r NAME MAC
do
    # Skip empty lines
    [ -z "$NAME" ] && continue

    IP=$(get_ip_from_mac "$MAC")

    if [ -n "$IP" ]; then
        echo "$NAME $IP" >> "$CAM_CONF"
        echo "$(date) - $NAME -> $IP" >> "$LOG"
    else
        echo "$(date) - $NAME -> NOT FOUND" >> "$LOG"
    fi

done < "$DEVICE_CONF"

echo "$(date) - IP update completed" >> "$LOG"
echo "----------------------------------------" >> "$LOG"