#!/usr/bin/env bash

# Script to decrypt encrypted files in GitHub Actions workflow
# This runs automatically in the workflow

set -e

if [[ -z "$SCRIPTS_ENCRYPTION_KEY" ]]; then
    echo "ERROR: SCRIPTS_ENCRYPTION_KEY environment variable not set"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files to decrypt (in-place)
FILES_TO_DECRYPT=(
    "extras/s3_tool"
    "extras/vemio_upload"
    "extras/watermark"
    "extras/zoomd"
    "extras/zoom_attendance"
    "extras/s3_tool_simple.py"
)

echo "🔓 Decrypting sensitive files..."

for file in "${FILES_TO_DECRYPT[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo "  Decrypting: $file"
        # Decrypt in-place using AES-256-CBC
        local temp_file="${SCRIPT_DIR}/${file}.decrypted"
        openssl enc -aes-256-cbc -d -pbkdf2 -in "$SCRIPT_DIR/$file" -out "$temp_file" -k "$SCRIPTS_ENCRYPTION_KEY"
        mv "$temp_file" "$SCRIPT_DIR/$file"
        chmod +x "$SCRIPT_DIR/$file" 2>/dev/null || true
        echo "    ✓ Decrypted: $file"
    else
        echo "  WARNING: Encrypted file not found: $file"
    fi
done

echo ""
echo "✓ Decryption complete! Scripts are ready to use."
