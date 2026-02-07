#!/usr/bin/env bash

# Unified script for encrypting/decrypting sensitive files and installing dependencies
# Usage: 
#   bootstrap.sh safe    - Encrypt files and remove originals (run locally before push)
#   bootstrap.sh run     - Decrypt files (run in GitHub Actions)
#   bootstrap.sh install - Install required system dependencies (run in GitHub Actions)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Files to encrypt/decrypt (source in bin/scripts/, encrypted in extras/)
FILES=(
    "s3_tool"
    "vemio_upload"
    "watermark"
    "zoomd"
    "zoom_attendance"
    "s3_tool_simple.py"
)

encrypt_files() {
    if [[ -z "$SCRIPTS_ENCRYPTION_KEY" ]]; then
        echo "❌ ERROR: SCRIPTS_ENCRYPTION_KEY environment variable not set"
        echo ""
        echo "Usage: SCRIPTS_ENCRYPTION_KEY='your-key' ./bootstrap.sh safe"
        echo ""
        echo "Or export it first:"
        echo "  export SCRIPTS_ENCRYPTION_KEY='your-key'"
        echo "  ./bootstrap.sh safe"
        exit 1
    fi

    echo "🔐 Encrypting sensitive files from bin/scripts/ to extras/..."
    echo ""

    local encrypted_count=0
    local skipped_count=0

    for file in "${FILES[@]}"; do
        if [[ -f "$REPO_ROOT/bin/scripts/$file" ]]; then
            echo "  🔒 Encrypting: $file"
            openssl enc -aes-256-cbc -salt -pbkdf2 -in "$REPO_ROOT/bin/scripts/$file" -out "$REPO_ROOT/extras/${file}.enc" -k "$SCRIPTS_ENCRYPTION_KEY"
            echo "     ✓ Encrypted: bin/scripts/$file → extras/${file}.enc"
            encrypted_count=$((encrypted_count + 1))
        else
            if [[ -f "$REPO_ROOT/extras/${file}.enc" ]]; then
                echo "  ⏭️  Already encrypted: extras/${file}.enc"
                skipped_count=$((skipped_count + 1))
            else
                echo "  ⚠️  Source file not found: bin/scripts/$file"
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
    echo "     git add extras/*.enc"
    echo "     git commit -m 'Update encrypted scripts'"
    echo "     git push"
    echo ""
    echo "  2. Ensure GitHub Secret is set:"
    echo "     Name: SCRIPTS_ENCRYPTION_KEY"
    echo "     Value: <your-encryption-key>"
    echo ""
}

decrypt_files() {
    if [[ -z "$SCRIPTS_ENCRYPTION_KEY" ]]; then
        echo "❌ ERROR: SCRIPTS_ENCRYPTION_KEY environment variable not set"
        echo ""
        echo "In GitHub Actions, this should be set from secrets:"
        echo "  env:"
        echo "    SCRIPTS_ENCRYPTION_KEY: \${{ secrets.SCRIPTS_ENCRYPTION_KEY }}"
        echo ""
        echo "For local testing:"
        echo "  export SCRIPTS_ENCRYPTION_KEY='your-key'"
        echo "  ./bootstrap.sh run"
        exit 1
    fi

    echo "🔓 Decrypting sensitive files from extras/ to extras/..."
    echo ""

    local decrypted_count=0
    local skipped_count=0

    for file in "${FILES[@]}"; do
        if [[ -f "$REPO_ROOT/extras/${file}.enc" ]]; then
            echo "  🔓 Decrypting: $file"
            openssl enc -aes-256-cbc -d -pbkdf2 -in "$REPO_ROOT/extras/${file}.enc" -out "$REPO_ROOT/extras/$file" -k "$SCRIPTS_ENCRYPTION_KEY"
            chmod +x "$REPO_ROOT/extras/$file" 2>/dev/null || true
            echo "     ✓ Decrypted: extras/${file}.enc → extras/$file"
            decrypted_count=$((decrypted_count + 1))
        else
            if [[ -f "$REPO_ROOT/extras/$file" ]]; then
                echo "  ⏭️  Already decrypted: extras/$file"
                skipped_count=$((skipped_count + 1))
            else
                echo "  ⚠️  Encrypted file not found: extras/${file}.enc"
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

install_dependencies() {
    echo "📦 Installing system dependencies..."
    echo ""

    # Only install what's NOT pre-installed on ubuntu-latest runners
    # Pre-installed: python3, pip, wget, curl, jq, unzip, gpg, gnupg, aws-cli
    echo "  Installing required packages..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        ffmpeg \
        postgresql-client \
        libpq-dev \
        python3-dev

    # Install Vault CLI (not pre-installed)
    if ! command -v vault &> /dev/null; then
        echo "  Installing HashiCorp Vault CLI..."
        wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq vault
    else
        echo "     ✓ Vault already installed: $(vault --version)"
    fi

    echo ""
    echo "✅ Dependencies installed!"
    echo "  - FFmpeg: $(ffmpeg -version 2>&1 | head -n1)"
    echo "  - PostgreSQL client: $(psql --version)"
    echo "  - Vault: $(vault --version 2>&1)"
    echo ""
}

show_usage() {
    cat << EOF
Usage: bootstrap.sh {safe|run|install}

Commands:
  safe    - Encrypt sensitive files and remove originals
            Requires: SCRIPTS_ENCRYPTION_KEY environment variable
            Run locally before committing to repo
          
  run     - Decrypt sensitive files for use
            Requires: SCRIPTS_ENCRYPTION_KEY environment variable
            Run in GitHub Actions workflow

  install - Install all required system dependencies
            Run in GitHub Actions before other steps
            Installs: python3, aws-cli, vault, postgresql-client, ffmpeg, etc.

Examples:
  # Encrypt before push (local)
  export SCRIPTS_ENCRYPTION_KEY='your-strong-key-here'
  ./bootstrap.sh safe
  git add extras/*.enc
  git push

  # Decrypt in GitHub Actions (workflow)
  - name: Decrypt scripts
    env:
      SCRIPTS_ENCRYPTION_KEY: \${{ secrets.SCRIPTS_ENCRYPTION_KEY }}
    run: |
      cd github_actions
      ./bootstrap.sh run

Environment Variables:
  SCRIPTS_ENCRYPTION_KEY  - Encryption/decryption key (required)
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
    install)
        install_dependencies
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
