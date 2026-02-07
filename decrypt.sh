#!/usr/bin/env bash

# Script to decrypt encrypted files in GitHub Actions workflow
# This runs automatically in the workflow

set -e

if [[ -z "$SCRIPTS_ENCRYPTION_KEY" ]]; then
    echo "ERROR: SCRIPTS_ENCRYPTION_KEY environment variable not set"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files to decrypt
FILES_TO_DECRYPT=(
    "scripts/s3_tool"
    "scripts/vemio_upload"
    "scripts/watermark"
    "scripts/zoomd"
    "scripts/s3wm_update"
    "scripts/zoom_attendance"
    "scripts/s3_tool_simple.py"
)

echo "🔓 Decrypting sensitive files..."

for file in "${FILES_TO_DECRYPT[@]}"; do
    if [[ -f "$SCRIPT_DIR/${file}.enc" ]]; then
        echo "  Decrypting: $file"
        # Decrypt using AES-256-CBC
        openssl enc -aes-256-cbc -d -pbkdf2 -in "$SCRIPT_DIR/${file}.enc" -out "$SCRIPT_DIR/$file" -k "$SCRIPTS_ENCRYPTION_KEY"
        chmod +x "$SCRIPT_DIR/$file" 2>/dev/null || true
        echo "    ✓ Decrypted: $file"
    else
        echo "  WARNING: Encrypted file not found: ${file}.enc"
    fi
done

echo ""
echo "✓ Decryption complete! Scripts are ready to use."
