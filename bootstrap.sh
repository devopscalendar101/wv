#!/usr/bin/env bash

# Unified script for encrypting/decrypting sensitive files
# Usage: 
#   bootstrap.sh safe  - Encrypt files and remove originals (run locally before push)
#   bootstrap.sh run   - Decrypt files (run in GitHub Actions)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files to encrypt/decrypt
FILES=(
    "scripts/s3_tool"
    "scripts/vemio_upload"
    "scripts/watermark"
    "scripts/zoomd"
    "scripts/s3wm_update"
    "scripts/zoom_attendance"
    "scripts/s3_tool_simple.py"
)

encrypt_files() {
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        echo "❌ ERROR: ENCRYPTION_KEY environment variable not set"
        echo ""
        echo "Usage: ENCRYPTION_KEY='your-key' ./bootstrap.sh safe"
        echo ""
        echo "Or export it first:"
        echo "  export ENCRYPTION_KEY='your-key'"
        echo "  ./bootstrap.sh safe"
        exit 1
    fi

    echo "🔐 Encrypting sensitive files..."
    echo ""

    local encrypted_count=0
    local skipped_count=0

    for file in "${FILES[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            echo "  🔒 Encrypting: $file"
            openssl enc -aes-256-cbc -salt -pbkdf2 -in "$SCRIPT_DIR/$file" -out "$SCRIPT_DIR/${file}.enc" -k "$ENCRYPTION_KEY"
            
            # Remove original file after successful encryption
            rm "$SCRIPT_DIR/$file"
            echo "     ✓ Encrypted and removed original: $file"
            encrypted_count=$((encrypted_count + 1))
        else
            if [[ -f "$SCRIPT_DIR/${file}.enc" ]]; then
                echo "  ⏭️  Already encrypted: ${file}.enc"
                skipped_count=$((skipped_count + 1))
            else
                echo "  ⚠️  File not found: $file"
            fi
        fi
    done

    echo ""
    echo "✅ Encryption complete!"
    echo "   Encrypted: $encrypted_count files"
    echo "   Already encrypted: $skipped_count files"
    echo ""
    echo "Next steps:"
    echo "  1. Commit the .enc files:"
    echo "     git add github_actions/scripts/*.enc"
    echo "     git commit -m 'Update encrypted scripts'"
    echo "     git push"
    echo ""
    echo "  2. Ensure GitHub Secret is set:"
    echo "     Name: SCRIPTS_ENCRYPTION_KEY"
    echo "     Value: <your-encryption-key>"
    echo ""
}

decrypt_files() {
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        echo "❌ ERROR: ENCRYPTION_KEY environment variable not set"
        echo ""
        echo "In GitHub Actions, this should be set from secrets:"
        echo "  env:"
        echo "    ENCRYPTION_KEY: \${{ secrets.SCRIPTS_ENCRYPTION_KEY }}"
        echo ""
        echo "For local testing:"
        echo "  export ENCRYPTION_KEY='your-key'"
        echo "  ./bootstrap.sh run"
        exit 1
    fi

    echo "🔓 Decrypting sensitive files..."
    echo ""

    local decrypted_count=0
    local skipped_count=0

    for file in "${FILES[@]}"; do
        if [[ -f "$SCRIPT_DIR/${file}.enc" ]]; then
            echo "  🔓 Decrypting: $file"
            openssl enc -aes-256-cbc -d -pbkdf2 -in "$SCRIPT_DIR/${file}.enc" -out "$SCRIPT_DIR/$file" -k "$ENCRYPTION_KEY"
            chmod +x "$SCRIPT_DIR/$file" 2>/dev/null || true
            echo "     ✓ Decrypted: $file"
            decrypted_count=$((decrypted_count + 1))
        else
            if [[ -f "$SCRIPT_DIR/$file" ]]; then
                echo "  ⏭️  Already decrypted: $file"
                skipped_count=$((skipped_count + 1))
            else
                echo "  ⚠️  Encrypted file not found: ${file}.enc"
            fi
        fi
    done

    echo ""
    echo "✅ Decryption complete!"
    echo "   Decrypted: $decrypted_count files"
    echo "   Already decrypted: $skipped_count files"
    echo "   Scripts are ready to use."
    echo ""
}

show_usage() {
    cat << EOF
Usage: bootstrap.sh {safe|run}

Commands:
  safe  - Encrypt sensitive files and remove originals
          Requires: ENCRYPTION_KEY environment variable
          Run locally before committing to repo
          
  run   - Decrypt sensitive files for use
          Requires: ENCRYPTION_KEY environment variable
          Run in GitHub Actions workflow

Examples:
  # Encrypt before push (local)
  export ENCRYPTION_KEY='your-strong-key-here'
  ./bootstrap.sh safe
  git add scripts/*.enc
  git push

  # Decrypt in GitHub Actions (workflow)
  - name: Decrypt scripts
    env:
      ENCRYPTION_KEY: \${{ secrets.SCRIPTS_ENCRYPTION_KEY }}
    run: |
      cd github_actions
      ./bootstrap.sh run

Environment Variables:
  ENCRYPTION_KEY  - Encryption/decryption key (required)
                    Store in GitHub Secrets as SCRIPTS_ENCRYPTION_KEY

Files managed:
$(printf "  - %s\n" "${FILES[@]}")

EOF
}

# Main script logic
case "${1:-}" in
    safe)
        encrypt_files
        ;;
    run)
        decrypt_files
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        echo "❌ ERROR: Invalid command"
        echo ""
        show_usage
        exit 1
        ;;
esac
