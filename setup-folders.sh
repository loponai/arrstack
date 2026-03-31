#!/bin/bash
# ============================================================
# Tom Spark's ARR Stack — Folder Structure Setup
# https://github.com/loponai/arrstack
#
# Creates the /data directory structure required for hard links
# to work correctly. Run this ONCE before starting the stack.
#
# Usage: sudo bash setup-folders.sh
# ============================================================

set -e

DATA_DIR="/data"

echo ""
echo "=== Tom Spark's ARR Stack — Folder Setup ==="
echo ""
echo "This will create the following structure:"
echo ""
echo "  /data/"
echo "  ├── torrents/"
echo "  │   ├── movies/"
echo "  │   ├── tv/"
echo "  │   └── music/"
echo "  └── media/"
echo "      ├── movies/"
echo "      ├── tv/"
echo "      └── music/"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script needs sudo to create /data and set permissions."
    echo "Run: sudo bash setup-folders.sh"
    exit 1
fi

# Get the real user (not root) for ownership
REAL_USER=${SUDO_USER:-$USER}
REAL_UID=$(id -u "$REAL_USER")
REAL_GID=$(id -g "$REAL_USER")

echo "Creating folders..."
mkdir -p "$DATA_DIR"/{torrents/{movies,tv,music},media/{movies,tv,music}}

echo "Setting ownership to $REAL_USER ($REAL_UID:$REAL_GID)..."
chown -R "$REAL_UID":"$REAL_GID" "$DATA_DIR"

echo "Setting permissions..."
chmod -R 775 "$DATA_DIR"

echo ""
echo "Done! Folder structure:"
if command -v tree &> /dev/null; then
    tree "$DATA_DIR"
else
    find "$DATA_DIR" -type d | head -20
fi

echo ""
echo "Your PUID=$REAL_UID and PGID=$REAL_GID"
echo "Make sure these match your .env file."
echo ""
