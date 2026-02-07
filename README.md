# Watermark Video Pipeline - GitHub Actions

This directory contains GitHub Actions workflows and scripts for the watermark video pipeline, migrated from Jenkins.

## Structure

```
github_actions/
├── watermark-video-pipeline.yml       # Single batch workflow (manual trigger)
├── watermark-video-pipeline-multi.yml # Multiple batches workflow (auto + manual)
├── watermark-video-pipeline-vault.yml # Multiple batches with Vault integration ⭐
├── batch-config.json                  # Batch configuration file
├── scripts/
│   ├── watermark_pipeline.sh          # Main pipeline script
│   ├── s3_tool                        # S3 operations utility
│   ├── s3_tool_simple.py             # Simplified S3 tool
│   ├── vemio_upload                   # Vimeo upload script
│   ├── watermark                      # Video watermarking script
│   ├── zoomd                          # Zoom video download
│   └── zoom_attendance                # Attendance processing
├── requirements.txt                   # Python dependencies
├── README.md                          # This file
├── QUICK_START.md                    # 5-minute setup guide
└── VAULT_INTEGRATION.md              # Vault security documentation
```

## Three Workflow Options

### Option 1: Direct Secrets (watermark-video-pipeline-multi.yml)
- **Setup**: Simple (configure 16 GitHub secrets)
- **Security**: Good (GitHub secrets encrypted at rest)
- **Maintenance**: High (must update 16 secrets for rotation)
- **Best for**: Quick setup, small teams

### Option 2: Vault Integration (watermark-video-pipeline-vault.yml) ⭐ **Enterprise**
- **Setup**: Moderate (configure 2 GitHub secrets + Vault)
- **Security**: Excellent (multi-level token hierarchy)
- **Maintenance**: Low (rotate in Vault, not GitHub)
- **Best for**: Enterprise, same security as Jenkins

### Option 3: Single Batch (watermark-video-pipeline.yml)
- **Setup**: Simple
- **Security**: Good
- **Maintenance**: High
- **Best for**: Testing, one-off processing

## Setup

### 1. Copy Workflows to GitHub

Move the workflow files to your repository's workflows directory:

```bash
mkdir -p .github/workflows
cp github_actions/watermark-video-pipeline-multi.yml .github/workflows/
# Optional: Also copy single batch workflow
cp github_actions/watermark-video-pipeline.yml .github/workflows/
```

### 2. Configure Batch Settings

Edit `github_actions/batch-config.json` to enable/disable batches:

```json
{
  "batches": [
    {
      "course_id": "2",
      "batch_name": "itd_devops_dec_2025",
      "itd_zoom_id": "20251215",
      "batch_id": "40",
      "zoom_id": "85908177452",
      "zoom_account": "Z2",
      "zoom_email": "itdefined.org2@gmail.com",
      "parent_topic_param": "DEVOPS_DEC_2025_PARENT_TOPIC",
      "enabled": true  ← Set to true to enable, false to disable
    }
  ]
}
```

**Important:** Only batches with `"enabled": true` will be processed automatically.

### 3. Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

**AWS Credentials:**
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key

**Database Credentials:**
- `DB_HOST` - PostgreSQL host
- `DB_PORT` - PostgreSQL port (e.g., 5432)
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password

**Vimeo Credentials:**
- `VIMEO_ACCESS_TOKEN` - Vimeo API access token
- `VIMEO_CLIENT_ID` - Vimeo client ID
- `VIMEO_CLIENT_SECRET` - Vimeo client secret

**Zoom Credentials (per account):**
- `ZOOM_Z2_ACCOUNT_ID` - Zoom Z2 account ID
- `ZOOM_Z2_CLIENT_ID` - Zoom Z2 client ID
- `ZOOM_Z2_CLIENT_SECRET` - Zoom Z2 client secret
- `ZOOM_Z4_ACCOUNT_ID` - Zoom Z4 account ID
- `ZOOM_Z4_CLIENT_ID` - Zoom Z4 client ID
- `ZOOM_Z4_CLIENT_SECRET` - Zoom Z4 client secret

### 4. Make Scripts Executable

```bash
chmod +x github_actions/scripts/*
```

## Usage

### Automatic Execution (Scheduled)

The **multi-batch workflow** runs automatically every 15 minutes during class hours:
- IST 10:00-14:00 (morning classes)
- IST 19:00-21:00 (evening classes)

It will:
1. Process only **enabled** batches from `batch-config.json`
2. Use today's date as class date
3. Process all batches in parallel (up to 4 at once)

### Manual Execution - Multiple Batches

1. Go to your GitHub repository → Actions tab
2. Select "Watermark Video Pipeline - Multiple Batches"
3. Click "Run workflow"
4. Fill in parameters:
   - **class_date_list**: Comma-separated dates (e.g., `20260205,20260206`)
   - **Parent topics**: One for each course type
   - Boolean flags for processing options
5. Click "Run workflow"

**All enabled batches** will be processed for each date you specify.

### Manual Execution - Single Batch

For processing one specific batch:

For processing one specific batch:

1. Go to Actions → "Watermark Video Pipeline" (single)
2. Click "Run workflow"
3. Fill in ALL parameters manually for the specific batch
4. Click "Run workflow"

## Key Improvements Over Jenkins

### 1. **Environment Variables Set at Job Level**
```yaml
env:
  PGHOST: ${{ secrets.DB_HOST }}
  VIMEO_ACCESS_TOKEN: ${{ secrets.VIMEO_ACCESS_TOKEN }}
  # ... all secrets available to all steps
```

**Benefits:**
- ✅ Cleaner - no repeated `Setup Environment` steps
- ✅ Safer - secrets never passed as command arguments
- ✅ More efficient - set once, use everywhere
- ✅ Direct access via `$PGHOST`, `$VIMEO_ACCESS_TOKEN` in scripts

### 2. **Dynamic Matrix for Parallel Processing**
Like Jenkins' `parallel stagesMap`, but better:

```yaml
strategy:
  max-parallel: 4
  fail-fast: false
  matrix: ${{ fromJson(needs.prepare.outputs.matrix) }}
```

**Benefits:**
- ✅ Automatic job creation from `batch-config.json`
- ✅ Visual progress for each batch+date combination
- ✅ One failure doesn't stop others (`fail-fast: false`)
- ✅ Configurable parallelism

### 3. **Centralized Batch Configuration**

Edit `batch-config.json` to:
- Add new batches
- Enable/disable batches
- Update Zoom IDs, emails, etc.

No need to modify the workflow YAML!

## Comparison: Jenkins vs GitHub Actions

| Feature | Jenkins | GitHub Actions |
|---------|---------|----------------|
| **Environment Setup** | Multiple steps | Single `env` block |
| **Secrets** | Vault retrieval | Direct from GitHub Secrets |
| **Parallel Processing** | Groovy `parallel` | Matrix strategy |
| **Batch Config** | Hardcoded in Jenkinsfile | External JSON file |
| **Scheduling** | Cron syntax | Cron syntax (same) |
| **Infrastructure** | Self-hosted Jenkins | GitHub-hosted |
| **Maintenance** | High | None |
| **Cost** | Server costs | Free (public repos) |
| **Visibility** | Jenkins UI | GitHub Actions UI |

## Configuration Files

### batch-config.json

```json
{
  "batches": [
    {
      "course_id": "2",                          // Course ID in database
      "batch_name": "itd_devops_dec_2025",       // Used for S3 paths and Vimeo folders
      "itd_zoom_id": "20251215",                 // ITD webinar ID
      "batch_id": "40",                          // Batch ID in database
      "zoom_id": "85908177452",                  // Zoom meeting ID
      "zoom_account": "Z2",                      // Z2 or Z4
      "zoom_email": "itdefined.org2@gmail.com",  // Zoom account email
      "parent_topic_param": "DEVOPS_DEC_2025_PARENT_TOPIC",  // Parent topic parameter name
      "enabled": true                            // Enable/disable this batch
    }
  ]
}
```

**To add a new batch:**
1. Copy an existing batch object
2. Update all fields
3. Set `"enabled": true`
4. Commit and push

**To disable a batch temporarily:**
1. Set `"enabled": false`
2. Commit and push

### Workflow Steps

The pipeline performs the following steps:

1. **Setup Environment**
   - Checkout code
   - Setup Python 3.11
   - Install system dependencies (ffmpeg, postgresql-client)
   - Install Python packages (boto3, vimeo, psycopg2-binary)
   - Configure AWS credentials
   - Setup database environment variables

2. **Download Video**
   - Downloads video from Zoom or S3 (based on `use_s3_original` flag)
   - Displays original video size

3. **Backup to S3**
   - Uploads original video to backup S3 bucket

4. **Apply Watermark**
   - Applies watermark to the video using ffmpeg
   - Displays watermarked video size

5. **Upload Watermarked Video**
   - Uploads to S3 watermark bucket
   - Uploads to Vimeo (into course-specific folder)
   - Extracts Vimeo video ID

6. **Update Database**
   - Creates or updates class notes in `course_trainingmaterial` table
   - Sets `video_source_from` (vimeo/aws_s3)
   - Sets `vimeo_video_id` if available

7. **Cleanup**
   - Removes local video files (if enabled)
   - Uploads logs if workflow fails

## Parameters Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| bucket_name | string | Yes | class-recordings-itdefined | S3 bucket for watermarked videos |
| batch_name | string | Yes | - | Batch identifier |
| itd_webinar_id | string | Yes | - | ITD webinar ID |
| zoom_account | string | Yes | - | Zoom account |
| topic | string | Yes | - | Class topic |
| course_id | string | Yes | - | Course ID |
| batch_id | string | Yes | - | Batch ID |
| parent_topic | string | Yes | - | Parent topic |
| webinar_id | string | Yes | - | Webinar ID |
| webinar_email | string | Yes | - | Webinar email |
| class_date | string | Yes | - | Class date (YYYYMMDD) |
| s3_delete_original | boolean | No | false | Delete from original S3 bucket |
| delete_local_videos | boolean | No | true | Delete local videos after processing |
| delete_attendance | boolean | No | false | Delete existing attendance |
| delete_class | boolean | No | false | Delete existing class notes |
| s3_delete_watermark | boolean | No | false | Delete from watermark S3 bucket |
| use_s3_original | boolean | No | false | Use original video from S3 |
| vemio_delete | boolean | No | false | Delete existing Vimeo video |

## Features

### Compared to Jenkins

✅ **Advantages:**
- No infrastructure maintenance required
- Better visibility with GitHub UI
- Integrated with GitHub repository
- Free for public repositories
- Automatic cleanup and artifact management
- Better secrets management
- Easier to version control

⚠️ **Considerations:**
- GitHub Actions has execution time limits (6 hours for free tier)
- Storage limits for artifacts
- May need self-hosted runner for very large videos

### Video Size Tracking

The pipeline now displays file sizes at key steps:
- Original video download: `Downloaded video from S3: ... (size: 1.2GiB)`
- After watermarking: `Watermark applied successfully (size: 1.3GiB)`
- Watermarked video found: `Watermarked video found locally (size: 1.3GiB)`

### Vimeo Folder Management

- Automatically creates Vimeo folder if it doesn't exist
- Verifies video is added to the correct folder
- Retries folder assignment if initial attempt fails
- Supports both new uploads and existing video detection

### Database Integration

Updates `course_trainingmaterial` table with:
- `video_source_from` (vimeo or aws_s3)
- `vimeo_video_id` (Vimeo video ID)
- `recording_link` (video filename)
- `date_of_training` (class date)

## Troubleshooting

### Workflow Fails

1. Check the workflow logs in GitHub Actions
2. Look for error messages in the "Run Watermark Video Pipeline" step
3. Failed runs automatically upload logs as artifacts

### Video Not in Vimeo Folder

The script automatically:
- Verifies video is in the folder after upload
- Retries folder assignment if needed
- Logs warnings if folder assignment fails

### Database Connection Issues

Verify secrets are correctly set:
```bash
# Check if secrets are accessible (don't print actual values)
echo "DB_HOST is set: ${{ secrets.DB_HOST != '' }}"
```

## Migration from Jenkins

To migrate from Jenkins to GitHub Actions:

1. Copy this directory to your repository
2. Move the workflow file to `.github/workflows/`
3. Configure all GitHub secrets
4. Test with a single video first
5. Update any external scripts/systems that trigger the Jenkins job

## Support

For issues or questions:
1. Check the workflow logs in GitHub Actions
2. Review the script output in the logs
3. Check artifact uploads for additional logs
