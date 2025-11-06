#!/usr/bin/env bash
# auto-hotspot.sh
# Checks if PREDEFINED_SSID is in range; if not, starts an open hotspot named HOTSPOT_SSID.
# Run as root or with sudo.

set -euo pipefail

# === CONFIG ===
PREDEFINED_SSID="Vodafone-RC-RPI"     # the network you expect to see
SECOND_PREDEFINED_SSID="MEO-52EC60"     # the network you expect to see
HOTSPOT_SSID="rpihotspot"      # SSID for the open hotspot
HOTSPOT_CONN_NAME="rpihotspot"  # nm-connection name
# Optionally set a specific wifi interface (leave empty to auto-detect)
WIFI_IFACE="wlan0"
# =============

# Find a wifi interface if not provided
if [[ -z "$WIFI_IFACE" ]]; then
  WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2=="wifi" {print $1; exit}')
  if [[ -z "$WIFI_IFACE" ]]; then
    echo "ERROR: no Wi-Fi interface found (nmcli device status)."
    exit 1
  fi
fi

echo "Using wifi interface: $WIFI_IFACE"

# Ensure wifi radio is on
nmcli radio wifi on >/dev/null 2>&1 || true

# Scan for available SSIDs (non-blocking cached scan). Use -f SSID in terse mode to avoid header.
if nmcli -t -f SSID dev wifi | grep -xFq "$PREDEFINED_SSID"; then
  echo "Predefined SSID '$PREDEFINED_SSID' is in range. Ensure hotspot is down."
  # If hotspot connection active, bring it down
         if nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless" {print $1}' | grep -xFq "$HOTSPOT_CONN_NAME"; then
    echo "Stopping hotspot connection '$HOTSPOT_CONN_NAME'..."
    nmcli connection down "$HOTSPOT_CONN_NAME" || true
  fi
  exit 0
fi

# Scan for available SSIDs (non-blocking cached scan). Use -f SSID in terse mode to avoid header.
if nmcli -t -f SSID dev wifi | grep -xFq "$SECOND_PREDEFINED_SSID"; then
  echo "Predefined SSID '$SECOND_PREDEFINED_SSID' is in range. Ensure hotspot is down."
  # If hotspot connection active, bring it down
         if nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless" {print $1}' | grep -xFq "$HOTSPOT_CONN_NAME"; then
    echo "Stopping hotspot connection '$HOTSPOT_CONN_NAME'..."
    nmcli connection down "$HOTSPOT_CONN_NAME" || true
  fi
  exit 0
fi

echo "Predefined SSID '$PREDEFINED_SSID' NOT found. Starting open hotspot..."

# If connection does not exist, create it (open / no security)
if ! nmcli connection show "$HOTSPOT_CONN_NAME" >/dev/null 2>&1; then
  echo "Creating hotspot connection '$HOTSPOT_CONN_NAME' (open, mode=ap, ipv4 shared)..."
  nmcli connection add type wifi ifname "$WIFI_IFACE" con-name "$HOTSPOT_CONN_NAME" autoconnect no ssid "$HOTSPOT_SSID" \
    802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
  # ensure no wifi-security settings are present (open)
  nmcli connection modify "$HOTSPOT_CONN_NAME" 802-11-wireless.hidden no
fi


if nmcli -t -f SSID dev wifi | grep -xFq "$HOTSPOT_CONN_NAME"; then
echo "hotspot already qctive"
exit 0
fi
# Bring the hotspot up
echo "Bringing up hotspot '$HOTSPOT_CONN_NAME' on interface $WIFI_IFACE..."
nmcli connection up "$HOTSPOT_CONN_NAME"

echo "Hotspot should be active (SSID: $HOTSPOT_SSID)."
exit 0
