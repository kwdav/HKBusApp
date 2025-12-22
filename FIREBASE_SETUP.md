# Firebase Setup Guide for HK Bus App

This guide walks through setting up Firebase for the HK Bus App to enable automatic bus data distribution from QNAP NAS to iOS app.

## Overview

- **Purpose**: Host `bus_data.json` (17.76MB) on Firebase Storage
- **Update Frequency**: Every 3 days via automated QNAP cron job
- **Access Control**: App-only access with Firebase Security Rules
- **Version Management**: Metadata-based version tracking to avoid redundant downloads

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Project setup:
   - **Project name**: `HKBusApp` (or your preferred name)
   - **Google Analytics**: Optional (can disable for this use case)
   - Click **"Create project"** and wait for setup to complete

---

## Step 2: Enable Firebase Storage

1. In Firebase Console, select your project
2. In left sidebar, click **"Build"** → **"Storage"**
3. Click **"Get started"**
4. Choose **"Start in test mode"** (we'll configure security rules later)
5. Select Cloud Storage location:
   - Recommended: `asia-east2` (Hong Kong) or `asia-southeast1` (Singapore)
6. Click **"Done"**

You should now see an empty Storage browser with a bucket URL like:
```
gs://hkbusapp-12345.appspot.com
```

---

## Step 3: Configure Security Rules

Secure the storage so only your iOS app can download the file.

1. In Storage tab, click **"Rules"** at the top
2. Replace default rules with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow read access to bus_data.json for authenticated app users
    match /bus_data.json {
      allow read: if request.auth != null;
      allow write: if false; // Only admin (Python script) can write
    }

    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click **"Publish"**

**Note**: This requires your iOS app to use Firebase Authentication. If you prefer public read access (simpler but less secure), use:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /bus_data.json {
      allow read: if true;  // Public read access
      allow write: if false;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Step 4: Generate Service Account Key (for Python script)

The Python script needs admin credentials to upload files to Firebase Storage.

1. In Firebase Console, click the **gear icon** (⚙️) next to "Project Overview"
2. Select **"Project settings"**
3. Go to **"Service accounts"** tab
4. Click **"Generate new private key"**
5. Confirm by clicking **"Generate key"**
6. A JSON file will download (e.g., `hkbusapp-12345-firebase-adminsdk-xxxxx.json`)

**⚠️ IMPORTANT SECURITY NOTES:**
- This file grants full admin access to your Firebase project
- **Never commit this file to git** (it's already in `.gitignore`)
- Store it securely on your QNAP NAS only
- Recommended location: `/share/scripts/firebase/hkbusapp-service-account.json`
- Set proper file permissions on QNAP:
  ```bash
  chmod 600 /share/scripts/firebase/hkbusapp-service-account.json
  ```

---

## Step 5: Get Your Storage Bucket Name

You'll need this for the Python script configuration.

1. In Firebase Console → **Storage**
2. Look at the top for your bucket name (format: `your-project-id.appspot.com`)
3. Example: `hkbusapp-12345.appspot.com`

Save this value - you'll use it in the `.env` file.

---

## Step 6: Configure iOS App (Firebase SDK)

### Option A: If you haven't integrated Firebase SDK yet

1. In Firebase Console → **Project settings** → **General**
2. Under "Your apps", click the **iOS+** button
3. Register app:
   - **iOS bundle ID**: `com.yourcompany.HKBusApp` (must match Xcode)
   - **App nickname**: Optional
   - Click **"Register app"**
4. Download `GoogleService-Info.plist`
5. Add it to your Xcode project:
   - Drag into Xcode project navigator
   - Ensure "Add to target" has `HKBusApp` checked

### Option B: If Firebase SDK already integrated

Just update the Storage rules (Step 3) and you're good to go.

---

## Step 7: Verify Setup

### Test Firebase Storage Access

1. In Firebase Console → **Storage**
2. Click **"Upload file"**
3. Upload a test file (e.g., `test.txt`)
4. Note the download URL

### Test from iOS Simulator

Add test code to your iOS app:

```swift
import FirebaseStorage

func testFirebaseConnection() {
    let storage = Storage.storage()
    let storageRef = storage.reference()
    let testRef = storageRef.child("test.txt")

    testRef.downloadURL { url, error in
        if let error = error {
            print("❌ Firebase test failed: \(error)")
        } else if let url = url {
            print("✅ Firebase connected: \(url)")
        }
    }
}
```

---

## Summary Checklist

Before proceeding to Python script configuration:

- [ ] Firebase project created
- [ ] Firebase Storage enabled with location selected
- [ ] Security Rules configured
- [ ] Service account key JSON downloaded
- [ ] Storage bucket name noted (e.g., `project-id.appspot.com`)
- [ ] Service account key stored securely on QNAP NAS
- [ ] iOS app has `GoogleService-Info.plist` added

---

## Next Steps

Once Firebase is set up:

1. Configure Python script with `.env` file (see `.env.example`)
2. Test Python script locally to verify upload works
3. Deploy to QNAP NAS (see `NAS_DEPLOYMENT_QNAP.md`)
4. Set up cron job for automatic updates every 3 days

---

## Troubleshooting

### "Permission denied" when uploading from Python
- Check service account key is valid and not expired
- Verify JSON file path in `.env` is correct
- Ensure Firebase Storage is enabled in project

### iOS app can't download file
- Check Security Rules allow read access
- Verify `GoogleService-Info.plist` is in Xcode project
- Ensure Firebase SDK is initialized in `AppDelegate.swift`

### File upload succeeds but app sees old version
- Check metadata is being set correctly in Python script
- Verify iOS app version checking logic
- Clear app data and reinstall to test fresh download

---

## Cost Considerations

Firebase Storage pricing (as of 2024):

- **Storage**: $0.026/GB/month → ~$0.46/month for 17.76MB
- **Download**: $0.12/GB → Minimal (only when users update)
- **Operations**: $0.05/10,000 operations → Negligible

**Estimated monthly cost**: < $1 USD

Free tier includes:
- 5GB storage
- 1GB/day downloads
- 50,000 operations/day

Your usage will stay well within free tier limits.

---

## Support

For Firebase-specific issues, see:
- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [Firebase Admin SDK Python](https://firebase.google.com/docs/admin/setup)
- [Security Rules Guide](https://firebase.google.com/docs/storage/security)
