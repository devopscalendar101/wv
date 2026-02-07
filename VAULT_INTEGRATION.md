# Vault Integration for GitHub Actions

This workflow implements the same **multi-step Vault retrieval** process as your Jenkins pipeline, providing enterprise-grade security.

## Security Model

### Vault Token Hierarchy

```
SERVICE_TOKEN (GitHub Secret)
    ↓
ALL_TOKEN (from SVU vault)
    ↓
    ├─→ ITD_TEST_TOKEN → DB credentials, Vimeo credentials
    ├─→ AWS_ROOT_TOKEN → AWS credentials  
    └─→ ZOOM_TOKEN → Zoom credentials (Z1, Z2, Z4)
```

### Benefits

✅ **Least Privilege**: Each token only has access to its specific secrets  
✅ **Token Rotation**: Rotate child tokens without changing GitHub secrets  
✅ **Audit Trail**: Vault logs all secret access  
✅ **Centralized Management**: All secrets managed in Vault  
✅ **Same as Jenkins**: Identical security model

## Setup

### 1. GitHub Secrets (Only 2 Required!)

Unlike the direct approach (16 secrets), you only need:

- `SERVICE_TOKEN` - Vault service token with access to SVU vault
- `VAULT_URL` - Vault server URL (e.g., `https://vault.example.com`)

That's it! All other credentials are retrieved from Vault.

### 2. Vault Configuration

Ensure your Vault structure matches:

```
hej0SESwEs/cicuwrl4po
  └─ toc7kawoc7: ALL_TOKEN

driy9s4uce/je0emad4ov (accessed with ALL_TOKEN)
  ├─ wr0swu5udi: ITD_TEST_TOKEN
  ├─ v0ve2regos: ZOOM_TOKEN
  └─ vepiz9pafr: AWS_ROOT_TOKEN

ql1te2icha/bruxe0az6q (accessed with ITD_TEST_TOKEN)
  ├─ DB_HOST
  ├─ DB_PORT
  ├─ DB_NAME
  ├─ DB_USER
  ├─ DB_PASSWORD
  ├─ VIMEO_ACCESS_TOKEN
  ├─ VIMEO_CLIENT_ID
  └─ VIMEO_CLIENT_SECRET

yi6pobrath/s7ohebu2ho (accessed with AWS_ROOT_TOKEN)
  ├─ thujostav9: AWS_ACCESS_KEY_ID
  └─ yuru9ibruw: AWS_SECRET_ACCESS_KEY

t1lrophebr/sestip6ecu (accessed with ZOOM_TOKEN)
  ├─ ZOOM_ACCOUNT_ID_ORG1
  ├─ ZOOM_CLIENT_ID_ORG1
  ├─ ZOOM_CLIENT_SECRET_ORG1
  ├─ ZOOM_ACCOUNT_ID_ORG2
  ├─ ZOOM_CLIENT_ID_ORG2
  ├─ ZOOM_CLIENT_SECRET_ORG2
  ├─ ZOOM_ACCOUNT_ID_ORG4
  ├─ ZOOM_CLIENT_ID_ORG4
  └─ ZOOM_CLIENT_SECRET_ORG4
```

### 3. Deploy Workflow

```bash
mkdir -p .github/workflows
cp github_actions/watermark-video-pipeline-vault.yml .github/workflows/
git add .github/workflows/
git commit -m "Add Vault-integrated watermark pipeline"
git push
```

## How It Works

### Job 1: Get Vault Credentials

1. **Install Vault CLI** on the runner
2. **Multi-step retrieval**:
   - Use SERVICE_TOKEN → get ALL_TOKEN
   - Use ALL_TOKEN → get ITD_TEST_TOKEN, ZOOM_TOKEN, AWS_ROOT_TOKEN
   - Use each token → get specific credentials
3. **Test DB connection** immediately after retrieval
4. **Save to encrypted file** with proper escaping
5. **Upload as artifact** (encrypted by GitHub)

### Job 2: Prepare Matrix

- Reads `batch-config.json`
- Generates matrix for parallel processing
- No Vault access needed

### Job 3: Process Videos (Parallel)

For each batch+date combination:

1. **Download credentials artifact**
2. **Load credentials** from file
3. **Verify DB connection**
4. **Export to environment** for scripts
5. **Run watermark pipeline** with all credentials available
6. **Cleanup credentials** after completion

### Job 4: Cleanup (Always Runs)

- **Deletes credentials artifact** immediately after all jobs complete
- Ensures no credentials persist

## Security Features

### 1. Credential Isolation

```yaml
needs: [get-vault-credentials, prepare-matrix]
```

Each processing job gets fresh credentials from artifact, not from direct Vault access.

### 2. Encrypted Storage

- Credentials saved to file with `chmod 600`
- Uploaded as GitHub artifact (encrypted at rest)
- Only accessible to jobs in the same workflow run
- Auto-deleted after 1 day (configurable)

### 3. Proper Escaping

```bash
echo "export PGPASSWORD=$(printf %q "$PGPASSWORD")" > file
```

Handles special characters safely (same as Jenkins).

### 4. Connection Testing

```bash
# Test DB connection immediately after retrieval
if PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" ...; then
    echo "✓ DB connection successful"
else
    echo "ERROR: DB connection failed"
    exit 1
fi
```

Fails fast if credentials are invalid.

### 5. Automatic Cleanup

```yaml
cleanup-credentials:
  if: always()  # Runs even if jobs fail
  steps:
    - uses: geekyeggo/delete-artifact@v5
```

Credentials artifact deleted as soon as workflow completes.

## Comparison: Direct vs Vault

| Aspect | Direct Secrets | Vault Integration |
|--------|----------------|-------------------|
| **GitHub Secrets** | 16 | 2 |
| **Credential Rotation** | Update 16 secrets | Rotate Vault tokens |
| **Audit Trail** | GitHub logs only | Vault audit logs |
| **Access Control** | All-or-nothing | Hierarchical |
| **Setup Complexity** | Simple | Moderate |
| **Maintenance** | High (many secrets) | Low (2 secrets) |
| **Security Model** | Direct access | Least privilege |
| **Same as Jenkins** | No | Yes ✓ |

## Maintenance

### Rotate Credentials

1. **Rotate in Vault** (no GitHub changes needed):
   ```bash
   vault kv put ql1te2icha/bruxe0az6q DB_PASSWORD="new_password"
   ```

2. **Rotate SERVICE_TOKEN** (only when needed):
   - Generate new token in Vault
   - Update GitHub secret
   - Revoke old token

### Add New Credentials

Add to Vault, update workflow to retrieve:

```bash
NEWCRED=$(vault kv get -address="$VAULT_ADDR" -field=NEWCRED -mount=... ...)
echo "export NEWCRED=$(printf %q "$NEWCRED")" >> "$CREDS_FILE"
```

### Monitor Access

Check Vault audit logs:

```bash
vault audit list
vault read sys/audit/file
```

## Troubleshooting

### "Failed to get ALL_TOKEN"

- Check SERVICE_TOKEN is valid
- Verify SERVICE_TOKEN has read access to `hej0SESwEs/cicuwrl4po`

### "Failed to get ITD_TEST_TOKEN"

- Check ALL_TOKEN is valid
- Verify ALL_TOKEN has access to `driy9s4uce/je0emad4ov`

### "Database connection failed"

- Check DB credentials in Vault
- Verify ITD_TEST_TOKEN has access to DB vault
- Check network connectivity to database

### "Credentials file not found"

- Check artifact upload succeeded
- Verify job dependencies (`needs:`) are correct

## Migration Path

### Option 1: Direct Migration (Recommended)

1. Keep existing Jenkins with Vault
2. Deploy this workflow
3. Test in parallel for 1 week
4. Switch to GitHub Actions
5. Decommission Jenkins

### Option 2: Hybrid Approach

1. Use Vault workflow for sensitive batches
2. Use direct secrets workflow for others
3. Gradually migrate all to Vault

## Best Practices

1. **Rotate SERVICE_TOKEN quarterly**
2. **Monitor Vault audit logs weekly**
3. **Set short TTL on child tokens** (force refresh)
4. **Use separate tokens per environment** (prod/test)
5. **Keep batch-config.json in sync** with Vault structure

## Performance

- **Vault retrieval**: ~30 seconds (one-time per workflow run)
- **Parallel processing**: 4 batches simultaneously  
- **No impact on video processing**: Credentials loaded once

## Support

For Vault-related issues:

1. Check workflow logs (Job 1: Get Vault Credentials)
2. Verify Vault paths and tokens
3. Test Vault CLI manually:
   ```bash
   vault kv get -address="$VAULT_ADDR" -field=... -mount=... ...
   ```
4. Check Vault audit logs for access denials
