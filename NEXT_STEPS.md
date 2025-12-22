# Next Steps - Firebase & QNAP Deployment

This file outlines the remaining steps to complete the full Firebase + QNAP NAS automated deployment.

---

## ✅ What's Been Completed

1. **Python Script Enhancement**
   - ✅ Firebase Storage upload functionality added
   - ✅ Version management system (Unix timestamp)
   - ✅ Comprehensive logging system
   - ✅ Data validation before upload
   - ✅ Environment variable configuration
   - ✅ Absolute path handling for cron jobs
   - ✅ Exit codes for monitoring

2. **iOS App Updates**
   - ✅ Version field added to data model
   - ✅ Version display in console logs
   - ✅ `getCurrentVersion()` method for future update checks
   - ✅ Backward compatible with old JSON format

3. **Documentation**
   - ✅ `FIREBASE_SETUP.md` - Complete Firebase setup guide
   - ✅ `NAS_DEPLOYMENT_QNAP.md` - Full QNAP deployment instructions
   - ✅ `requirements.txt` - Python dependencies
   - ✅ `.env.example` - Environment variable template
   - ✅ `CHANGELOG.md` - v1.0.0 release notes

4. **Testing**
   - ✅ Local Python script execution successful
   - ✅ JSON generation with version field verified (17.00 MB, 2,091 routes, 9,232 stops)
   - ✅ Logging system working correctly
   - ✅ Data validation passing

---

## 🔄 Next Steps (Your Tasks)

### Step 1: Firebase Project Setup (30 minutes)

Follow the complete guide in `FIREBASE_SETUP.md`:

1. **Create Firebase Project**
   - Go to https://console.firebase.google.com/
   - Create new project named "HKBusApp" (or your preferred name)
   - Disable Google Analytics (optional for this use case)

2. **Enable Firebase Storage**
   - Navigate to Build → Storage
   - Start in test mode initially
   - Select region: `asia-east2` (Hong Kong) or `asia-southeast1` (Singapore)

3. **Configure Security Rules**
   - Copy rules from `FIREBASE_SETUP.md`
   - Option 1: Public read (simpler, less secure)
   - Option 2: Authenticated read (requires Firebase Auth in iOS app)

4. **Generate Service Account Key**
   - Project Settings → Service Accounts → Generate New Private Key
   - Download JSON file (e.g., `hkbusapp-12345-firebase-adminsdk-xxxxx.json`)
   - **IMPORTANT**: Keep this file secure, never commit to git

5. **Note Your Storage Bucket Name**
   - Format: `your-project-id.appspot.com`
   - You'll need this for `.env` configuration

**Estimated Time**: 15-30 minutes

---

### Step 2: Local Testing with Firebase (15 minutes)

Test Firebase upload from your Mac before deploying to NAS:

1. **Install Firebase Dependencies**
   ```bash
   cd "/Users/davidwong/Documents/App Development/busApp"
   pip3 install -r requirements.txt
   ```

2. **Create `.env` File**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` with Your Credentials**
   ```bash
   # Use your actual paths and bucket name
   FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/your/firebase-key.json
   FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
   OUTPUT_DIRECTORY=/Users/davidwong/Documents/App Development/busApp/output
   LOG_DIRECTORY=/Users/davidwong/Documents/App Development/busApp/logs
   ```

4. **Test Upload**
   ```bash
   python3 collect_bus_data_optimized_concurrent.py
   ```

5. **Verify in Firebase Console**
   - Go to Firebase Console → Storage
   - Check that `bus_data.json` exists
   - Click file → Metadata tab
   - Verify version, generated_at, total_routes, total_stops

**Expected Output**:
```
✅ Firebase initialized: your-project-id.appspot.com
...
📤 Uploading /path/to/bus_data.json to Firebase Storage...
   Version: 1761795570
   Size: 17821361 bytes
✅ Upload successful!
   Blob path: gs://your-project-id.appspot.com/bus_data.json
☁️  Firebase: Uploaded successfully
```

**Estimated Time**: 10-15 minutes (including data collection)

---

### Step 3: QNAP NAS Deployment (45-60 minutes)

Follow the complete guide in `NAS_DEPLOYMENT_QNAP.md`:

1. **SSH into QNAP**
   ```bash
   ssh admin@your-nas-ip
   ```

2. **Create Directories**
   ```bash
   mkdir -p /share/scripts/hkbus/output
   mkdir -p /share/scripts/hkbus/logs
   mkdir -p /share/scripts/firebase
   ```

3. **Upload Files**
   - Use SCP or QNAP File Station
   - Upload: `collect_bus_data_optimized_concurrent.py`
   - Upload: `requirements.txt`
   - Upload: `.env.example`
   - Upload: Firebase service account JSON to `/share/scripts/firebase/`

4. **Install Dependencies**
   ```bash
   cd /share/scripts/hkbus
   pip3 install -r requirements.txt
   ```

5. **Configure `.env`**
   ```bash
   cp .env.example .env
   vi .env
   # Update paths for QNAP:
   # FIREBASE_SERVICE_ACCOUNT_PATH=/share/scripts/firebase/your-key.json
   # FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
   # OUTPUT_DIRECTORY=/share/scripts/hkbus/output
   # LOG_DIRECTORY=/share/scripts/hkbus/logs
   ```

6. **Secure Credentials**
   ```bash
   chmod 600 .env
   chmod 600 /share/scripts/firebase/*.json
   ```

7. **Test Run**
   ```bash
   python3 collect_bus_data_optimized_concurrent.py
   # Check exit code
   echo $?  # Should be 0 for success
   ```

8. **Setup Cron Job**
   ```bash
   crontab -e
   # Add line (every 3 days at 3 AM):
   0 3 */3 * * cd /share/scripts/hkbus && /usr/bin/python3 collect_bus_data_optimized_concurrent.py >> /share/scripts/hkbus/logs/cron_output.log 2>&1
   ```

9. **Verify Cron**
   ```bash
   crontab -l
   ```

**Estimated Time**: 45-60 minutes

---

### Step 4: iOS App Firebase Integration (Future Enhancement)

**Currently**: iOS app loads local `bus_data.json` from app bundle.

**Future Enhancement**: Download from Firebase Storage automatically.

This is optional and can be implemented later when needed. The version field is already in place to support this.

**What's Needed**:
1. Add Firebase iOS SDK to Xcode project
2. Add `GoogleService-Info.plist` to project
3. Create `FirebaseBusDataManager.swift`:
   - Check local version vs Firebase metadata version
   - Download new file if version is newer
   - Replace local file with downloaded version
4. Call download check on app launch or when user pulls to refresh

**Estimated Time**: 2-3 hours (future work)

---

## 📋 Quick Reference

### File Locations

**On Your Mac**:
- Python script: `/Users/davidwong/Documents/App Development/busApp/collect_bus_data_optimized_concurrent.py`
- Requirements: `/Users/davidwong/Documents/App Development/busApp/requirements.txt`
- Config template: `/Users/davidwong/Documents/App Development/busApp/.env.example`
- Generated JSON: `/Users/davidwong/Documents/App Development/busApp/bus_data.json`
- Logs: `/Users/davidwong/Documents/App Development/busApp/logs/`

**On QNAP NAS** (after deployment):
- Python script: `/share/scripts/hkbus/collect_bus_data_optimized_concurrent.py`
- Requirements: `/share/scripts/hkbus/requirements.txt`
- Config: `/share/scripts/hkbus/.env` (create from template)
- Firebase key: `/share/scripts/firebase/your-key.json`
- Output: `/share/scripts/hkbus/output/bus_data.json`
- Logs: `/share/scripts/hkbus/logs/`

**Firebase Storage**:
- File: `gs://your-project-id.appspot.com/bus_data.json`
- Access: Firebase Console → Storage

---

## 🔧 Troubleshooting

### Common Issues

1. **"Module not found" error**
   - Solution: Install dependencies with `pip3 install -r requirements.txt`

2. **"Permission denied" for Firebase**
   - Solution: Check service account key path in `.env` is correct
   - Solution: Verify key file has correct permissions (chmod 600)

3. **Cron job doesn't run**
   - Solution: Use full paths in cron command (`/usr/bin/python3`)
   - Solution: Check cron service status (`/etc/init.d/crond status`)

4. **Upload fails but collection succeeds**
   - Script will exit with code 1 (upload failed)
   - JSON still saved locally at `output/bus_data.json`
   - Check Firebase credentials and network connectivity

### Getting Help

- Check logs: `tail -f /share/scripts/hkbus/logs/bus_data_collection_*.log`
- Check cron output: `tail -f /share/scripts/hkbus/logs/cron_output.log`
- Verify Firebase: https://console.firebase.google.com/
- Python script logs all errors with detailed messages

---

## 📊 Success Criteria

You'll know everything is working when:

- ✅ Local test run completes successfully (exit code 0)
- ✅ `bus_data.json` appears in Firebase Storage
- ✅ Firebase metadata shows correct version, routes, and stops
- ✅ QNAP test run succeeds
- ✅ Cron job configured and visible in `crontab -l`
- ✅ Logs show successful executions
- ✅ No error emails/notifications

---

## 📅 Timeline Summary

- **Firebase Setup**: 30 minutes
- **Local Testing**: 15 minutes
- **QNAP Deployment**: 60 minutes
- **Total**: ~2 hours

After this, the system will run automatically every 3 days with no manual intervention required!

---

## 💡 Tips

1. **Test locally first**: Always verify Firebase upload works on your Mac before deploying to NAS
2. **Keep credentials secure**: Never commit `.env` or Firebase keys to git
3. **Monitor first few runs**: Check logs after first 2-3 cron executions
4. **Setup log rotation**: Use the rotation script in `NAS_DEPLOYMENT_QNAP.md` to prevent disk space issues
5. **Email notifications**: Optional but helpful for monitoring failures

---

**Good luck with the deployment! 🚀**

If you encounter any issues, refer to the detailed guides:
- `FIREBASE_SETUP.md` for Firebase-specific questions
- `NAS_DEPLOYMENT_QNAP.md` for QNAP-specific questions
