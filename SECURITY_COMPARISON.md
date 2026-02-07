# GitHub Actions vs Jenkins - Security Comparison

## Credentials Management Approaches

### Jenkins (Current)

```groovy
environment {
    SERVICE_TOKEN = credentials('SERVICE_TOKEN')  // From Jenkins
    VAULT_ADDR = credentials('VAULT_URL')
}

stages {
    stage('Get Vault Tokens') {
        // Multi-step Vault retrieval
        // ALL_TOKEN → ITD_TEST_TOKEN, ZOOM_TOKEN, AWS_ROOT_TOKEN
        // Each token → specific credentials
        // Save to /tmp/vault_creds_${BUILD_NUMBER}.env
    }
    
    stage('Parallel Batch Processing') {
        parallel stagesMap  // Load credentials from file
    }
}
```

**Secrets Required**: 2 (SERVICE_TOKEN, VAULT_URL)  
**Security Model**: Multi-level Vault hierarchy  
**Maintenance**: Low (rotate in Vault)

---

## GitHub Actions - Three Options

### Option 1: Direct Secrets

```yaml
env:
  PGHOST: ${{ secrets.DB_HOST }}
  VIMEO_ACCESS_TOKEN: ${{ secrets.VIMEO_ACCESS_TOKEN }}
  # ... all 16 secrets directly in environment
```

**Secrets Required**: 16  
**Security Model**: Direct GitHub secrets  
**Maintenance**: High (update 16 secrets)

✅ Simplest setup  
✅ No Vault needed  
❌ Many secrets to manage  
❌ Different from Jenkins

### Option 2: Vault Integration (Recommended for Enterprise)

```yaml
jobs:
  get-vault-credentials:
    # Multi-step Vault retrieval (same as Jenkins)
    # Upload credentials as encrypted artifact
  
  process-videos:
    needs: get-vault-credentials
    # Download and use credentials
    # Auto-cleanup after use
```

**Secrets Required**: 2 (SERVICE_TOKEN, VAULT_URL)  
**Security Model**: Same multi-level Vault hierarchy as Jenkins  
**Maintenance**: Low (rotate in Vault)

✅ Identical to Jenkins security  
✅ Least privilege access  
✅ Centralized Vault management  
✅ Automatic cleanup  
⚠️ Requires Vault access from GitHub runners

### Option 3: Single Batch (Testing Only)

Manual workflow for one batch at a time.

---

## Detailed Comparison

| Feature | Jenkins | GHA Option 1<br>(Direct) | GHA Option 2<br>(Vault) |
|---------|---------|----------|----------|
| **GitHub Secrets** | 0 (uses Jenkins) | 16 | 2 |
| **Vault Integration** | ✅ Yes | ❌ No | ✅ Yes |
| **Token Hierarchy** | ✅ Multi-level | ❌ Single level | ✅ Multi-level |
| **Credential Rotation** | Vault only | Update 16 secrets | Vault only |
| **Audit Trail** | Vault logs | GitHub logs | Vault + GitHub logs |
| **Setup Time** | N/A (existing) | 10 minutes | 15 minutes |
| **Maintenance** | Low | High | Low |
| **Infrastructure** | Self-hosted | GitHub-hosted | GitHub-hosted |
| **Cost** | Server costs | Free (public) | Free (public) |

---

## Security Deep Dive

### Vault Token Flow

```
                    Jenkins/GitHub Secret
                            │
                      SERVICE_TOKEN
                            │
                            ↓
                    Vault: SVU/cicuwrl4po
                            │
                       ALL_TOKEN
                            │
                ┌───────────┼───────────┐
                ↓           ↓           ↓
         ITD_TEST_TOKEN  AWS_ROOT   ZOOM_TOKEN
                │         TOKEN         │
                ↓           ↓           ↓
           DB + Vimeo      AWS      Z1/Z2/Z4
```

**Principle**: Each token has minimal required permissions

### Credential Lifecycle

#### Jenkins
1. Retrieve from Vault → Save to `/tmp/vault_creds_${BUILD_NUMBER}.env`
2. Load in parallel stages
3. Auto-cleanup when build completes

#### GitHub Actions (Vault Option)
1. Retrieve from Vault → Save to `$RUNNER_TEMP/vault_creds_${RUN_ID}.env`
2. Upload as encrypted artifact
3. Download in parallel jobs
4. **Auto-delete artifact when workflow completes**

**Key Difference**: GitHub Actions uses artifacts (encrypted by GitHub) instead of local files

---

## Migration Recommendations

### If You Have Vault Setup → Use Option 2 (Vault Integration)

**Pros:**
- ✅ **Identical security model** to Jenkins
- ✅ **No secret sprawl** (only 2 secrets)
- ✅ **Easy credential rotation**
- ✅ **Existing Vault policies work**
- ✅ **Centralized audit logs**

**Cons:**
- ⚠️ GitHub runners need network access to Vault
- ⚠️ Slightly more complex setup

**Migration Steps:**
```bash
# 1. Add only 2 secrets to GitHub
SERVICE_TOKEN: <same token from Jenkins>
VAULT_URL: https://vault.example.com

# 2. Deploy workflow
cp github_actions/watermark-video-pipeline-vault.yml .github/workflows/

# 3. Test
# 4. Run in parallel with Jenkins for 1 week
# 5. Switch over
```

### If You Want Simple Setup → Use Option 1 (Direct Secrets)

**Pros:**
- ✅ **Fastest setup** (10 minutes)
- ✅ **No external dependencies**
- ✅ **Works anywhere**

**Cons:**
- ❌ **16 secrets to manage**
- ❌ **Credential rotation = update all secrets**
- ❌ **Different from Jenkins**

**Migration Steps:**
```bash
# 1. Add 16 secrets to GitHub (extract from Vault)
DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD,
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
VIMEO_ACCESS_TOKEN, VIMEO_CLIENT_ID, VIMEO_CLIENT_SECRET,
ZOOM_Z2_ACCOUNT_ID, ZOOM_Z2_CLIENT_ID, ZOOM_Z2_CLIENT_SECRET,
ZOOM_Z4_ACCOUNT_ID, ZOOM_Z4_CLIENT_ID, ZOOM_Z4_CLIENT_SECRET

# 2. Deploy workflow
cp github_actions/watermark-video-pipeline-multi.yml .github/workflows/

# 3. Test and run
```

---

## Security Best Practices

### Both Options

1. **Use repository secrets**, not environment secrets
2. **Enable branch protection** on main branch
3. **Require pull request reviews** for workflow changes
4. **Enable dependabot** for action updates
5. **Set short artifact retention** (1 day for credentials)

### Vault Option Only

6. **Use short TTL tokens** where possible
7. **Rotate SERVICE_TOKEN quarterly**
8. **Monitor Vault audit logs**
9. **Use separate tokens** for prod/test
10. **Test Vault connectivity** in workflow

### Direct Secrets Only

6. **Rotate all secrets quarterly**
7. **Use secret scanning** (GitHub Advanced Security)
8. **Limit repository access**
9. **Monitor GitHub audit logs**
10. **Document secret purpose**

---

## Cost Analysis

### Jenkins (Current)

- **Infrastructure**: EC2 instance ($50-200/month)
- **Maintenance**: 2-4 hours/month
- **Vault**: Existing (sunk cost)
- **Total**: ~$300/month (including labor)

### GitHub Actions (Either Option)

- **Infrastructure**: $0 (GitHub-hosted)
- **Minutes**: Free for public repos, ~$0.008/minute for private
- **Storage**: Minimal (artifacts auto-deleted)
- **Maintenance**: 0-1 hours/month
- **Total**: $0-50/month

**Savings**: ~$250/month + time savings

---

## Recommendation Matrix

| Your Situation | Recommendation | Reasoning |
|----------------|----------------|-----------|
| Already using Vault | **Option 2 (Vault)** | Maintain security consistency |
| Security-first organization | **Option 2 (Vault)** | Best security practices |
| Small team, quick start | **Option 1 (Direct)** | Simplicity over complexity |
| Testing/POC | **Option 1 (Direct)** | Fastest to deploy |
| Enterprise compliance | **Option 2 (Vault)** | Audit trail requirements |
| No Vault, don't want it | **Option 1 (Direct)** | No external dependencies |

---

## Frequently Asked Questions

**Q: Can I migrate from Option 1 to Option 2 later?**  
A: Yes! Just:
1. Set up Vault structure
2. Add 2 secrets (SERVICE_TOKEN, VAULT_URL)
3. Switch workflow file
4. Delete 16 old secrets

**Q: Which is more secure: Option 1 or Option 2?**  
A: Option 2 (Vault) provides defense in depth with hierarchical tokens and centralized audit logs.

**Q: Do I need to maintain Vault if I use Option 2?**  
A: If you already have Vault (like Jenkins), no additional maintenance needed.

**Q: Can I use both options for different batches?**  
A: Not recommended. Choose one approach for consistency.

**Q: What if Vault is down?**  
A: Option 2 workflow will fail. Have Vault HA setup for production.

**Q: How long does Vault retrieval take?**  
A: ~30 seconds one-time per workflow run (not per batch).

**Q: Are credentials logged?**  
A: No. Both options use `set +x` and proper escaping to prevent logging.

---

## Summary

### Choose Option 1 (Direct Secrets) if:
- ✅ You want the fastest setup
- ✅ You don't have Vault
- ✅ You have a small team
- ✅ Credential rotation is infrequent

### Choose Option 2 (Vault Integration) if:
- ✅ You already use Vault (like Jenkins)
- ✅ You want enterprise-grade security
- ✅ You need consistent security across systems
- ✅ You have compliance requirements
- ✅ **You want to match Jenkins exactly** ⭐

For most teams migrating from Jenkins → **Option 2 (Vault)** is recommended to maintain security consistency.
