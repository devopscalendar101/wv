# Watermark Video Pipeline - GitHub Actions

This repository contains only the GitHub Actions workflow for the watermark video pipeline.

## Source Code

The actual source code (scripts, configs, etc.) is stored in the private repository:
- [devopscalendar101/wv_source](https://github.com/devopscalendar101/wv_source) (private)

The workflow automatically clones the private repo using the `PAT` secret.

## Workflow

- **File**: [`.github/workflows/watermark-video-pipeline-vault.yml`](.github/workflows/watermark-video-pipeline-vault.yml)
- **Triggers**: Manual dispatch, Scheduled (cron)
- **Concurrency**: One run at a time (queued)

## Required Secrets

| Secret | Description |
|--------|-------------|
| `PAT` | GitHub Personal Access Token with `repo` scope to access private wv_source repo |
| `SCRIPTS_ENCRYPTION_KEY` | Key to decrypt encrypted scripts from wv_source |
| `SERVICE_TOKEN` | HashiCorp Vault service token |
| `VAULT_URL` | Vault server URL |
| `ITD_USER` | ITD platform username |
| `ITD_PASS` | ITD platform password |

## Pipeline Flow

1. **Get Vault credentials** → Authenticate and retrieve all service credentials
2. **Prepare matrix** → Read batch config from wv_source
3. **Process videos** (parallel) → Download, watermark, upload to S3/Vimeo, update DB
4. **Cleanup** → Remove temporary credentials

## Security

- All sensitive source code in private repo
- Scripts encrypted at rest in wv_source
- Credentials fetched from HashiCorp Vault at runtime
- No secrets in workflow YAML
