#!/bin/bash

SOURCE=/home/pi/.firewalla/config/dnsbooster
TARGET=/usr/local/bin/dnsbooster

if [ ! -x "$SOURCE" ]; then
    echo "dnsbooster source not found or not executable: $SOURCE" >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    ln -sf "$SOURCE" "$TARGET"
else
    sudo ln -sf "$SOURCE" "$TARGET"
fi
