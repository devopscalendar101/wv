# Security: Encrypted Scripts for Public Repository

## Overview

This directory contains encrypted versions of sensitive scripts that can be safely stored in a public repository. The scripts are encrypted using AES-256-CBC encryption and are automatically decrypted during GitHub Actions workflow execution.

## 🔐 Security Model

**Files in Public Repo:**
- ✅ `*.enc` - Encrypted scripts (safe to commit)
- ✅ `encrypt.sh` - Encryption tool
- ✅ `decrypt.sh` - Decryption tool  
- ✅ Workflow files (`.yml`)
- ✅ `batch-config.json`
- ✅ Documentation files

**NOT in Public Repo:**
- ❌ Original unencrypted scripts
- ❌ Encryption key (stored in GitHub Secrets)
- ❌ Vault tokens or credentials

## 🚀 Initial Setup (One-Time)

### Step 1: Generate Strong Encryption Key

```bash
# Generate a random 32-character encryption key
openssl rand -base64 32
```

Save this key securely - you'll need it for encryption and as a GitHub Secret.

### Step 2: Encrypt Your Scripts

```bash
cd github_actions

# Run encryption script with your key
./encrypt.sh "your-encryption-key-from-step-1"
```

This will create `.enc` files for:
- `scripts/s3_tool.enc`
- `scripts/vemio_upload.enc`
- `scripts/watermark.enc`
- `scripts/zoomd.enc`
- `scripts/s3wm_update.enc`
- `scripts/zoom_attendance.enc`
- `scripts/s3_tool_simple.py.enc`

### Step 3: Delete Original Unencrypted Files

```bash
# Delete originals (they're now encrypted)
rm scripts/s3_tool
rm scripts/vemio_upload
rm scripts/watermark
rm scripts/zoomd
rm scripts/s3wm_update
rm scripts/zoom_attendance
rm scripts/s3_tool_simple.py
```

### Step 4: Add Encryption Key to GitHub Secrets

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `SCRIPTS_ENCRYPTION_KEY`
5. Value: Your encryption key from Step 1
6. Click "Add secret"

### Step 5: Commit Encrypted Files

```bash
git add *.enc encrypt.sh decrypt.sh
git commit -m "Add encrypted scripts for public repo"
git push
```

## 🔄 Workflow Integration

The workflows automatically decrypt scripts before use:

```yaml
- name: Decrypt sensitive scripts
  env:
    SCRIPTS_ENCRYPTION_KEY: ${{ secrets.SCRIPTS_ENCRYPTION_KEY }}
  run: |
    cd github_actions
    chmod +x decrypt.sh
    ./decrypt.sh
```

This step:
1. Runs at the start of each job
2. Decrypts all `.enc` files
3. Makes them executable
4. Scripts are only available during workflow execution
5. Automatically cleaned up when job finishes

## 🛠️ Updating Encrypted Scripts

When you need to update a script:

### Option A: Update Locally and Re-encrypt

```bash
# 1. Decrypt locally for editing (don't commit!)
cd github_actions
export SCRIPTS_ENCRYPTION_KEY="your-key"
./decrypt.sh

# 2. Edit the script
vim scripts/s3_tool

# 3. Re-encrypt
./encrypt.sh "$SCRIPTS_ENCRYPTION_KEY"

# 4. Delete the unencrypted version
rm scripts/s3_tool

# 5. Commit only the .enc file
git add scripts/s3_tool.enc
git commit -m "Update s3_tool script"
git push
```

### Option B: Edit Via GitHub Actions

Create a workflow to decrypt, edit, and re-encrypt:

```yaml
name: Update Scripts

on:
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Decrypt scripts
        env:
          SCRIPTS_ENCRYPTION_KEY: ${{ secrets.SCRIPTS_ENCRYPTION_KEY }}
        run: |
          cd github_actions
          ./decrypt.sh
      # Make your changes here
      - name: Re-encrypt scripts
        env:
          SCRIPTS_ENCRYPTION_KEY: ${{ secrets.SCRIPTS_ENCRYPTION_KEY }}
        run: |
          cd github_actions
          ./encrypt.sh "$SCRIPTS_ENCRYPTION_KEY"
      # Commit encrypted files
```

## 🔍 Verification

### Verify Encryption is Working

```bash
# Try to read encrypted file (should be gibberish)
cat scripts/s3_tool.enc

# Check file is actually encrypted
file scripts/s3_tool.enc
# Output: scripts/s3_tool.enc: openssl enc'd data with salted password
```

### Test Decryption Locally

```bash
export SCRIPTS_ENCRYPTION_KEY="your-key"
./decrypt.sh

# Verify scripts are readable
cat scripts/s3_tool | head
```

## 🎯 What This Protects

✅ **Protected:**
- Script logic and implementation details
- API endpoint URLs
- Internal tool paths
- Script comments and documentation
- Algorithm implementations

❌ **NOT Protected (Store in GitHub Secrets):**
- Vault tokens (`SERVICE_TOKEN`)
- Database credentials (`PGHOST`, `PGPASSWORD`)
- API keys (Zoom, Vimeo, AWS)
- Any sensitive data values

## 🔐 Security Best Practices

1. **Never commit unencrypted scripts** to public repo
2. **Never hardcode secrets** in scripts - use environment variables
3. **Rotate encryption key** periodically
4. **Use different keys** for dev/staging/production
5. **Audit access** to GitHub Secrets regularly
6. **Enable branch protection** to prevent accidental commits

## 📋 Encryption Key Management

### Rotating the Encryption Key

```bash
# 1. Generate new key
NEW_KEY=$(openssl rand -base64 32)

# 2. Decrypt with old key
export SCRIPTS_ENCRYPTION_KEY="old-key"
./decrypt.sh

# 3. Encrypt with new key
./encrypt.sh "$NEW_KEY"

# 4. Update GitHub Secret with new key

# 5. Delete unencrypted files and commit
rm scripts/s3_tool scripts/vemio_upload scripts/watermark scripts/zoomd scripts/s3wm_update scripts/zoom_attendance scripts/s3_tool_simple.py
git add scripts/*.enc
git commit -m "Rotate encryption key"
git push
```

## ❓ Troubleshooting

### "Decryption failed" error

**Cause:** Wrong encryption key in GitHub Secret

**Fix:**
1. Verify the key in GitHub Secrets matches the key used for encryption
2. Re-encrypt files if needed

### "File not found" errors during workflow

**Cause:** Scripts weren't decrypted properly

**Fix:**
1. Check the decrypt step ran successfully
2. Verify all `.enc` files are committed
3. Check `SCRIPTS_ENCRYPTION_KEY` secret is set

### Want to work with scripts locally

```bash
# Decrypt locally (temporary)
export SCRIPTS_ENCRYPTION_KEY="your-key"
./decrypt.sh

# Work with scripts...

# Before committing, re-encrypt and remove originals
./encrypt.sh "$SCRIPTS_ENCRYPTION_KEY"
rm scripts/s3_tool scripts/vemio_upload # etc...
```

## 🌟 Advantages

1. **Safe for public repos** - All sensitive code is encrypted
2. **Easy maintenance** - Simple encrypt/decrypt workflow
3. **No performance impact** - Decryption happens once at workflow start
4. **Version controlled** - Encrypted files can be committed normally
5. **Audit trail** - All changes are tracked in git history
6. **Automatic cleanup** - Decrypted files never leave GitHub Actions runners

## 📝 Additional Notes

- Encrypted files are ~33% larger than originals (base64 encoding)
- Decryption takes <1 second per file
- AES-256-CBC is military-grade encryption
- GitHub Secrets are encrypted at rest and in transit
- Workflow logs never show the encryption key
