# QNAP NAS Deployment Guide

Complete guide for deploying the HK Bus Data Collection script on QNAP NAS with automated Firebase uploads.

---

## Prerequisites

Before starting, ensure you have:

- [ ] QNAP NAS with QTS operating system
- [ ] SSH access to QNAP (admin privileges)
- [ ] Python 3 installed on QNAP
- [ ] Firebase project set up (see `FIREBASE_SETUP.md`)
- [ ] Firebase service account JSON key downloaded

---

## Step 1: Access QNAP via SSH

### Enable SSH on QNAP

1. Log into QNAP web interface
2. Go to **Control Panel** → **Network & File Services** → **Telnet / SSH**
3. Enable **"Allow SSH connection"**
4. Note the SSH port (default: 22)

### Connect via SSH

```bash
ssh admin@your-nas-ip
# Enter admin password when prompted
```

---

## Step 2: Check Python Installation

```bash
# Check Python version (should be 3.7+)
python3 --version

# Check pip
pip3 --version
```

**If Python 3 is not installed:**

QNAP usually has Python 3 pre-installed. If not:

1. Go to QNAP **App Center**
2. Search for **"Python 3"**
3. Install the official Python 3 package

---

## Step 3: Create Project Directory

```bash
# Create directory structure
mkdir -p /share/scripts/hkbus
mkdir -p /share/scripts/hkbus/output
mkdir -p /share/scripts/hkbus/logs
mkdir -p /share/scripts/firebase

# Navigate to project directory
cd /share/scripts/hkbus
```

**Path explanation:**
- `/share/scripts/hkbus` - Main project directory
- `/share/scripts/hkbus/output` - Generated JSON files
- `/share/scripts/hkbus/logs` - Execution logs
- `/share/scripts/firebase` - Firebase credentials (secure location)

---

## Step 4: Upload Files to QNAP

### Option A: Using SCP (from your Mac)

```bash
# Upload Python script
scp collect_bus_data_optimized_concurrent.py admin@your-nas-ip:/share/scripts/hkbus/

# Upload requirements.txt
scp requirements.txt admin@your-nas-ip:/share/scripts/hkbus/

# Upload .env.example as template
scp .env.example admin@your-nas-ip:/share/scripts/hkbus/

# Upload Firebase service account key
scp path/to/your-firebase-key.json admin@your-nas-ip:/share/scripts/firebase/hkbus-service-account.json
```

### Option B: Using QNAP File Station

1. Open **File Station** in QNAP web interface
2. Navigate to `/share/scripts/hkbus`
3. Click **Upload** and select files:
   - `collect_bus_data_optimized_concurrent.py`
   - `requirements.txt`
   - `.env.example`
4. Navigate to `/share/scripts/firebase`
5. Upload your Firebase service account JSON file

---

## Step 5: Install Python Dependencies

```bash
cd /share/scripts/hkbus

# Install dependencies
pip3 install -r requirements.txt

# Verify installation
pip3 list | grep -E "requests|firebase-admin|python-dotenv"
```

**Expected output:**
```
firebase-admin          6.3.0
python-dotenv           1.0.0
requests                2.31.0
```

**If installation fails:**

Try installing with user flag:
```bash
pip3 install --user -r requirements.txt
```

---

## Step 6: Configure Environment Variables

### Create .env file

```bash
cd /share/scripts/hkbus

# Copy template
cp .env.example .env

# Edit with vi or nano
vi .env
```

**Add your actual values:**

```env
# Firebase service account key path (absolute path)
FIREBASE_SERVICE_ACCOUNT_PATH=/share/scripts/firebase/hkbus-service-account.json

# Firebase Storage bucket (from Firebase Console)
FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com

# Output directory
OUTPUT_DIRECTORY=/share/scripts/hkbus/output

# Log directory
LOG_DIRECTORY=/share/scripts/hkbus/logs
```

**Save and exit:**
- In vi: Press `ESC`, type `:wq`, press Enter
- In nano: Press `CTRL+X`, then `Y`, then Enter

### Secure the .env file

```bash
# Set restrictive permissions
chmod 600 .env
chmod 600 /share/scripts/firebase/hkbus-service-account.json
```

---

## Step 7: Test the Script

### Manual Test Run

```bash
cd /share/scripts/hkbus

# Run script
python3 collect_bus_data_optimized_concurrent.py
```

**Expected output:**

```
2025-10-30 15:30:00 [INFO] Logging initialized: /share/scripts/hkbus/logs/bus_data_collection_20251030_153000.log
======================================================================
2025-10-30 15:30:01 [INFO] 🚀 Hong Kong Bus Data Collection with Firebase Upload
2025-10-30 15:30:01 [INFO] ⚡ KMB: Batch API + CTB: Concurrent + Firebase Storage
======================================================================
2025-10-30 15:30:01 [INFO] ✅ Firebase initialized: your-project-id.appspot.com

🚀 Optimized Concurrent Bus Data Collector initialized
📊 Strategy: KMB batch + CTB concurrent

🏎️  KMB Ultra-Fast Collection (3 API calls)
==================================================
1️⃣ Fetching ALL KMB stops...
✅ Got 6,XXX stops in X.XXs
...
[Full execution output]
...
2025-10-30 15:35:45 [INFO] 🎉 Collection Complete in 345.67 seconds!
2025-10-30 15:35:45 [INFO] 📄 Local file: /share/scripts/hkbus/output/bus_data.json
2025-10-30 15:35:45 [INFO] ☁️  Firebase: Uploaded successfully
2025-10-30 15:35:45 [INFO] ✅ Ready for iOS app integration!
```

### Verify Output Files

```bash
# Check generated JSON
ls -lh /share/scripts/hkbus/output/

# Check log file
ls -lh /share/scripts/hkbus/logs/
tail -f /share/scripts/hkbus/logs/bus_data_collection_*.log
```

### Check Exit Code

```bash
echo $?
```

**Exit codes:**
- `0` = Success
- `1` = Firebase upload failed (data collected but not uploaded)
- `2` = Data collection failed
- `130` = User interrupted (Ctrl+C)

---

## Step 8: Setup Cron Job (Every 3 Days)

### Edit Crontab

```bash
# Open crontab editor
crontab -e
```

### Add Cron Job Entry

**Run every 3 days at 3:00 AM (Monday, Thursday, Sunday):**

```bash
# HK Bus Data Collection - Every 3 days at 3 AM
0 3 */3 * * cd /share/scripts/hkbus && /usr/bin/python3 collect_bus_data_optimized_concurrent.py >> /share/scripts/hkbus/logs/cron_output.log 2>&1
```

**Alternative: Specific weekdays (Monday, Thursday, Sunday at 3 AM):**

```bash
# HK Bus Data Collection - Mon/Thu/Sun at 3 AM
0 3 * * 0,1,4 cd /share/scripts/hkbus && /usr/bin/python3 collect_bus_data_optimized_concurrent.py >> /share/scripts/hkbus/logs/cron_output.log 2>&1
```

**Cron schedule breakdown:**
```
0 3 */3 * *
│ │  │  │ │
│ │  │  │ └─ Day of week (0-6, 0=Sunday)
│ │  │  └─── Month (1-12)
│ │  └────── Day of month (1-31) - */3 means every 3 days
│ └───────── Hour (0-23) - 3 AM
└─────────── Minute (0-59) - 0 minutes past the hour
```

### Save and Exit

- In vi: Press `ESC`, type `:wq`, press Enter
- In nano: Press `CTRL+X`, then `Y`, then Enter

### Verify Cron Job

```bash
# List all cron jobs
crontab -l

# Check cron service status
/etc/init.d/crond status
```

---

## Step 9: Monitor Execution

### View Latest Log

```bash
# Watch log in real-time
tail -f /share/scripts/hkbus/logs/bus_data_collection_*.log

# View cron output
tail -f /share/scripts/hkbus/logs/cron_output.log
```

### Check Last Execution Time

```bash
# Check file modification time
ls -lth /share/scripts/hkbus/output/bus_data.json
```

### Check Firebase Upload

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Storage**
4. Verify `bus_data.json` exists and check its metadata:
   - **version**: Unix timestamp
   - **generated_at**: ISO datetime
   - **file_size**: ~18MB
   - **total_routes**: ~2,090
   - **total_stops**: ~9,223

---

## Step 10: Email Notifications (Optional)

### Setup Email Alerts on Failure

Create wrapper script `/share/scripts/hkbus/run_with_email.sh`:

```bash
#!/bin/bash

SCRIPT_DIR="/share/scripts/hkbus"
LOG_FILE="$SCRIPT_DIR/logs/cron_output.log"
EMAIL="your-email@example.com"

# Run the script
cd $SCRIPT_DIR
/usr/bin/python3 collect_bus_data_optimized_concurrent.py >> $LOG_FILE 2>&1

# Check exit code
if [ $? -ne 0 ]; then
    # Send email on failure (requires sendmail or mail command)
    echo "Bus data collection failed. Check logs at $LOG_FILE" | mail -s "QNAP Bus Collection Failed" $EMAIL
fi
```

Make executable:

```bash
chmod +x /share/scripts/hkbus/run_with_email.sh
```

Update crontab to use wrapper:

```bash
0 3 */3 * * /share/scripts/hkbus/run_with_email.sh
```

---

## Troubleshooting

### Issue: "Module not found" error

**Solution:**

```bash
# Check Python path
which python3

# Reinstall dependencies with full path
/usr/bin/pip3 install -r /share/scripts/hkbus/requirements.txt

# Update cron to use full Python path
/usr/bin/python3 /share/scripts/hkbus/collect_bus_data_optimized_concurrent.py
```

### Issue: "Permission denied" when accessing files

**Solution:**

```bash
# Fix permissions
chmod +x /share/scripts/hkbus/collect_bus_data_optimized_concurrent.py
chmod 600 /share/scripts/hkbus/.env
chmod 600 /share/scripts/firebase/hkbus-service-account.json
```

### Issue: Firebase upload fails with "Permission denied"

**Solution:**

1. Verify Firebase service account key is valid:
   ```bash
   cat /share/scripts/firebase/hkbus-service-account.json
   ```

2. Check `.env` file has correct path:
   ```bash
   cat /share/scripts/hkbus/.env | grep FIREBASE_SERVICE_ACCOUNT_PATH
   ```

3. Test Firebase connection manually:
   ```bash
   cd /share/scripts/hkbus
   python3 collect_bus_data_optimized_concurrent.py
   ```

### Issue: Cron job doesn't run

**Solution:**

1. Check cron service:
   ```bash
   /etc/init.d/crond status
   /etc/init.d/crond restart
   ```

2. Verify crontab syntax:
   ```bash
   crontab -l
   ```

3. Check cron logs:
   ```bash
   cat /var/log/cron
   ```

4. Test cron command manually:
   ```bash
   cd /share/scripts/hkbus && /usr/bin/python3 collect_bus_data_optimized_concurrent.py
   ```

### Issue: Script runs but no Firebase upload

**Solution:**

1. Check if Firebase libraries installed:
   ```bash
   pip3 list | grep firebase-admin
   ```

2. Verify `.env` configuration:
   ```bash
   cat /share/scripts/hkbus/.env
   ```

3. Check logs for specific error:
   ```bash
   grep -i "firebase" /share/scripts/hkbus/logs/bus_data_collection_*.log
   ```

---

## Maintenance

### Log Rotation

Prevent log files from consuming too much space:

```bash
# Create log rotation script
cat > /share/scripts/hkbus/rotate_logs.sh << 'EOF'
#!/bin/bash
# Keep only last 30 days of logs
find /share/scripts/hkbus/logs -name "*.log" -mtime +30 -delete
echo "$(date): Log rotation complete" >> /share/scripts/hkbus/logs/maintenance.log
EOF

chmod +x /share/scripts/hkbus/rotate_logs.sh

# Add to crontab (run weekly on Sunday at 2 AM)
0 2 * * 0 /share/scripts/hkbus/rotate_logs.sh
```

### Disk Space Monitoring

```bash
# Check disk usage
df -h /share

# Check project directory size
du -sh /share/scripts/hkbus
```

### Update Script

When you update the Python script:

```bash
# Upload new version via SCP
scp collect_bus_data_optimized_concurrent.py admin@your-nas-ip:/share/scripts/hkbus/

# Or edit directly on QNAP
cd /share/scripts/hkbus
vi collect_bus_data_optimized_concurrent.py
```

---

## Summary Checklist

After deployment, verify:

- [ ] Python 3 and dependencies installed
- [ ] Project directories created
- [ ] Files uploaded to QNAP
- [ ] `.env` configured with correct paths and bucket name
- [ ] Firebase service account key in place with correct permissions
- [ ] Manual test run successful
- [ ] JSON generated in `/share/scripts/hkbus/output/`
- [ ] Firebase upload successful (check Firebase Console)
- [ ] Cron job configured and running
- [ ] Logs being generated correctly
- [ ] Email notifications working (if configured)

---

## Support & Monitoring

### Quick Health Check Command

```bash
# Run this to check system status
cd /share/scripts/hkbus && \
echo "=== Python Version ===" && python3 --version && \
echo "\n=== Dependencies ===" && pip3 list | grep -E "requests|firebase|dotenv" && \
echo "\n=== Last Run ===" && ls -lth output/bus_data.json 2>/dev/null && \
echo "\n=== Latest Log ===" && ls -lth logs/*.log 2>/dev/null | head -3 && \
echo "\n=== Cron Job ===" && crontab -l | grep bus_data
```

### Performance Benchmarks

Expected execution times:
- **KMB collection**: 5-10 seconds (3 API calls)
- **CTB collection**: 3-5 minutes (concurrent processing)
- **Data validation**: < 1 second
- **JSON save**: < 2 seconds
- **Firebase upload**: 10-30 seconds (depends on network)
- **Total**: 4-7 minutes

---

## Contact & Resources

- **Firebase Console**: https://console.firebase.google.com/
- **QNAP Support**: https://www.qnap.com/en/support
- **Python Script Issues**: Check `logs/` directory first
- **Cron Issues**: Check `/var/log/cron` on QNAP

---

**Last Updated**: 2025-10-30
**Script Version**: v1.0 with Firebase integration
**Target Platform**: QNAP QTS
