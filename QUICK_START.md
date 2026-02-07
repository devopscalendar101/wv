# Quick Start Guide - GitHub Actions Migration

## 📋 Pre-Migration Checklist

- [ ] Copy workflows to `.github/workflows/`
- [ ] Configure `batch-config.json` 
- [ ] Add all secrets to GitHub repository
- [ ] Test with one batch first
- [ ] Enable automatic scheduling

## 🚀 Quick Setup (5 minutes)

```bash
# 1. Copy files
mkdir -p .github/workflows
cp github_actions/watermark-video-pipeline-multi.yml .github/workflows/
cp github_actions/batch-config.json ./

# 2. Configure batches
vim github_actions/batch-config.json  # Enable/disable batches

# 3. Commit
git add .github/workflows/ github_actions/
git commit -m "Add GitHub Actions watermark pipeline"
git push
```

## 🔐 Required Secrets

Go to GitHub → Settings → Secrets and variables → Actions → New repository secret

### AWS (2 secrets)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Database (5 secrets)
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

### Vimeo (3 secrets)
- `VIMEO_ACCESS_TOKEN`
- `VIMEO_CLIENT_ID`
- `VIMEO_CLIENT_SECRET`

### Zoom (6 secrets - 3 per account)
- `ZOOM_Z2_ACCOUNT_ID`
- `ZOOM_Z2_CLIENT_ID`
- `ZOOM_Z2_CLIENT_SECRET`
- `ZOOM_Z4_ACCOUNT_ID`
- `ZOOM_Z4_CLIENT_ID`
- `ZOOM_Z4_CLIENT_SECRET`

**Total: 16 secrets**

## 🎯 Common Tasks

### Add a New Batch
Edit `github_actions/batch-config.json`:
```json
{
  "course_id": "XX",
  "batch_name": "itd_course_month_year",
  "itd_zoom_id": "YYYYMMDD",
  "batch_id": "XX",
  "zoom_id": "XXXXXXXXXXX",
  "zoom_account": "Z2 or Z4",
  "zoom_email": "itdefined.orgX@gmail.com",
  "parent_topic_param": "COURSE_NAME_PARENT_TOPIC",
  "enabled": true
}
```

### Temporarily Disable a Batch
```json
"enabled": false
```

### Process Old Videos
Go to Actions → Run workflow manually:
- Set `class_date_list`: `20260101,20260102,20260103`
- All enabled batches will be processed for those dates

### Change Schedule
Edit `.github/workflows/watermark-video-pipeline-multi.yml`:
```yaml
schedule:
  - cron: '*/15 4-8,13-15 * * *'  # Every 15 min, IST 10:00-14:00 & 19:00-21:00
```

## 📊 Monitoring

### View Running Jobs
GitHub → Actions → Click on running workflow

### Check Logs
Click on specific job (e.g., `itd_devops_dec_2025_20260205`)

### Download Logs (if failed)
Failed jobs automatically upload logs as artifacts:
- Go to failed workflow
- Scroll down to "Artifacts"
- Download `logs-{batch_name}-{date}.zip`

## 🔄 Migration from Jenkins

### What Changes?
| Item | Jenkins | GitHub Actions |
|------|---------|----------------|
| Trigger | Jenkins UI / Cron | GitHub Actions UI / Cron |
| Secrets | Vault | GitHub Secrets |
| Logs | Jenkins console | GitHub Actions UI |
| Parallel | Groovy script | Matrix strategy |
| Config | Jenkinsfile | JSON + YAML |

### What Stays the Same?
- ✅ All scripts (s3wm_update, vemio_upload, etc.)
- ✅ Processing logic
- ✅ Database updates
- ✅ S3 uploads
- ✅ Vimeo uploads
- ✅ Cron schedule

### Migration Steps
1. Keep Jenkins running
2. Deploy GitHub Actions
3. Test with one batch for a few days
4. Enable all batches
5. Monitor for 1 week
6. Disable Jenkins job
7. Decommission Jenkins (optional)

## ❓ FAQ

**Q: Can I run both Jenkins and GitHub Actions together?**
A: Yes! Both can run safely. They won't conflict.

**Q: What if I need to process yesterday's videos?**
A: Run workflow manually with `class_date_list: YYYYMMDD` (yesterday's date)

**Q: How do I know if a video was processed?**
A: Check the workflow run. Green = success. Click on job for details.

**Q: Can I process multiple dates at once?**
A: Yes! Use comma-separated: `class_date_list: 20260201,20260202,20260203`

**Q: What happens if one batch fails?**
A: Others continue processing (`fail-fast: false`). Check logs for the failed one.

**Q: How do I test without affecting production?**
A: Set `delete_class: false`, `vemio_delete: false`, test with old date.

**Q: Do I need to maintain Jenkins server anymore?**
A: No! GitHub Actions is fully managed. No infrastructure needed.

## 🆘 Troubleshooting

### Database Connection Failed
- Check secrets are set correctly
- Test connection: Actions → Run workflow → Check "Test Database Connection" step

### Video Not Found on Zoom
- Check `zoom_id` and `zoom_account` in batch-config.json
- Verify Zoom secrets are correct
- Check if video exists on Zoom

### S3 Upload Failed
- Verify AWS credentials
- Check bucket permissions
- Check AWS_REGION is correct

### Vimeo Upload Failed
- Check Vimeo credentials
- Verify Vimeo folder exists (auto-created now)
- Check Vimeo storage quota

### Workflow Not Running Automatically
- Check cron schedule syntax
- Verify workflow file is in `.github/workflows/`
- Check Actions is enabled for the repo

## 📞 Support

For issues:
1. Check workflow logs
2. Download artifacts (if available)
3. Review this quick start guide
4. Check main README.md for detailed documentation
