# Firebase API Key Regeneration Guide

## 🚨 Security Incident Summary

**Issue**: Firebase `GoogleService-Info.plist` containing API key `AIzaSyD7ADhEeEay70U3x7M7vvD9qa90jDRViFg` was exposed in public GitHub repository.

**Status**:
- ✅ File removed from Git tracking
- ✅ File permanently deleted from Git history
- ✅ Changes force-pushed to GitHub
- ⏳ **CRITICAL**: API key must be regenerated immediately

---

## Step 1: Regenerate the Compromised API Key

### Option A: Regenerate iOS API Key (Recommended)

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com/
   - Select project: **HKBusApp** (id: hkbusapp-e34a7)

2. **Navigate to Project Settings**
   - Click gear icon ⚙️ (top left)
   - Select "Project settings"

3. **Download New Configuration File**
   - Go to "General" tab
   - Scroll to "Your apps" section
   - Find your iOS app
   - Click "GoogleService-Info.plist" download button
   - This will download a NEW plist file with a NEW API key

4. **Replace Local File**
   ```bash
   # Backup the old file first (optional)
   mv HKBusApp/HKBusApp/GoogleService-Info.plist HKBusApp/HKBusApp/GoogleService-Info.plist.OLD

   # Move the newly downloaded file to your project
   mv ~/Downloads/GoogleService-Info.plist HKBusApp/HKBusApp/GoogleService-Info.plist
   ```

5. **Verify the File is NOT Tracked**
   ```bash
   git status
   # GoogleService-Info.plist should NOT appear in the output
   # If it does, it means .gitignore is not working
   ```

### Option B: Delete and Re-Add iOS App (Nuclear Option)

If regeneration doesn't work:

1. In Firebase Console → Project Settings → Your apps
2. Delete the existing iOS app
3. Click "Add app" → iOS
4. Follow the setup wizard
5. Download the new `GoogleService-Info.plist`

---

## Step 2: Set API Key Restrictions (CRITICAL)

### Why Restrictions Matter
Even though the old key is now removed from GitHub, anyone who cloned your repository before the fix still has access to it. Restrictions limit what the key can be used for.

### iOS API Key Restrictions

1. **Open Google Cloud Console**
   - Go to https://console.cloud.google.com/
   - Select project: **HKBusApp**

2. **Navigate to API Credentials**
   - Click hamburger menu ☰
   - Go to "APIs & Services" → "Credentials"

3. **Find iOS API Key**
   - Look for the key starting with `AIzaSy...`
   - Click the key name to edit

4. **Set Application Restrictions**
   - Under "Application restrictions"
   - Select "iOS apps"
   - Click "Add an item"
   - Enter your iOS Bundle ID: `com.davidwong.HKBusApp`
   - Click "Done"

5. **Set API Restrictions**
   - Under "API restrictions"
   - Select "Restrict key"
   - Enable ONLY these APIs:
     - ✅ Cloud Storage for Firebase API
     - ✅ Firebase Installations API
     - ✅ Google Analytics API (if using Analytics)
   - Click "Save"

### Web API Key Restrictions (If Applicable)

If you have a separate web API key:

1. Set "HTTP referrers" restriction
2. Add your authorized domains:
   - `https://yourdomain.com/*`
   - `http://localhost:*` (for development)

---

## Step 3: Verify Security

### Check 1: Confirm File is Protected
```bash
# This should return empty (file not tracked)
git ls-files | grep GoogleService-Info.plist

# This should show the file exists locally
ls -la HKBusApp/HKBusApp/GoogleService-Info.plist
```

### Check 2: Test App Build
```bash
cd HKBusApp
xcodebuild -project HKBusApp.xcodeproj \
  -scheme HKBusApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  clean build
```

### Check 3: Verify Firebase Connection
- Run the app
- Check Xcode console for Firebase initialization logs
- Should see: `[Firebase/Core][I-COR000003] The default Firebase app has been configured.`

---

## Step 4: Monitor for Abuse

### Google Cloud Console Monitoring

1. **Set Up Billing Alerts**
   - Go to Google Cloud Console → Billing
   - Set budget alerts at:
     - $5 (50% of expected monthly cost)
     - $10 (100% of expected monthly cost)
     - $20 (warning threshold)

2. **Monitor API Usage**
   - Go to "APIs & Services" → "Dashboard"
   - Check daily for unusual spikes
   - Monitor for 2-4 weeks after the incident

3. **Review Logs**
   - Go to "Logging" → "Logs Explorer"
   - Filter by Firebase API calls
   - Look for:
     - Requests from unknown IP addresses
     - Unusual geographic locations
     - High request volumes

### Firebase Console Monitoring

1. **Storage Usage**
   - Go to Firebase Console → Storage
   - Check for unexpected downloads
   - Review access logs

2. **Analytics (if enabled)**
   - Check for unusual user patterns
   - Monitor app installations from unexpected regions

---

## Step 5: Additional Security Measures

### 1. Enable Firebase App Check (Highly Recommended)

App Check prevents unauthorized clients from accessing your Firebase services.

**Setup Steps**:
1. Firebase Console → Build → App Check
2. Click "Get started"
3. For iOS: Register your app with App Attest or DeviceCheck
4. Enforce App Check for:
   - Cloud Storage
   - Realtime Database (if used)
   - Cloud Functions (if used)

### 2. Update Firebase Security Rules

Ensure your Storage rules are restrictive:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      // Only allow authenticated iOS app to read
      allow read: if request.auth != null;
      // No public writes
      allow write: if false;
    }
  }
}
```

### 3. Set Up Secret Scanning (GitHub)

1. Go to your GitHub repository settings
2. Enable "Secret scanning" (if available)
3. Enable "Push protection" to prevent future accidental commits

### 4. Review Access Control

- Check Firebase Console → Project Settings → Users and permissions
- Remove any unknown users
- Ensure principle of least privilege

---

## Step 6: Document the Incident

### Create Incident Log

```markdown
## Security Incident: 2024-12-22

**Type**: Exposed Firebase API Key
**Severity**: High
**Detection**: Google Cloud automated email alert
**Response Time**: < 2 hours

**Timeline**:
- 11:49 - Notification received
- 12:20 - File removed from Git history
- 12:25 - Force push to GitHub completed
- [PENDING] - API key regenerated
- [PENDING] - API restrictions applied

**Actions Taken**:
1. Removed GoogleService-Info.plist from Git tracking
2. Used git filter-branch to purge from history
3. Force pushed to GitHub
4. [TODO] Regenerate API key
5. [TODO] Apply iOS Bundle ID restrictions

**Prevention Measures**:
- .gitignore already included the file (was added after initial commit)
- Added security checklist to project documentation
- Enabled GitHub secret scanning (if available)

**Lessons Learned**:
- Always add sensitive files to .gitignore BEFORE first commit
- Use Firebase App Check for production apps
- Set API key restrictions immediately upon creation
- Regular security audits of repository
```

---

## Step 7: Future Prevention Checklist

### Before Every Commit

- [ ] Run `git status` to check for untracked sensitive files
- [ ] Verify `.gitignore` includes all credential files
- [ ] Review diff: `git diff --cached`
- [ ] Never commit files containing:
  - API keys
  - Passwords
  - Certificates
  - Service account JSON files
  - `.env` files with secrets

### Project Setup Best Practices

1. **Add .gitignore FIRST** before any commits
2. **Use environment variables** for sensitive config
3. **Never hardcode credentials** in source code
4. **Use Secret Management Tools**:
   - iOS Keychain for storing sensitive data
   - Firebase Remote Config for app configuration
   - CI/CD secrets for build-time credentials

5. **Enable Pre-commit Hooks**:
   ```bash
   # Install git-secrets (detects credentials)
   brew install git-secrets

   # Set up in your repo
   cd /path/to/repo
   git secrets --install
   git secrets --register-aws  # if using AWS
   ```

### Regular Security Audits

- [ ] Monthly: Review API key usage in Google Cloud Console
- [ ] Quarterly: Rotate API keys (if possible)
- [ ] Before releases: Run security scan on codebase
- [ ] After team changes: Review access permissions

---

## Emergency Contacts

**Google Cloud Support**: https://cloud.google.com/support
**Firebase Support**: https://firebase.google.com/support

**If you suspect active abuse**:
1. Immediately disable the compromised API key (Google Cloud Console)
2. Contact Google Cloud support
3. Review billing for unauthorized charges
4. File abuse report if necessary

---

## Verification Checklist

After completing all steps:

- [ ] New `GoogleService-Info.plist` downloaded and in place
- [ ] File NOT tracked by Git (`git ls-files` check)
- [ ] iOS Bundle ID restriction applied to API key
- [ ] API restrictions limit to required Firebase services only
- [ ] App builds and runs successfully
- [ ] Firebase connection verified in app logs
- [ ] Billing alerts configured in Google Cloud
- [ ] Monitoring set up for unusual activity
- [ ] Incident documented
- [ ] Team notified (if applicable)
- [ ] Old API key disabled/deleted (after confirming new key works)

---

## Next Steps (In Order)

1. **IMMEDIATELY**: Download new GoogleService-Info.plist from Firebase Console
2. **WITHIN 1 HOUR**: Apply iOS Bundle ID restrictions to API key
3. **WITHIN 24 HOURS**: Set up API usage monitoring and billing alerts
4. **WITHIN 1 WEEK**: Implement Firebase App Check
5. **ONGOING**: Monitor for unusual activity for 2-4 weeks

---

## Status: 🔴 ACTION REQUIRED

**You must complete Steps 1-2 immediately** to secure your Firebase project.

The exposed API key can still be used by anyone who:
- Cloned your repository before the fix
- Found the key in GitHub's cached search results
- Scraped the key from the public commit

**Do not delay this - regenerate and restrict the API key NOW.**
