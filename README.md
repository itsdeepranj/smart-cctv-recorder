# Smart CCTV Recorder (Self-Healing NVR)

A lightweight, self-healing CCTV recording system built using ffmpeg+Bash, designed to replace heavy NVR solutions with a modular,
reliable and low resource architecture.

## Overview

This project records RTSP camera streams locally while automatically handling:
- Dynamic IP changes (Via MAC address detection)
- Stream interruptions (Auto-recover on failure)
- Network outages (auto resart on reconnect)
- Continuous segmented recording
- Telegram alerts for system events

It is desgined for real-world reliability, especially in unstable network environments.

### Architecture

INIT -> RUN -> MONITOR -> RECOVER
System Check -> MAC -> IP -> Stream -> Record -> Log -> Watchdog -> Fix -> Restart

### Features
- **Dynamic IP Handling**: Detects cameras by MAC address, not IP, ensuring continuous recording even if IPs change.
- **Stream Monitoring**: Continuously checks stream health and automatically restarts recording if issues are detected.
- **Multi-Camera Support**: Easily add multiple cameras by configuring their MAC addresses and RTSP URLs.
- **Real-time watchdog**: Monitors system health and network status, automatically recovering from failures or outages.
- **Network-aware**: Pauses recording during network outages and automatically resumes when connectivity is restored.
- **5-minute Segmented Recording**: Saves recordings in 5-minute segments for easier management and retrieval.
- **Secure configuration**: Stores camera credentials securely in a separate configuration file.
- **Telegram Alerts**: Sends real-time notifications for critical events like stream failures or recoveries.

## Project Structure

smart-cctv-recorder/
|
|-- scripts/
|   |-- recorder.sh          # Main recording script
|   |-- view.sh              # Stream viewing script
|   |-- watchdog.sh           # System monitoring and recovery script
|   |-- ip_update.sh           # Dynamic IP handling script
|   |-- system_check.sh           # Initial system checks and setup script
|
|-- config/
|   |-- cameras.conf          # Camera configuration file (MAC, RTSP URL, credentials)
|   |-- settings.conf         # System settings (recording path, segment duration, etc.)
|
|-- secrets/
|   |-- credentials.env		 # Secure storage for camera credentials (not included in repo)
|   |-- devices.conf		 # Secure storage for device information (not included in repo)
|
|-- logs/
|-- recordings/
|
|-- .gitignore
|-- .env.example
|-- README.md

## Setup

### Clone repository

git clone https://github.com/itsdeepranj/smart-cctv-recorder.git
cd smart-cctv-recorder

### Configure cameras

- **Edit:		
config/cameras.conf

- **Example:
roof_cam,192.168.0.100
front_cam,192.168.0.101
side_came,192.168.0.102

### Add secrets (Not Comitted)

- **Create:
secrets/credentials.env

RTSP_USER=admin
RTSP_PASS=your_password

BOT_TOEKN=your_telegram_token
CHAT_ID=your_chat_id

- **Create:
secrets/devices.conf

roof_cam,AA:BB:CC:DD:EE:FF
front_cam,XX:XX:XX:XX:XX:XX
side_cam,XX:XX:XX:XX:XX:XX

### Install dependencies

sudo apt update
sudo apt install ffmpeg arp-scan curl

### Run recorder

cd scripts
chmod +x *.sh
./recorder.sh

## Live View(Terminal)

./view.sh

select a camera to open live stream using ffplay

## How It Works

### INIT PHASE
- Check internet & system
- Resolve IP using MAC

### RUN PHASE
- Validate RTSP stream
- Start ffmpeg recording
- Save segmented files

### Monitor & Recovery
- Watchdog monitor logs
- Detects failures instantly
- Fixes IP if changed
- Restarts recorder automatically

### Alerts
Telegram notifications for:
- Camera offline
- Stream failure
- IP change
- System recovery

## Security

sensitive data is excluded from Git:

secrets/
recordings/
logs/
.env

use .env .example as a template

## Design Philosophy

- No heavy NVR software
- Full Control with simple tools
- Event-driven (not cron-based)
- Modular and scalable
- Built for unstable networks

## Future Improvements
- Web dashboard
- Auto cleanup (retention policy)
- Cloud backup support
- Optional AI detection layer


## Installation guide
sudo cp systemd/smart-cctv-recorder.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable smart-cctv-recorder
sudo systemctl start smart-cctv-recorder