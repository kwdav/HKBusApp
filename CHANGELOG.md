# Changelog

All notable changes to the HK Bus App project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14.3] - 2025-12-30

### Fixed - Invalid Route Filtering and Validation
- **🚌 3-Layer Defense System for Invalid Routes**: Completely eliminated display of routes without stop data
  - **Layer 1 - Search Results Filtering** (`LocalBusDataManager.searchRoutesLocally()`):
    - Routes with no stop data are now completely filtered out from search results
    - Validation checks both outbound and inbound directions
    - Routes only appear if at least one direction has stops (count > 0)
    - Added `DirectionInfo.stopCount` property for displaying actual stop counts
    - Example: 9C (0 stops in both directions) → completely hidden from search results

  - **Layer 2 - Direction Selection Validation** (`SearchViewController`):
    - Direction picker only shows directions with stop data
    - Filters out invalid directions before presenting selection sheet
    - Shows error alert if no valid directions exist for selected route
    - Prevents navigation to routes without stop data

  - **Layer 3 - Route Detail Error Handling** (`RouteDetailViewController`):
    - Added empty stops validation on route load
    - Shows friendly error message if route has no stop data
    - Graceful fallback prevents white screen crashes

- **⌨️ Keyboard-Level Route Validation**: Custom keyboard now prevents invalid route input at character level
  - Enhanced `LocalBusDataManager.getPossibleNextCharacters()` with stop data validation
  - Keyboard buttons dynamically enable/disable based on route validity
  - O(1) dictionary lookup for route_stops validation
  - Dual-Set tracking system for validation optimization:
    - `validatedRoutes`: Tracks all checked routes (prevents duplicate validation)
    - `validRoutes`: Tracks only routes confirmed to have stops
  - Example behaviors:
    - Typing "9" → "C" button **disabled** (9C has 0 stops in both directions)
    - Typing "90" → "C" button **enabled** (90C outbound has 15 stops)
    - Instant visual feedback, prevents invalid input before API call

- **🔄 Single-Direction Route Button Fix**: Direction switch button correctly hidden for single-direction routes
  - Fixed `RouteDetailViewController.fetchAvailableDirections()` to use `LocalBusDataManager.searchRoutesLocally()`
  - Previously used `BusAPIService.searchRoutes()` which returned unfiltered directions
  - Now correctly queries filtered local data (only directions with stops)
  - Direction switch arrow icon and button interaction disabled for single-direction routes
  - Example: A28X (only outbound with stops) → no direction switch button

### Changed
- **LocalBusDataManager.swift**:
  - `searchRoutesLocally()`: Added compactMap filtering for directions without stops
  - `getPossibleNextCharacters()`: Enhanced with route_stops validation logic
  - Added helper methods: `getRouteStopCount()`, `isValidRouteDirection()`

- **SearchViewController.swift**:
  - `handleRouteSelection()`: Added direction validation before showing selection sheet
  - Enhanced error handling with user-friendly alert messages

- **RouteDetailViewController.swift**:
  - `loadRouteDetail()`: Added empty stops validation check
  - `fetchAvailableDirections()`: Switched from API service to local data manager
  - `showEmptyStopsError()`: Added error UI for routes without stops

### Technical Details
- **Route Validation Logic**:
  - Route ID format: `{company}_{routeNumber}_{O|I}` (O=outbound, I=inbound)
  - Validation checks: `data.routeStops[routeId]?.count ?? 0 > 0`
  - A route is valid if **any direction** has stops (OR logic, not AND)
  - Performance: Dictionary lookup O(1), cached keyboard state for <1ms response

- **Data Integrity Context**:
  - `bus_data.json` contains 113 CTB routes in `routes` but missing from `route_stops`
  - These are special/seasonal routes (R/P/N suffixes, race days, peak hours)
  - Routes exist in government API but have no active stop data
  - Filtering prevents user confusion and empty search results

- **Keyboard State Management**:
  - Integrated with existing `keyboardStateCache` (100-item limit)
  - Validation occurs during `getPossibleNextCharacters()` call
  - Button states update synchronously with text input
  - No animation delays - instant visual feedback

### User Experience Improvements
- ✅ **No Invalid Route Display**: Users never see routes that have no stops
- ✅ **Smart Keyboard**: Buttons guide users to only valid route numbers
- ✅ **Clear Direction Info**: Stop counts shown in direction selection sheet
- ✅ **Clean UI**: Single-direction routes don't show unnecessary switch button
- ✅ **Error Prevention**: Triple validation ensures no crashes from missing data

### Related Files Modified
- `LocalBusDataManager.swift`: Lines 295-338 (getPossibleNextCharacters), 397-464 (searchRoutesLocally), 465-489 (validation helpers)
- `SearchViewController.swift`: Lines 1370-1421 (direction validation)
- `RouteDetailViewController.swift`: Lines 511-517 (empty check), 882-901 (fetchAvailableDirections), 1120-1194 (error UI)

## [0.14.2] - 2025-12-25

### Fixed - Custom Keyboard Clear Button Issue
- **🎹 Clear (x) Button Keyboard Restoration**: Fixed critical UX issue where custom keyboard disappeared after pressing Clear (x) button
  - Root cause: `searchBarShouldClear(_:)` delegate method not being called by iOS
  - Implemented focus reset mechanism in `textDidChange` when search text becomes empty
  - Added `resignFirstResponder()` → `becomeFirstResponder()` cycle to force keyboard re-trigger
  - Optimized timing with 0.2s + 0.15s delays for stable keyboard restoration

- **🛡️ Multi-Layer Protection Against Interference**
  - Modified execution order: focus reset BEFORE `tableView.reloadData()` to prevent scroll events
  - Added `isClearingText` protection in `scrollViewWillBeginDragging` to skip keyboard hiding
  - Added `isClearingText` protection in `textDidChange` to prevent duplicate processing
  - Enhanced `searchBarTextDidEndEditing` with fallback keyboard restoration logic

### Changed
- **SearchViewController.swift**:
  - `searchBarShouldClear(_:)`: Complete rewrite with focus reset logic and delayed data loading
  - `searchBar(_:textDidChange:)`: Added Clear (x) detection and focus reset execution
  - `scrollViewWillBeginDragging(_:)`: Added protection check to skip keyboard hiding during clear
  - `searchBarTextDidEndEditing(_:)`: Enhanced with fallback keyboard restoration mechanism

### Technical Details
- **Focus Reset Flow**:
  1. Clear (x) pressed → `textDidChange` detects empty text
  2. Immediately `resignFirstResponder()` to unfocus text field
  3. Delay 0.2s, then `becomeFirstResponder()` to refocus
  4. Delay 0.15s, check `isKeyboardVisible` and force `showKeyboard()` if needed
  5. Finally load nearby routes and `reloadData()`

- **Timing Optimization**:
  - Tested 0.1s delays: unstable, keyboard sometimes failed to reappear
  - Settled on 0.2s + 0.15s: stable and reliable, keyboard consistently reappears
  - Tradeoff: ~0.35s brief keyboard disappearance (acceptable for stability)

- **Edge Cases Handled**:
  - Scroll during clear operation: protected by `isClearingText` flag
  - Rapid Clear (x) presses: debounced by async dispatch queue
  - Clear after scrolling search results: keyboard correctly reappears (verified)

### User Experience
- ✅ Custom keyboard now reliably reappears after Clear (x) button press
- ⚠️ Brief ~0.35s keyboard disappearance during focus reset (necessary for stability)
- ✅ Consistent behavior across all scenarios (with/without scrolling)

## [0.14.1] - 2025-12-22

### Security - Firebase API Key Regeneration
- **🔒 API Key Security Incident Response**
  - Successfully resolved Firebase API key exposure incident (detected via Google Cloud alert)
  - Removed GoogleService-Info.plist from Git tracking and history
  - Regenerated Firebase API key (old: AIzaSyD7AD..., new: AIzaSyADM3...)
  - Enhanced .gitignore protection with wildcard pattern (`GoogleService-Info.plist*`)
  - All sensitive files now permanently excluded from version control

- **✅ Comprehensive Security Verification**
  - Verified new API key configuration in GoogleService-Info.plist
  - Confirmed Bundle ID consistency (com.answertick.HKBusApp)
  - Validated Firebase initialization in AppDelegate
  - Tested successful builds (Debug & Release modes)
  - Verified Firebase Storage configuration
  - Confirmed no sensitive files tracked by Git

### Added - Security Documentation
- **📋 Complete Security Response Documentation**
  - `FIREBASE_API_KEY_REGENERATION.md`: Detailed incident response guide
  - `SECURITY_IMMEDIATE_ACTIONS.md`: Quick action checklist
  - `FIREBASE_API_KEY_UPDATE_REPORT.md`: Incident timeline and actions
  - `APP_SECURITY_CHECK_REPORT.md`: Comprehensive post-incident verification

### Fixed
- **🛡️ Git Security Protection**
  - Purged GoogleService-Info.plist from all Git history using git filter-branch
  - Force-pushed cleaned history to GitHub (commit: 78cb036)
  - Updated .gitignore from `GoogleService-Info.plist` to `GoogleService-Info.plist*`
  - Created backup of old configuration (GoogleService-Info.plist.backup-20251222)

### Technical Details
- **Incident Timeline**:
  - 11:49 - Google Cloud alert received (API key exposed on GitHub)
  - 12:20 - Git history cleanup completed
  - 12:25 - Force push to GitHub
  - 16:39 - New GoogleService-Info.plist downloaded from Firebase Console
  - 17:04 - New API key installed and verified
  - 17:15 - Complete security verification finished
  - Total response time: ~5.5 hours from detection to resolution

- **Security Measures Applied**:
  - ✅ Old API key disabled in Google Cloud Console
  - ✅ New API key restricted to iOS Bundle ID (com.answertick.HKBusApp)
  - ✅ API key restricted to required Firebase services only
  - ✅ .gitignore enhanced with wildcard protection
  - ✅ CocoaPods dependencies reinstalled (17 pods)
  - ✅ Build verification (Debug & Release successful)

### Recommendations Completed
- Set up API key restrictions in Google Cloud Console
- Configure billing alerts for abuse monitoring
- Consider enabling Firebase App Check for additional security

### Related Commits
- `78cb036`: security: Remove GoogleService-Info.plist from tracking
- `36615e7`: security: Update Firebase API key and enhance protection
- `31290ec`: docs: Add comprehensive app security check report

## [0.14.0] - 2025-12-22

### Fixed - Custom Keyboard Reliability
- **🎹 Keyboard Re-appearance Issue**: Fixed critical bug where keyboard wouldn't reappear after dismissal
  - Synchronized state flags with animation completions (no more race conditions)
  - Removed blocking guard clauses that prevented re-showing
  - Fixed searchBarShouldEndEditing to allow normal editing dismissal
  - Added automatic state recovery in viewWillAppear

- **🔄 Animation Conflict Resolution**
  - Fixed Cancel button double-dismissal conflict
  - Fixed scroll-to-dismiss during animation-in-progress
  - Added completion handlers for all show/hide operations

- **🛡️ State Consistency**
  - Keyboard state now synchronized with actual visibility
  - Added recovery mechanism for stuck states
  - Improved edge case handling (rapid taps, mid-animation interactions)

### Changed
- Custom keyboard show/hide methods now use completion handlers
- Search bar editing end behavior now follows standard iOS patterns
- State flags updated after animations complete (not before)

### Technical Details
- Modified `BusRouteKeyboard.swift`:
  - Added optional `completion` parameter to `show()` and `hide()` methods
  - Removed guard clauses (`guard isHidden else { return }`)
  - Set `isHidden = false` immediately in `show()` for consistency
  - Added alpha/transform checks to avoid redundant animations
  - Completion handlers called after UIView.animate completes

- Modified `SearchViewController.swift`:
  - Updated `showKeyboard()` and `hideKeyboard()` to use completion handlers
  - State flags (`isKeyboardVisible`) now set in completion blocks
  - Fixed `searchBarShouldEndEditing()` to always return `true`
  - Updated `searchBarTextDidEndEditing()` to hide keyboard when search bar loses focus
  - Reordered `searchBarCancelButtonClicked()` operations (keyboard hide → resign first responder)
  - Added alpha check to `scrollViewWillBeginDragging()` (only hide if keyboard fully visible)
  - Added `resetKeyboardStateIfNeeded()` method called in `viewWillAppear()`
  - Added `isKeyboardAnimating` flag to prevent rapid show/hide during animations

### Root Cause
The keyboard failed to reappear due to timing race conditions:
1. `hideKeyboard()` set `isKeyboardVisible = false` immediately
2. Hide animation ran for 0.25s asynchronously
3. User tapped search bar during animation
4. `showKeyboard()` passed guard check (`isKeyboardVisible == false`)
5. But `customKeyboard.show()` guard failed (`isHidden` still `false`)
6. Keyboard stuck in inconsistent state

**Solution**: Removed guard clauses, synchronized state with animation completions, added recovery mechanism.

## [0.13.0] - 2025-12-22

### Performance - Station Search Optimization
- **⚡ 10x Scrolling Performance Improvement**
  - Implemented distance calculation caching for station search results
  - Cache distances once when results load instead of recalculating on every cell scroll
  - Eliminates hundreds of redundant `CLLocation.distance()` calculations during scrolling
  - Pre-formats route display text to avoid repeated string operations (mapping, sorting, joining)

- **🎯 Smart Result Sorting**
  - Station search results now sorted by distance (nearest first) when location available
  - Alphabetical sorting when no location permission granted
  - Improves discoverability of relevant nearby stops

### Changed - Search UX Consistency
- **⏱️ Unified Debounce Timing**
  - Changed station search debounce from 0.5s to 0.3s
  - Consistent responsiveness across both route search and station search
  - Faster search feedback for better UX

### Added - Route Search Visual Feedback
- **🔄 Loading State Indicator**
  - Shows "搜尋中..." message during API calls
  - Clear visual feedback while waiting for search results
  - Professional loading experience

- **📭 Empty State Messages**
  - Shows "沒有找到路線「X」" when search returns no results
  - Shows "搜尋時發生錯誤" when API errors occur
  - Clarifies when no results exist vs loading vs error states

### Technical Details
- Modified `StopSearchViewController.swift`:
  - Added `distanceCache` and `routeDisplayTextCache` dictionaries
  - Added `cacheDistances()` and `cacheRouteDisplayText()` methods
  - Updated `calculateDistanceText()` to use cache first with fallback
  - Cache built once when results load (nearby stops or search results)

- Modified `LocalBusDataManager.swift`:
  - Added optional `location` parameter to `searchStops()` method
  - Implemented distance-based sorting when location provided
  - Alphabetical fallback sorting when no location

- Modified `StopSearchResultTableViewCell.swift`:
  - Added `cachedRouteText` parameter to `configure()` method
  - Uses cached text when available, falls back to calculation on cache miss

- Modified `SearchViewController.swift`:
  - Added `isShowingLoading` and `searchEmptyMessage` state properties
  - Updated `searchRoutes()` to set loading and empty states
  - Updated table view data source to display loading/empty cells

### Performance Metrics
- **Before**: 50 cells × scroll event = 100+ calculations per scroll
- **After**: 1 batch cache build (0.05s) + O(1) dictionary lookups
- **Impact**: Instant scrolling on lists with 50+ stops, no frame drops

### Memory Impact
- Distance cache: ~50 entries × 10 bytes = 500 bytes
- Route text cache: ~50 entries × 50 bytes = 2.5 KB
- Total additional memory: <3 KB (negligible)

## [0.12.3] - 2025-12-18

### Fixed - Toast Notification Appearance Mode Handling
- **🎨 Toast Color Synchronization**
  - Fixed toast background color mismatch during appearance mode transitions
  - Toast now correctly displays system appearance when switching to "自動" mode
  - Uses `UIScreen.main.traitCollection` for accurate system appearance detection
  - Resolves color flickering when transitioning between manual and automatic modes

### Technical Details
- Modified `SettingsViewController.swift:showToast()`:
  - Automatic mode: Uses `UIScreen.main.traitCollection.userInterfaceStyle` (system appearance)
  - Manual modes: Uses `AppearanceManager.shared.currentMode` (explicit setting)
  - Prevents race condition during 0.3-second appearance transition animation
  - Toast background color now matches target appearance mode immediately

### Before vs After
- **Before**: Switching to "自動" → Toast shows old mode color → 0.3s delay → Appearance changes
- **After**: Switching to "自動" → Toast shows correct system color → Smooth transition

## [0.12.2] - 2025-12-18

### Changed - Settings Page Update Indicator & UX Improvements
- **⚙️ Settings Page Update Hint**
  - Removed automatic background download (no interruption)
  - App only checks for updates (24-hour throttling)
  - When new version available, shows hint in Settings page
  - Orange hint row: "🆕 有新版本巴士數據可供更新"
  - Hint appears below "更新路線資料" button
  - User manually taps button to download when ready

- **📊 Data Version Display**
  - Added "巴士數據" info row in Settings → 數據管理 section
  - Shows current data version with timestamp (e.g., "數據版本: 2025-10-30 12:40")
  - Shows "使用內置數據" for first-time users
  - Non-interactive info display (read-only)

- **🔔 NotificationCenter Integration**
  - SceneDelegate posts "NewVersionAvailable" notification when update detected
  - SettingsViewController listens and shows orange hint row
  - Hint disappears after successful manual update

### Technical Details
- Modified `SceneDelegate.swift:sceneDidBecomeActive()`:
  - Only checks for updates (no automatic download)
  - Posts "NewVersionAvailable" notification when update found
  - Removed background download logic entirely

- Modified `SettingsViewController.swift`:
  - Added `hasNewVersionAvailable` boolean flag
  - Added NotificationCenter observer for "NewVersionAvailable"
  - Dynamic row count: 2 rows (no update) or 3 rows (update available)
  - Row 0: Data version display (style: .value1)
  - Row 1: Update route data button (triggers download)
  - Row 2: Orange hint (conditional, only when update available)
  - Modified `updateRouteData()` to use FirebaseDataManager
  - Shows download progress in loading alert
  - Hides hint row after successful update

### User Experience Improvements
1. **Toast Message for Success** 🎉
   - Update success now shows toast message instead of alert dialog
   - No need to tap "確定" button
   - Auto-dismisses after 1.5 seconds
   - Less intrusive user experience
   - Dark mode: Solid black background (100% opacity)
   - Light mode: Solid white background (100% opacity)
   - Text color auto-adapts to mode (UIColor.label)

2. **Date Format Simplification** 📅
   - Data version displays as "yyyy-MM-dd" (e.g., "2025-10-30")
   - Removed time (HH:mm) for cleaner look
   - Bundle data version also shows date on first install
   - No more "使用內置數據" placeholder

3. **Smart Download Logic** 🧠
   - Checks small metadata file (2KB) first
   - Only downloads large file (17MB) if update available
   - Shows "已是最新版本" toast if already up to date
   - Saves bandwidth and time

4. **Network Timeout Protection** ⏱️
   - 30-second timeout for all network operations
   - Prevents indefinite hanging on poor network
   - Clear error message: "連線逾時，請檢查網路連線並稍後再試"
   - Applies to both metadata check and data download

5. **Security Enhancement** 🔒
   - Removed Firebase URLs from all user-visible error messages
   - Generic error messages prevent information leakage
   - Console logs still available for debugging (developer only)
   - No gs:// or firebasestorage.app URLs exposed

### Before vs After
- **Before**: Popup dialog → Detailed error with URLs → Manual dismiss
- **After**: Quiet hint → Smart check → Toast success → 30s timeout → Generic errors

## [0.12.1] - 2025-12-13

### Fixed - Build Issues
- **🔧 Firebase rsync Error Fix**
  - Disabled `ENABLE_USER_SCRIPT_SANDBOXING` in Podfile post_install
  - Modified Xcode project settings to disable script sandboxing
  - Resolved rsync permission errors with Firebase SDK on Xcode 15+
  - Successfully built project with all Firebase dependencies

### Changed
- Updated Podfile with Xcode 15+ compatibility fix
- Modified project.pbxproj to disable user script sandboxing

## [0.12.0] - 2025-12-13

### Added - iOS Firebase Data Download
- **📱 FirebaseDataManager Service**
  - New singleton service for managing Firebase Storage downloads
  - Version checking with 24-hour throttling to save bandwidth
  - Smart download (only when updates available)
  - Progress tracking with real-time percentage updates
  - MD5 checksum verification for data integrity
  - Automatic installation to Documents directory

- **🔄 LocalBusDataManager Enhancements**
  - Priority-based data loading: Documents → Bundle
  - New `reloadData()` method for post-update refresh
  - Automatic fallback to bundled data on first install
  - Enhanced logging for data source tracking

- **🚀 App Lifecycle Integration**
  - Firebase initialization in `AppDelegate`
  - Automatic version check on app activation
  - User-friendly update prompts with progress display
  - Silent failure handling (non-intrusive)

### Changed
- **AppDelegate.swift**
  - Added Firebase initialization
  - Import `FirebaseCore`

- **SceneDelegate.swift**
  - Added `sceneDidBecomeActive` update check
  - Implemented update alert dialogs
  - Added download progress UI
  - Added success/failure feedback

- **LocalBusDataManager.swift**
  - Modified `loadBusData()` to support Documents directory
  - Added `getBusDataURL()` for intelligent file location
  - Added `reloadData()` for post-update refresh

### Technical Details
- **FirebaseDataManager.swift** (New - 280 lines)
  - `checkForUpdates()`: 24-hour throttled version checking
  - `downloadBusData()`: Progress-tracked download with MD5 verification
  - `installDownloadedData()`: Safe installation with version tracking
  - Uses `Insecure.MD5` from CryptoKit for integrity checks
  - Anonymous authentication for Firebase Security Rules

## [0.11.1] - 2025-12-13

### Fixed
- **🐛 Environment Variable Loading**
  - Fixed `.env` file not being loaded when Firebase libraries are not installed
  - Separated `python-dotenv` loading from Firebase library imports
  - Now loads environment variables immediately at script startup
  - Ensures `OUTPUT_DIRECTORY` and `LOG_DIRECTORY` are always respected

### Changed
- **📦 Dependency Handling**
  - `python-dotenv` is now treated as independent from Firebase libraries
  - Better error messages when libraries are missing
  - Script provides clearer installation instructions

### Testing
- ✅ Verified complete workflow with correct directory structure
- ✅ Confirmed backup mechanism works (`output/backup/`)
- ✅ All 7 validation checks pass
- ✅ Metadata generation working correctly
- ✅ 2,103 routes and 9,250 stops collected successfully
- ✅ Firebase Admin SDK installed and tested
- ✅ Manual upload to Firebase Storage successful (17.05 MB data + 487 bytes metadata)
- ✅ Verified file integrity with MD5 checksums
- ✅ Confirmed metadata download from Firebase works

## [0.11.0] - 2025-12-12

### Added - Python Data Collection & Firebase Infrastructure
- **🔍 Enhanced Data Validation System**
  - Expanded from 4 to 7 comprehensive validation checks
  - New checks: required fields completeness, direction consistency, company validity, stop-route mapping
  - Automatic validation report generation (`validation_report.json`) with detailed check results
  - Enhanced coordinate validation including NaN/Infinity detection and zero coordinate checks
  - Warnings for orphaned stops (stops with no routes) while maintaining threshold-based error detection

- **📋 Bus Data Metadata Generation**
  - New `generate_metadata()` method creates `bus_data_metadata.json` with version control information
  - Includes MD5 and SHA256 checksums for file integrity verification
  - Contains file size, route/stop counts, and Firebase download URL
  - Enables iOS app to check for updates without downloading full 18MB file (metadata is only ~2KB)

- **💾 Automatic Backup System**
  - New `create_backup()` method creates timestamped backups before each new data generation
  - Automatic cleanup keeps only last 7 backups to save disk space
  - Backup naming format: `bus_data_YYYYMMDD_HHMMSS.json`
  - Stored in separate `backup/` subdirectory for organization

- **📤 Manual Firebase Upload Script**
  - New standalone `manual_upload_firebase.py` for easy manual uploads during development
  - Automatic metadata generation/verification before upload
  - Uploads both `bus_data.json` and `bus_data_metadata.json` to Firebase Storage
  - Comprehensive environment validation and error reporting
  - Display upload summary with version, checksums, and statistics

### Changed
- **🔄 Data Collection Workflow**
  - Updated main() execution flow: collect → validate → backup → save → generate metadata → upload
  - Moved from 6-step to 8-step process with backup and metadata generation
  - Enhanced logging with clear step separators for better monitoring

### Technical Details
- **collect_bus_data_optimized_concurrent.py**
  - `validate_data()`: Lines 481-661 → 7-check validation system with detailed reporting
  - `create_backup()`: Lines 711-744 → Timestamped backup with automatic cleanup
  - `generate_metadata()`: Lines 746-802 → MD5/SHA256 checksums + metadata generation
  - `main()`: Lines 804-883 → Updated workflow with backup and metadata steps

- **manual_upload_firebase.py** (New File)
  - Standalone script for manual Firebase uploads during development
  - Environment verification, metadata generation, and dual-file upload
  - 249 lines with comprehensive error handling and progress reporting

## [0.10.1] - 2025-12-12

### Fixed
- **🔧 Custom Keyboard State Synchronization (Critical)**
  - Fixed race condition in `isUpdatingFromKeyboard` flag that caused search to be skipped during rapid key presses
  - Changed from asynchronous to synchronous flag reset using `defer` statement
  - Eliminated circular update prevention issues between keyboard input and search bar
  - Enhanced `textDidChange` guard clause for more robust checking

- **🔄 Search Results Display Logic**
  - Fixed issue where clearing search bar wouldn't reload nearby routes when `busDisplayData` already had content
  - Removed conditional `busDisplayData.isEmpty` checks in `syncSearchStates` (2 locations)
  - Now always reloads nearby routes when returning from search mode for data consistency
  - Ensures UI state matches search bar state in all scenarios

- **📊 Table View Update Reliability**
  - Added explicit `tableView.reloadData()` calls in search results success and failure cases
  - Implemented nested `DispatchQueue.main.async` to ensure reload completes before scrolling
  - Prevents race conditions between data updates and UI refresh

- **🎯 Search State Consistency**
  - Simplified `performSearch()` logic by removing recursive calls
  - Direct state variable updates instead of recursive `performSearch()` invocation
  - Added state consistency validation in keyboard timer callbacks
  - Prevents infinite loops and ensures reliable search execution

- **🎨 Keyboard Z-Index Overlay**
  - Fixed floating refresh button appearing above custom keyboard
  - Restored original `viewDidLoad` setup order for proper view hierarchy
  - Added `view.bringSubviewToFront(customKeyboard)` in both `setupUI()` and `showKeyboard()`
  - Ensures keyboard always overlays floating button when visible

- **⏱️ Timer-Based Search Validation**
  - Added state consistency checks before search execution in 300ms debounce timers
  - Validates `searchBar.text` matches `currentSearchText` before triggering API call
  - Automatically syncs states if mismatch detected during timer execution
  - Applied to both `keyboardDidTapNumber` and `keyboardDidTapLetter` methods

### Technical Details
- **SearchViewController.swift Changes**
  - `updateSearchBar()`: Lines 1373-1387 → Synchronous flag reset with `defer`
  - `textDidChange`: Line 1014 → Changed `if` to `guard !isUpdatingFromKeyboard`
  - `syncSearchStates()`: Lines 1408-1413, 1428-1433 → Removed `busDisplayData.isEmpty` conditionals
  - `performSearch()`: Lines 930-965 → Eliminated recursive call, direct state updates
  - `searchRoutes()`: Lines 994-1009 → Added explicit `reloadData()` and nested async scrolling
  - `keyboardDidTapNumber/Letter`: Lines 1310-1321, 1333-1344 → Added timer validation logic
  - `showKeyboard()`: Line 252 → Added `view.bringSubviewToFront(customKeyboard)`
  - `setupUI()`: Line 167 → Added `view.bringSubviewToFront(customKeyboard)`

### Performance Impact
- Minimal performance overhead from removed `busDisplayData.isEmpty` checks
- Protected by existing caching mechanisms (10-min location cache, 30-min API cache)
- Net improvement in UI responsiveness and state consistency

### Changed
- **⚙️ Settings Icon Design Update**
  - Replaced emoji gear icon "⚙️" with SF Symbol flat icon `gearshape.fill`
  - Consistent visual style with other system icons throughout the app
  - Enhanced professional appearance with native iOS iconography
  - 18pt medium weight icon matches button area dimensions
  - Automatic dark mode adaptation with label tint color

### Technical
- **BusListViewController.swift Updates**
  - Modified settings button configuration to use `UIImage(systemName:withConfiguration:)` (line 139-142)
  - Replaced `setTitle()` with `setImage()` for SF Symbol display
  - Updated color system from `setTitleColor` to `tintColor` for proper icon rendering
  - Added `UIImage.SymbolConfiguration` for precise icon sizing (18pt, medium weight)

## [1.0.0] - 2025-10-30

### Added
- **☁️ Firebase Storage Integration (Python Script)**
  - Complete Firebase Admin SDK integration for automated data uploads
  - Automatic upload of `bus_data.json` (17MB) to Firebase Storage
  - Metadata support: version (Unix timestamp), generated_at, file_size, route/stop counts
  - Smart fallback: continues with local save if Firebase unavailable

- **📅 Version Management System**
  - Unix timestamp-based versioning for JSON data files
  - Python script generates unique version number for each data collection run
  - iOS app can read version from JSON for future update checks
  - Foundation for automatic update detection (prevents redundant downloads)

- **📝 Comprehensive Logging System (Python)**
  - Structured logging to both file and console
  - Daily log files with timestamps: `bus_data_collection_YYYYMMDD_HHMMSS.log`
  - Detailed execution tracking: API calls, processing steps, errors
  - Configurable log directory via environment variables

- **🔒 Environment-Based Configuration**
  - `.env` file support for secure credential management
  - Configurable paths: Firebase service account, output directory, log directory
  - Never commit sensitive credentials to repository
  - Easy deployment to different environments (local, NAS, cloud)

- **✅ Data Validation Before Upload**
  - Automatic validation: minimum routes (>1500), stops (>5000), coordinate bounds
  - Hong Kong GPS bounds checking (22.0-22.7N, 113.8-114.5E)
  - Consistency checks: routes must have stops, stop references must be valid
  - Upload blocked if validation fails (prevents corrupted data distribution)

- **📚 Complete Documentation**
  - `FIREBASE_SETUP.md`: Step-by-step Firebase project setup guide
  - `NAS_DEPLOYMENT_QNAP.md`: Full QNAP NAS deployment instructions with cron job setup
  - `requirements.txt`: Python dependencies with version locking
  - `.env.example`: Environment variable template

### Changed
- **🐍 Python Script Major Refactor**
  - Renamed output file: `bus_data_optimized_concurrent.json` → `bus_data.json` (cleaner)
  - Absolute path handling for NAS cron job compatibility
  - Exit codes: 0 (success), 1 (upload failed), 2 (collection failed), 130 (interrupted)
  - Enhanced error handling with detailed logging

- **📱 iOS Data Model Updates**
  - `LocalBusData` struct now includes optional `version: Int?` field
  - Backward compatible: existing JSON without version still loads correctly
  - Version display in console logs with human-readable date format
  - New `getCurrentVersion()` method for future Firebase update checks

### Technical
- **Python Dependencies**
  - Added: `firebase-admin==6.3.0` (Firebase Storage SDK)
  - Added: `python-dotenv==1.0.0` (Environment variable management)
  - Retained: `requests==2.31.0` (API calls)

- **Python Script Architecture**
  - New: `setup_logging()` - Configures dual logging (file + console)
  - New: `initialize_firebase()` - Firebase Admin SDK initialization with validation
  - New: `upload_to_firebase_storage()` - Upload with metadata and error handling
  - Enhanced: `validate_data()` - Pre-upload data integrity checks
  - Modified: `finalize_and_save()` - Uses configurable output directory
  - Modified: `main()` - Orchestrates collection → validation → save → upload workflow

- **iOS LocalBusDataManager.swift**
  - Added `version: Int?` to `LocalBusData` struct (line 256)
  - Added version display in `loadBusData()` with date formatting (lines 40-45)
  - Added `getCurrentVersion()` helper method (lines 23-26)
  - CodingKeys updated to include `version` field

### Infrastructure
- **QNAP NAS Ready**
  - Cron job compatible with absolute paths and environment variables
  - Log rotation recommendations included in deployment guide
  - Email notification setup (optional)
  - Health check commands for monitoring

- **Security**
  - Firebase service account keys never committed to git
  - 600 permissions recommended for credentials
  - Environment variables for all sensitive data
  - Firebase Security Rules setup instructions

### Performance
- **Execution Time**: ~4-7 minutes total
  - Data collection: 3-5 minutes (unchanged)
  - Validation: <1 second
  - Local save: <2 seconds
  - Firebase upload: 10-30 seconds (network dependent)
- **Success Rate**: 100% API calls (3,356 successful calls in test run)
- **Data Output**: 17.00 MB JSON, 2,091 routes, 9,232 stops

### Deployment
- **Scheduled Updates**: Cron job every 3 days at 3:00 AM
- **Automatic Uploads**: No manual intervention required after setup
- **Error Handling**: Exit codes enable monitoring scripts
- **Log Retention**: Automatic cleanup (30-day rotation recommended)

## [0.8.10] - 2025-10-24

### Added
- **📍 Tap-to-Navigate from "我的" Page**
  - Tapping favorite route items in "我的" page now navigates to full route detail view
  - Seamless navigation to RouteDetailViewController with complete route information
  - Custom CATransition animation for smooth entry (0.3s, moveIn from right)
  - Identical navigation experience as route search and station pages

- **🎯 Smart Stop Auto-Expansion from Favorites**
  - Route detail view now auto-expands the specific stop user favorited (not nearest stop)
  - New `targetStopId` parameter in RouteDetailViewController for precise stop targeting
  - Priority-based expansion: target stop → nearest stop (fallback)
  - Enhanced user flow: tap favorite → open route → see YOUR stop automatically expanded
  - Works seamlessly with existing auto-expand logic for location-based scenarios

### Improved
- **🎨 Navigation Bar Consistency**
  - Fixed navigation bar visibility when entering route details from "我的" page
  - Navigation bar (with route number and company badge) now displays correctly from all entry points
  - Consistent UI presentation regardless of source view controller
  - Explicit `setNavigationBarHidden(false)` in RouteDetailViewController ensures proper display

- **✨ Enhanced Navigation Experience**
  - Edit mode check prevents navigation during route reordering/deletion
  - Table row deselects with animation after tap for polished interaction
  - All UI elements (navigation bar, route info, stops) appear consistently
  - Smooth transition animations unified across entire app

### Technical
- **BusListViewController.swift Navigation Updates**
  - Added QuartzCore import for CATransition support (line 2)
  - Implemented `didSelectRowAt` method with edit mode guard (line 797-822)
  - Passes `targetStopId` to RouteDetailViewController for auto-expansion
  - Custom transition: CATransition with 0.3s duration, moveIn type, fromRight subtype

- **RouteDetailViewController.swift Target Stop Support**
  - Added optional `targetStopId` property for favorites-based expansion (line 10)
  - Modified init to accept optional `targetStopId` parameter (line 36-41)
  - Created `expandTargetStop()` method for target stop expansion with fallback (line 347-397)
  - Enhanced `tryAutoExpandNearestStop()` to prioritize target stop (line 372-376)
  - Added `setNavigationBarHidden(false)` in viewWillAppear for consistent UI (line 72-73)

### Fixed
- **🔧 Navigation Bar Missing from "My" Page Entry**
  - Fixed issue where navigation bar disappeared when entering route details from favorites
  - Root cause: BusListViewController hides navigation bar, RouteDetailViewController didn't restore it
  - Solution: Explicit navigation bar show in RouteDetailViewController's viewWillAppear
  - All route detail UI elements now display correctly regardless of entry point

- **🎯 Auto-Expand Wrong Stop Issue**
  - Fixed route details always expanding nearest stop instead of user's favorited stop
  - Implemented target stop identification and expansion before location-based expansion
  - Users now see the exact stop they favorited when navigating from "我的" page
  - Maintains fallback to nearest stop when no target specified (search/station entry points)

## [0.8.9] - 2025-10-24

### Added
- **✨ Route Detail Stop Highlighting**
  - Expanded stops now display with 10% blue background highlight for better visual feedback
  - Blue highlight color matches the ETA text color system for consistent design language
  - Smooth 0.2-second fade animation when expanding/collapsing stops
  - Highlight automatically updates based on ETA display state
  - Enhanced user experience by clearly indicating which stop is currently showing ETA information

### Improved
- **🎨 Visual Feedback Enhancement**
  - Background color dynamically changes when tapping stop items to show/hide ETA
  - Highlight persists during auto-refresh cycles for consistent visual state
  - Touch highlight behavior updated to preserve blue background when releasing finger
  - Expanded stops remain visually distinct from collapsed stops throughout interaction

### Technical
- **RouteStopTableViewCell.swift Updates**
  - Modified `loadAndShowETA()` to set `containerView.backgroundColor` to 10% blue (line 232-234)
  - Modified `hideETA()` to restore `secondarySystemBackground` color (line 267-270)
  - Enhanced `setHighlighted()` to preserve blue background for expanded stops (line 365-377)
  - Leverages existing `isShowingETA` state for automatic highlight management
  - Zero changes needed in `RouteDetailViewController` - uses existing expand/collapse logic
  - Automatic support for all scenarios: auto-expand, manual tap, ETA refresh

## [0.8.8] - 2025-10-23

### Changed
- **📱 Smart Tab Restoration System**
  - App now remembers last used tab across app launches for better UX continuity
  - Kill app and reopen will restore your last selected tab automatically
  - Each tab resets to its first page when restored (navigation stack cleared)
  - First-time users see route discovery page ("路線") to encourage exploration
  - Returning users with favorites see their last used tab for seamless workflow

### Improved
- **🎯 Intelligent First Launch Detection**
  - App detects first-time installations and opens "路線" tab for discovery
  - Users with existing favorites get tab memory functionality immediately
  - No more forced navigation to specific tabs based on favorites count
  - Tab selection persists regardless of favorites data changes
  - Natural user flow encourages adding favorites without forced interactions

### Technical
- **MainTabBarController.swift Tab Memory Implementation**
  - Added `lastSelectedTabKey` UserDefaults key for persistent tab storage (line 6)
  - Implemented `setInitialTab()` method with priority-based tab restoration (line 72-108)
  - Priority: Saved tab → Favorites check (first launch only)
  - Modified `didSelect` to save tab selection on every switch (line 186)
  - Tab validation ensures invalid indices default to "我的" tab safely
  - Automatic `popToRootViewController` when restoring tabs for clean state

### Fixed
- **Tab Persistence Logic**
  - Fixed issue where app always opened "路線" tab after kill regardless of last used tab
  - Resolved problem where favorites count incorrectly controlled tab selection on every launch
  - UserDefaults now properly distinguishes between "never saved" (nil) and "saved 0" (integer)
  - Used `object(forKey:)` instead of `integer(forKey:)` to detect first launch accurately

## [0.8.7] - 2025-10-23

### Changed
- **⭐ Unified Favorite Management System**
  - Standardized all "Add to Favorites" actions across the entire app
  - All new favorites now automatically added to "我的" category for consistency
  - Eliminated confusing category variations ("從站點搜尋加入", stop names, "其他")
  - Simplified user mental model: one default category for all favorites
  - "我的" category automatically created if it doesn't exist

- **🔕 Silent Favorites Toggle**
  - Removed all popup notifications when adding/removing favorites
  - Star button now provides instant visual feedback without interruptions
  - Smoother user experience with unobtrusive favorite management
  - Background synchronization ensures "我的" page stays up-to-date automatically
  - Consistent silent behavior across route detail, station routes, and route search pages

### Improved
- **Enhanced UX Consistency**
  - Users can now add favorites from any page without modal disruptions
  - Favorites appear in predictable "我的" category regardless of origin
  - Star button state updates immediately reflect add/remove actions
  - Real-time synchronization via NotificationCenter keeps all views in sync
  - No user action required to see favorites changes across tabs

### Technical
- **RouteDetailViewController.swift Updates**
  - Modified `toggleFavorite()` to use `subTitle: "我的"` instead of stop name (line 490)
  - Removed `showMessage()` method and all popup alert calls
  - Changed error handling from popup to console logging (line 509)

- **StopRoutesViewController.swift Updates**
  - Modified `toggleFavorite()` to use `subTitle: "我的"` instead of "從站點搜尋加入" (line 401)
  - Removed `showMessage()` method and all popup alert calls

- **SearchViewController.swift Updates**
  - Modified `toggleFavorite()` to explicitly specify `subTitle: "我的"` instead of relying on default (line 1174)
  - Changed from `addFavorite(busRoute)` to `addFavorite(busRoute, subTitle: "我的")`

- **FavoritesManager.swift Default Value**
  - Default `subTitle` parameter remains `"其他"` for backward compatibility (line 43)
  - All active code paths now explicitly specify `"我的"` to override default
  - Ensures consistent category assignment across all user-facing features

### Fixed
- **Category Consistency Issues**
  - Fixed inconsistent favorite categories created from different pages
  - Resolved user confusion about where favorites would appear
  - Eliminated category fragmentation (stop names, search origin, "其他")

## [0.8.6] - 2025-10-23

### Fixed
- **🔒 Edit Mode Only Swipe-to-Delete**
  - Fixed issue where swipe-to-delete was available at all times on "我的" page
  - Swipe-to-delete now only enabled when in editing mode (after tapping "編輯" button)
  - Prevents accidental deletion while browsing favorite routes
  - Safer user experience with intentional edit mode requirement
  - All other editing features (reorder, category management) remain unchanged

### Technical
- **BusListViewController.swift Updates**
  - Modified `tableView(_:canEditRowAt:)` to return `tableView.isEditing` instead of `true` (line 727)
  - Edit mode must be explicitly activated before swipe gestures enable deletion
  - Consistent with iOS best practices for destructive actions

## [0.8.5] - 2025-10-23

### Fixed
- **🔍 Route Search Pull-to-Refresh Conflict**
  - Fixed critical issue where pull-to-refresh triggered during active search
  - Pull-to-refresh now completely hidden when displaying search results
  - Resolved iOS limitation: `refreshControl.isEnabled = false` does not prevent triggering
  - Solution: Dynamically set `tableView.refreshControl = nil` during search mode
  - Re-adds refresh control automatically when returning to nearby routes mode
  - Prevents accidental search clearing when scrolling down search results
  - Cleaner visual experience without refresh control spinner during search

### Technical
- **SearchViewController.swift UIRefreshControl Management**
  - Modified `searchRoutes()` success handler to set `refreshControl = nil` (line 694)
  - Updated 7 locations to restore refresh control when showing nearby routes:
    - `performSearch()` when query is empty (line 659)
    - `textDidChange` when search cleared (line 745)
    - `searchBarCancelButtonClicked()` when cancel tapped (line 783)
    - `loadRoutesFromNearbyStops()` after loading routes (line 473)
    - `keyboardDidTapBackspace()` when search emptied (line 1048)
    - `syncSearchStates()` first empty state check (line 1107)
    - `syncSearchStates()` second empty state check (line 1129)
  - Replaced all `refreshControl?.isEnabled = true/false` with `= refreshControl / = nil`
  - Apple-recommended solution: setting refreshControl to nil is only way to disable
  - UIRefreshControl responds to scroll view content offset changes, not touch events

### Improved
- **Better Search UX**
  - Search results can be scrolled freely without refresh control interference
  - No visual distraction from refresh control spinner during search
  - Instant refresh control restoration when clearing search
  - Consistent behavior across all search state transitions

## [0.8.4] - 2025-10-23

### Fixed
- **⭐ Star Button Touch Responsiveness**
  - Fixed critical issue where star icon was blocking touch events from reaching the 44x44px button underneath
  - Changed `starImageView.isUserInteractionEnabled` from `true` to `false` to allow touch pass-through
  - Full 44x44px touch area now properly responsive (meets WCAG and Apple HIG minimum touch target)
  - Star button now works consistently across all pages (BusETATableViewCell and RouteStopTableViewCell)

- **🔄 Real-Time Favorites Synchronization**
  - Fixed issue where "我的" page required manual refresh after adding/removing favorites from other pages
  - Implemented NotificationCenter-based real-time synchronization across all pages
  - Adding/removing favorites from route detail page or station page now instantly updates "我的" page
  - Eliminated need for manual pull-to-refresh to see favorites changes
  - Consistent user experience across entire app with immediate feedback

### Technical
- **FavoritesManager.swift Notification System**
  - Added `favoritesDidChangeNotification` static property for favorites change events
  - Modified `addFavorite()` method to post notification after successful add (line 61)
  - Modified `removeFavorite()` method to post notification after successful remove (line 77)
  - Lightweight observer pattern similar to FontSizeManager implementation

- **BusListViewController.swift Auto-Refresh Integration**
  - Added notification observer for `FavoritesManager.favoritesDidChangeNotification` (line 40-44)
  - Implemented `favoritesDidChange()` method to reload data automatically (line 59-62)
  - Proper observer cleanup in existing `deinit` to prevent memory leaks
  - No manual user action required - favorites sync happens transparently

### Improved
- **Real-Time UX Enhancement**
  - Instant favorites updates across all tabs and navigation stacks
  - No visual delay or loading indicators needed - changes appear immediately
  - Users can add/remove favorites from any page and see changes reflected instantly
  - Enhanced app responsiveness and modern iOS app behavior

## [0.8.3] - 2025-10-23

### Improved
- **♿ Extended WCAG AAA Accessibility to Destination and Search Result Text**
  - **Destination labels** ("→ 目的站點") now use 85% opacity white/black for AAA compliance
  - **Search result direction text** upgraded from AA (4.5:1) to AAA (7.3:1) contrast
  - **Font size enhancement**: Destination text increased by 1pt for better readability
    - Normal mode: 14pt → 15pt (+1pt)
    - Large mode: 16pt → 17pt (+1pt)
  - Consistent visual hierarchy across all secondary information displays
  - All direction and destination text now meets WCAG AAA standard with excellent readability

### Technical
- **FontSizeManager.swift Updates**
  - Modified `destinationFontSize`: 14pt → 15pt (normal), 16pt → 17pt (large) (line 69-72)
  - Enhanced font size for destination labels while maintaining +2pt difference for large mode

- **BusETATableViewCell.swift Color System**
  - Destination label color: `secondaryLabel` → 85% opacity white/black (line 94-99)
  - Applied dynamic color system matching second/third ETA times
  - WCAG AAA compliant: 7.3:1 contrast ratio in both light and dark modes

- **SearchResultTableViewCell.swift Color Enhancement**
  - Subtitle (direction) color: `secondaryLabel` → 85% opacity white/black (line 64-69)
  - Unified color treatment with destination labels and ETA times
  - Maintains excellent readability across all lighting conditions

### Accessibility
- **Complete WCAG AAA Coverage for All Secondary Text**
  - **AAA Level (7.5:1)**: First ETA time, primary labels
  - **AAA Level (7.3:1)**: Second/third ETA, destination labels, search result directions
  - **AA Level (4.5:1)**: Distance labels, sequence numbers, status messages
  - **Enhanced font sizes**: All destination text 1pt larger for improved legibility
  - **Unified visual system**: Consistent 85% opacity treatment for all secondary informational text
  - **Dynamic adaptation**: Perfect contrast ratios maintained in both light and dark modes

## [0.8.2] - 2025-10-22

### Improved
- **♿ WCAG AAA Accessibility Compliance for All ETA Times with Visual Hierarchy**
  - **ALL ETA times now meet WCAG AAA level** (7.0:1+ ratio) for maximum readability
  - First ETA: Deep blue #003D82 (light mode) / systemTeal (dark mode) - contrast ratio 7.5:1
  - Second/third ETA: 85% opacity white/black for subtle visual distinction - contrast ratio 7.3:1
  - Smart opacity-based hierarchy maintains AAA compliance while providing visual differentiation
  - Enhanced all secondary text colors to meet WCAG AA level (4.5:1 ratio minimum) for better readability
  - Replaced all `UIColor.tertiaryLabel` with `UIColor.secondaryLabel` for improved contrast
  - Replaced all `UIColor.gray` with `UIColor.secondaryLabel` for consistent accessibility
  - Applied across all UI components: distance labels, sequence numbers, status messages, star icons
  - Ensures excellent readability for users with visual impairments across all lighting conditions

### Technical
- **BusETATableViewCell.swift Color Updates** (6 changes)
  - Distance label: `tertiaryLabel` → `secondaryLabel` (line 102)
  - Star icon unfilled state: `tertiaryLabel` → `secondaryLabel` (line 130, 320)
  - **Second/third ETA times: 85% opacity white (dark mode) / 85% opacity black (light mode)** (line 271-278)
  - "未有資料" status text: `gray` → `secondaryLabel` (line 260, 287)

- **RouteStopTableViewCell.swift Color Updates** (5 changes)
  - Sequence number label: `tertiaryLabel` → `secondaryLabel` (line 75)
  - Star icon unfilled state: `tertiaryLabel` → `secondaryLabel` (line 96, 340)
  - **Second/third ETA times: 85% opacity white (dark mode) / 85% opacity black (light mode)** (line 318-325)
  - "未有資料" / "載入失敗" status text: `gray` → `secondaryLabel` (line 309)

### Accessibility
- **Complete WCAG Compliance Matrix**
  - **AAA Level (7.5:1)**: First ETA time with deep blue #003D82 (light) / systemTeal (dark)
  - **AAA Level (7.3:1)**: Second/third ETA times with 85% opacity for subtle visual hierarchy
  - **AA Level (4.5:1)**: All secondary text including:
    - Distance information labels
    - Route sequence numbers
    - Status messages ("未有資料", "載入失敗")
    - Unfilled star (favorite) icons
  - **Label (21:1)**: Primary text (bus numbers, station names, route directions)
  - All text now meets or exceeds WCAG standards for maximum accessibility
  - **Sophisticated ETA hierarchy** uses opacity to distinguish priority while maintaining AAA compliance
  - **Dynamic adaptation** ensures perfect contrast in both light and dark modes

## [0.8.1] - 2025-10-22

### Improved
- **♿ WCAG AAA Accessibility Compliance for ETA Colors**
  - Enhanced first ETA color contrast to meet WCAG AAA level (7.5:1 ratio) for better readability
  - Light mode: Deep blue `#003D82` (RGB: 0, 61, 130) provides excellent contrast on white background
  - Dark mode: Maintains `systemTeal` for optimal visibility in dark environments
  - Dynamic color adaptation based on user interface style (light/dark mode)
  - Ensures maximum readability for users with visual impairments
  - Applied consistently across all pages: "我的", "路線", and route details

### Technical
- **BusETATableViewCell.swift Color System**
  - Replaced static `UIColor.systemCyan` with dynamic `UIColor { traitCollection }` closure
  - Light mode condition: `traitCollection.userInterfaceStyle == .dark ? systemTeal : #003D82`
  - Automatic color switching based on system appearance without notification listeners
  - WCAG AAA compliant deep blue for light mode (contrast ratio 7.5:1)

- **RouteStopTableViewCell.swift Color System**
  - Implemented identical dynamic color system for route detail page ETA display
  - Maintains visual consistency across all ETA display components
  - Automatic trait collection-based color selection for seamless appearance transitions

### Accessibility
- **Color Contrast Standards**
  - Light mode deep blue: `UIColor(red: 0.0, green: 0.24, blue: 0.51, alpha: 1.0)` achieves 7.5:1 contrast
  - Exceeds WCAG AA requirement (4.5:1) and meets AAA gold standard (7.0:1)
  - First ETA now easily readable for users with:
    - Low vision conditions
    - Color blindness (protanopia, deuteranopia)
    - Age-related vision changes
    - Screen viewing in bright sunlight conditions
  - Dark mode retains systemTeal for optimized dark theme visibility

## [0.8.0] - 2025-10-22

### Added
- **🎨 Appearance Setting Feature**
  - New "外觀" setting in Display Settings section with 3 options:
    - "自動" (Automatic): Follows system appearance preference
    - "淺色" (Light): Forces light mode across entire app
    - "深色" (Dark): Forces dark mode across entire app
  - Segmented control interface for easy switching between appearance modes
  - Instant appearance changes with smooth cross-dissolve transitions
  - Persistent appearance preference saved in UserDefaults
  - Applied automatically on app launch

### Improved
- **⚙️ Enhanced Settings Page Organization**
  - "外觀" setting positioned as first option in Display Settings section
  - "字體大細" setting follows below for logical grouping
  - Consistent UI with other segmented control settings
  - Non-blocking bottom toast notifications for setting changes

- **🎨 Modern Toast Notification System**
  - Replaced modal alert-based toast with bottom-positioned toast view
  - Toast appears at screen bottom (20px above safe area) without blocking user interaction
  - Smooth fade in/out animations (0.3s duration)
  - Auto-dismisses after 1.5 seconds
  - Dark mode adaptive styling with inverted colors (dark background + light text)
  - Rounded corners (12px) for modern iOS appearance
  - Users can continue interacting with settings while toast is visible

### Technical
- **New AppearanceManager.swift Service**
  - Singleton pattern for centralized appearance management
  - `AppearanceMode` enum with 3 cases: automatic, light, dark
  - UserDefaults persistence with "AppearanceMode" key
  - `applyAppearance()` method applies changes to window with 0.3s transition
  - `applySavedAppearance()` method restores saved preference on launch
  - UIUserInterfaceStyle mapping for proper system integration

- **SettingsViewController.swift Updates**
  - Added `appearanceChanged(_:)` action method for segmented control
  - Updated Display Settings section to show 2 rows (appearance + font size)
  - Enhanced cell configuration logic to handle row-based settings
  - Integrated AppearanceManager for reading/writing appearance state

- **SceneDelegate.swift Integration**
  - Added `AppearanceManager.shared.applySavedAppearance()` call in `scene(_:willConnectTo:options:)`
  - Ensures appearance preference is applied immediately on app launch
  - Seamless integration with existing app initialization flow

- **SettingsViewController.swift Toast System**
  - Replaced `UIAlertController`-based blocking toast with custom non-blocking toast view
  - `showToast(message:)` method creates temporary UIView with label and animations
  - Toast positioned at bottom with constraints: 20px above safe area, 40px side margins
  - Auto-layout system ensures proper centering and adaptive width
  - Automatic cleanup via `removeFromSuperview()` after animation completes

## [0.7.0] - 2025-10-22

### Added
- **🎨 Professional Empty State Experience**
  - Beautiful empty state view for first-time app installations with no user data
  - 325x225px custom illustration (empty.png) guiding users to add favorites
  - Clear two-tier messaging system:
    - Primary: "未有收藏路線" (24pt semibold, label color - dark/high contrast)
    - Secondary: "前往路線或站點頁面，點擊星號按鈕即可加入收藏" (16pt regular, secondaryLabel)
  - ScrollView support enables content scrolling on small screens (iPhone SE, etc.)
  - Preserved pull-to-refresh functionality even when empty (consistent UX across all states)
  - Empty state positioned with proper header/tab bar insets (40px top/bottom padding)

### Changed
- **🚀 No Default Data Auto-Loading**
  - Eliminated automatic default route initialization on first launch
  - Fresh installations now show empty "我的" page instead of developer's personal routes
  - User-driven onboarding encourages exploration and personalization
  - App always launches on "我的" tab (index 0) regardless of empty/populated state
  - Removed auto-switching behavior that previously redirected to "路線" tab when empty

- **🎨 Enhanced Text Readability**
  - Empty state title color upgraded: secondaryLabel → label (significantly darker)
  - Empty state subtitle color improved: tertiaryLabel → secondaryLabel (better contrast)
  - Optimized for both light and dark modes with adaptive system colors
  - Text remains highly readable even on small or low-brightness screens

### Improved
- **📱 Responsive Empty State Design**
  - Content container with proper constraints for all screen sizes
  - ScrollView enables vertical scrolling when screen height is insufficient
  - Maintains visual centering on larger screens (iPhone Pro Max, iPad)
  - Dynamic layout adapts to status bar, header, and tab bar heights
  - `alwaysBounceVertical = true` ensures pull-to-refresh always works

### Technical
- **FavoritesManager.swift Changes**
  - Removed `initializeDefaultFavoritesIfNeeded()` from `init()` method
  - `getAllFavorites()` now returns empty array `[]` on error instead of `BusRouteConfiguration.defaultRoutes`
  - Preserved `initializeDefaultFavoritesIfNeeded()` method for developer tools restore functionality

- **MainTabBarController.swift Updates**
  - Modified `checkAndSetInitialTab()` to always stay on "我的" tab (no auto-switching)
  - Removed automatic navigation to "路線" tab when favorites are empty
  - Simplified launch logic: track first launch but don't change selected index
  - Removed `resetInitialTabBehavior()` method (no longer needed)

- **BusListViewController.swift Enhancements**
  - Added `emptyStateView` with ScrollView for responsive layout
  - Created `setupEmptyStateView()` with comprehensive empty state UI
  - Modified `updateEmptyState()` to manage visibility without hiding tableView (preserves pull-to-refresh)
  - Removed automatic tab switching logic from delete operations
  - Empty state asset loaded from Assets.xcassets via `UIImage(named: "empty")`

- **Assets.xcassets Structure**
  - Created `empty.imageset` directory with proper Contents.json
  - Added empty.png (325x225px) to asset catalog for system-managed image loading
  - Supports @1x, @2x, @3x scales for all device resolutions

### Fixed
- **Pull-to-Refresh on Empty State**
  - Fixed issue where refresh control disappeared when "我的" page was empty
  - Solution: Keep tableView visible (not hidden) and layer emptyStateView on top
  - Ensures consistent pull-to-refresh UX regardless of favorites count
  - Refresh control properly appears above empty state content

## [0.6.1] - 2025-10-22

### Changed
- **🔡 Enhanced Font Size System**
  - Increased all normal font sizes by 3pt for better readability across the app
  - Updated large font mode to maintain +2~3pt difference from normal mode

### Improved
- **🔡 Updated Font Size Scale Table**
  | Element | Normal | Large | Increase |
  |---------|--------|-------|----------|
  | Bus Number | 34pt | 38pt | +4pt |
  | Station Name | 16pt | 18pt | +2pt |
  | Destination | 14pt | 16pt | +2pt |
  | ETA Time | 17pt | 19pt | +2pt |
  | Station Name (Search) | 24pt | 27pt | +3pt |
  | Section Header | 16pt | 18pt | +2pt |
  | Route Detail Number | 32pt | 36pt | +4pt |
  | Regular Text | 17pt | 19pt | +2pt |
  | Small Text | 15pt | 17pt | +2pt |

### Technical
- **FontSizeManager.swift Updates**
  - Modified `stopNameFontSize`: 13pt → 16pt (normal), 15pt → 18pt (large)
  - Modified `destinationFontSize`: 11pt → 14pt (normal), 13pt → 16pt (large)
  - Modified `etaTimeFontSize`: 14pt → 17pt (normal), 16pt → 19pt (large)
  - Modified `stationNameFontSize`: 21pt → 24pt (normal), 24pt → 27pt (large)
  - Modified `sectionHeaderFontSize`: 13pt → 16pt (normal), 15pt → 18pt (large)
  - Modified `regularTextFontSize`: 14pt → 17pt (normal), 16pt → 19pt (large)
  - Modified `smallTextFontSize`: 12pt → 15pt (normal), 14pt → 17pt (large)
  - Bus number and route detail number sizes remain unchanged (already optimal)

## [0.6.0] - 2025-10-21

### Added
- **⚙️ Comprehensive Settings Page**
  - New dedicated settings page accessible from "我的" page (replaced "更新" button with "設定" button)
  - Three main sections: Data Management, Display Settings, and About
  - Professional iOS-style `.insetGrouped` table view design
  - Settings navigation smoothly integrated into existing app flow

- **📊 Data Management Features**
  - **Update Route Data**: Manual refresh of stop data from hk-bus-crawling API
  - Loading indicators with user feedback during data updates
  - Success/failure alerts showing stop counts and error messages
  - Same functionality as previous "更新" button but in dedicated settings location

- **🔤 Dynamic Font Size System**
  - Global font size preference: Normal (default) or Large (+2~4pt)
  - Two-option segmented control for easy switching
  - Instant font size changes reflected across all pages
  - All text elements scale proportionally for better readability

- **ℹ️ App Information Display**
  - App version display with format "vX.X.X (Build XXX)"
  - Version info pulled from Info.plist (`CFBundleShortVersionString` + `CFBundleVersion`)
  - Clean, professional presentation

- **🛠️ Hidden Developer Tools**
  - Secret developer menu accessible via version area (left 50px×50px, 10 taps in 3 seconds)
  - **Reset to Default Routes**: Clears all custom favorites and restores 14 default routes from reference file
  - **Re-download Reference Data**: Clears cache and re-downloads latest hk-bus-crawling data
  - Detailed app stats in developer menu (favorites count, stop data update time, local bus data summary)
  - Confirmation dialogs before destructive actions with clear warnings
  - Smart reset system matches `/my html reference/index.php` default route configuration

### Changed
- **🎨 Enhanced Font Management Architecture**
  - Created centralized `FontSizeManager` singleton for global font preferences
  - UserDefaults-based font size persistence across app launches
  - Font size preference stored as "normal" or "large" string values

- **📐 UI Component Updates**
  - All table view cells now support dynamic fonts via NotificationCenter
  - Font changes broadcast via `FontSizeManager.fontSizeDidChangeNotification`
  - View controllers listen for font changes and reload data automatically
  - Smooth, instant UI updates when font size changes

### Added
- **🛠️ Enhanced Developer Tools**
  - Added "Clear All Favorites Only" option to test empty "我的" page state
  - New option clears all favorites WITHOUT restoring default routes
  - Useful for testing empty page UI and edge cases
  - Clear warning messages distinguish between "reset" (restores defaults) and "clear" (leaves empty)

### Improved
- **🔡 Initial Font Size Scale Table** (Updated in v0.6.1)
  | Element | Normal | Large | Increase |
  |---------|--------|-------|----------|
  | Bus Number | 34pt | 38pt | +4pt |
  | Station Name | 13pt | 15pt | +2pt |
  | Destination | 11pt | 13pt | +2pt |
  | ETA Time | 14pt | 16pt | +2pt |
  | Station Name (Search) | 21pt | 24pt | +3pt |
  | Section Header | 13pt | 15pt | +2pt |
  | Route Detail Number | 32pt | 36pt | +4pt |
  | Regular Text | 14pt | 16pt | +2pt |
  | Small Text | 12pt | 14pt | +2pt |

### Technical
- **New Files Created**
  - `FontSizeManager.swift`: Global font management with NotificationCenter integration
  - `DeveloperToolsManager.swift`: Developer tools functionality with Core Data and cache clearing
  - `SettingsViewController.swift`: Complete settings UI with custom segmented control cells
  - `UIFont` extension added to `FontSizeManager.swift` for app-specific font helpers

- **Modified Components**
  - **BusListViewController**: Replaced "更新" (🔄) with "設定" (⚙️), added font change listener
  - **SearchViewController**: Added NotificationCenter observer for font size changes
  - **BusETATableViewCell**: Dynamic font updates with notification listener + manual update method
  - **SearchResultTableViewCell**: Font change support with live UI updates
  - **RouteStopTableViewCell**: Dynamic font scaling for stop names and sequence numbers
  - **StopSearchResultTableViewCell**: Font updates for station names, routes, and distance labels

- **Architecture Enhancements**
  - NotificationCenter-based reactive font updates for instant UI refresh
  - Automatic cleanup with `deinit` removing observers to prevent memory leaks
  - Centralized font definitions via `UIFont` extension (`.appBusNumber`, `.appStopName`, etc.)
  - Font manager calculates all sizes dynamically based on user preference
  - Developer tools with proper error handling and user feedback

- **Developer Tools Implementation**
  - `TapDetector` class tracks taps within 3-second window (10 taps required)
  - Core Data batch delete for efficient favorites clearing
  - `clearAllFavoritesOnly()` method for complete data removal without restore
  - File system cache management for stop data reset
  - Detailed app information export with version, favorites, and data stats

## [0.5.13] - 2025-10-21

### Fixed
- **📐 "我的" Page Scroll Behavior and Layout**
  - Fixed scroll indicator positioning to correctly show full scrollable range
  - Eliminated double-margin issue where scroll bar couldn't reach top or bottom
  - Resolved section header spacing with `sectionHeaderTopPadding = 0` for iOS 15+
  - Fixed content scrolling to properly reach last item without tab bar obstruction
  - Implemented proper content inset system for header and tab bar avoidance

### Improved
- **🎨 Fixed Header Layout Optimization**
  - Refined fixed header (status bar + buttons) positioning for pixel-perfect alignment
  - Section headers now stick directly below button area with no visible gap
  - Optimized button area padding: 8px top + 28px height + 8px bottom
  - Translucent blur background (`.systemMaterial`) for professional appearance
  - Content properly extends under translucent bars for full-screen experience

### Technical
- **BusListViewController Scroll System Refactoring**
  - Set `contentInsetAdjustmentBehavior = .never` for full manual control
  - Configured `contentInset` with proper top (header) and bottom (tab bar) spacing
  - Set `scrollIndicatorInsets = .zero` to prevent double-margin calculation
  - Added `sectionHeaderTopPadding = 0` to eliminate default iOS 15+ spacing
  - Implemented `viewDidLayoutSubviews()` for empty placeholder (no dynamic updates needed)
  - Created `headerView` property to store reference for potential future use
  - Proper constraint-based layout for fixed header overlay system

## [0.5.12] - 2025-10-20

### Fixed
- **🔍 Search Field Stability and State Synchronization**
  - Eliminated circular update loops between custom keyboard and search bar
  - Fixed critical state desynchronization between `searchBar.text` (UI) and `currentSearchText` (internal state)
  - Resolved issue where search results wouldn't appear after input due to state mismatch
  - Fixed empty search field behaving as if containing input, requiring multiple backspace presses
  - Added `isUpdatingFromKeyboard` flag to break circular update chains
  - Enhanced `textDidChange` delegate to detect and sync external input (paste, autocorrect)
  - Implemented comprehensive state validation in search operations

### Improved
- **⌨️ Custom Keyboard Performance and UX**
  - Removed all animations from letter button visibility changes for instant response
  - Implemented HTML float-left behavior for letter buttons (visible buttons flow continuously without gaps)
  - Dynamic row reorganization when button visibility changes (e.g., B hidden → first row shows [A, C])
  - Number buttons now instantly change state without animation delays
  - Unified 0.3s debounce across all input methods (custom keyboard + direct input)
  - Search consistency validation prevents API calls with mismatched states

### Technical
- **SearchViewController State Management**
  - Added `isUpdatingFromKeyboard: Bool` flag to prevent circular updates (line 27)
  - Enhanced `updateSearchBar()` with flag protection and async reset (line 977-991)
  - Modified `textDidChange` to skip processing during keyboard updates and sync states (line 672-708)
  - Added debounce to `keyboardDidTapNumber()` and `keyboardDidTapLetter()` (line 942-968)
  - Enhanced `keyboardDidTapBackspace()` with debounce and state sync recovery (line 970-1017)
  - Added search consistency validation in `performSearch()` (line 617-648)

- **BusRouteKeyboard Float-Left Layout**
  - Created `reorganizeLetterButtons()` method for dynamic row reconstruction (line 188-232)
  - Modified `setupLettersSection()` to defer row creation until runtime (line 127-184)
  - Enhanced `updateButtonEnabled()` with `isLetter` parameter for different behaviors (line 304-336)
  - Letter buttons: `isHidden = true` (hide and reorganize with float-left flow)
  - Number buttons: `isEnabled = false` (disable but stay visible for grid stability)
  - Removed UIView animations for instant button state changes (0.0s vs 0.2s)
  - Auto Layout constraint order fix: add to hierarchy before setting inter-view constraints

- **SearchResultTableViewCell Typography**
  - Increased subtitle font size from 13pt to 15pt for better readability (line 42)

## [0.5.11] - 2025-10-19

### Improved
- **🔄 Unified Pull-to-Refresh UI Across All Pages**
  - Standardized pull-to-refresh appearance and behavior throughout the entire app
  - All refresh controls now use consistent dark mode-adaptive styling (`UIColor.label`)
  - Added contextual text labels to clearly indicate refresh action:
    - "我的" page: "更新路線" (Update Routes)
    - "路線" page: "更新附近路線" (Update Nearby Routes) - existing
    - "站點" page: "更新站點" (Update Stops) - newly added
    - Station details page: "更新路線" (Update Routes) - newly added
    - Stop ETA page: "更新到站時間" (Update Arrival Times)
  - Enhanced user experience with consistent visual feedback during data refresh
  - Full dark mode support with automatic color adaptation

### Added
- **📍 Pull-to-Refresh for Station Search Page**
  - Added manual refresh capability to reload nearby stops with fresh GPS data
  - Clears location cache to force new location request for most accurate results
  - Resets search state and returns to nearby stops view
  - 1-second delay for smooth user feedback

- **🚌 Pull-to-Refresh for Station Details Page**
  - Added manual refresh to reload all route ETAs for selected station
  - Updates complete route list with latest arrival time information
  - Consistent with other pages' refresh behavior
  - Enhanced station page interactivity

### Technical
- **BusListViewController Updates**
  - Changed `refreshControl.tintColor` from `systemBlue` to `label` for dark mode support
  - Added `attributedTitle` with "更新路線" text (14pt system font)
  - Standardized refresh control configuration

- **StopETAViewController Updates**
  - Added `attributedTitle` with "更新到站時間" text (14pt system font)
  - Maintained existing `label` tint color for consistency

- **StopSearchViewController Updates**
  - Added `refreshControl` property of type `UIRefreshControl`
  - Implemented `handleRefresh()` method to clear cache and reload nearby stops
  - Added refresh control setup in `setupTableView()` with standardized configuration
  - Text label: "更新站點" with dark mode-adaptive styling

- **StopRoutesViewController Updates**
  - Added `refreshControl` property of type `UIRefreshControl`
  - Implemented `handleRefresh()` method to reload routes and ETAs
  - Added refresh control setup in `setupTableView()` with standardized configuration
  - Text label: "更新路線" with dark mode-adaptive styling

- **Standardized Configuration Pattern**
  ```swift
  refreshControl.tintColor = UIColor.label
  refreshControl.attributedTitle = NSAttributedString(
      string: "適當的文字",
      attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
  )
  ```

## [0.5.10] - 2025-10-19

### Fixed
- **🔍 Station Search Input Sensitivity**
  - Reduced minimum search character requirement from 2 to 1 character
  - Users can now search stations with single character input (e.g., "中", "尖", "旺")
  - Improved search responsiveness with 0.5 second debounce delay
  - Enhanced user experience for faster station discovery

### Technical
- **StopSearchViewController Updates**
  - Modified `performSearch()` validation logic to accept queries with 1+ characters
  - Updated inline documentation to reflect new minimum character requirement
  - Maintains existing debounce behavior for optimized API performance

## [0.5.9] - 2025-10-18

### Changed
- **🔄 Improved Tab Bar Navigation Behavior**
  - Tab switching now preserves navigation stacks for better user experience
  - Route tab (路線) and stop tab (站點) maintain navigation history when switching between tabs
  - Repeat tapping route tab pops to search root and shows keyboard
  - Repeat tapping stop tab pops back one level in navigation stack
  - Enhanced navigation flow consistency across the app

### Technical
- **MainTabBarController Updates**
  - Removed automatic `popToRootViewController` when switching to route tab from other tabs
  - Added navigation stack preservation logic for tab switching
  - Implemented stop search tab (index 2) repeat tap handling with `popViewController`
  - Route search tab (index 1) now only pops to root on repeat tap, not on tab switch
  - Enhanced tab selection delegate methods with context-aware navigation logic

## [0.5.8] - 2025-10-18

### Changed
- **🚌 Improved Station Route Navigation**
  - Station details page (站點詳細頁面) now opens full route detail page when tapping route items
  - Consistent navigation behavior across app: route search page and station page both navigate to RouteDetailViewController
  - Users can now view complete route information with all stops from station page
  - Removed redundant single-stop ETA page in favor of comprehensive route details

### Technical
- **StopRoutesViewController Updates**
  - Modified `didSelectRowAt` to call `showRouteDetail()` instead of `showStopETA()`
  - Removed `showStopETA()` method and StopETAViewController navigation
  - Added `showRouteDetail()` method with CATransition animation (from right)
  - Added QuartzCore import for transition animations
  - Consistent user experience with SearchViewController navigation

## [0.5.7] - 2025-10-18

### Changed
- **🎯 Enhanced Direction Indicators**
  - All bus destinations now display with direction prefixes for better clarity
  - "往：" prefix for outbound routes (towards destination) - using full-width colon
  - "返：" prefix for inbound routes (towards origin) - using full-width colon
  - Consistent formatting across all pages: "我的", "路線", and "站點"
  - Improved user experience by making route directions immediately recognizable

### Technical
- **LocalBusDataManager Updates**
  - Modified `getRoutesForStop()` to add direction prefixes when creating StopRoute objects
  - Inbound routes now show "返:" + origin name
  - Outbound routes now show "往:" + destination name

- **BusAPIService Direction Handling**
  - Updated `getCTBRouteDestination()` to support full direction string comparison
  - Added "往:" and "返:" prefixes to CTB/NWFB destination formatting
  - Updated `getKMBDestinationPlaceholder()` to include direction prefixes in fallback text
  - Ensured consistent direction handling across all three bus companies (CTB, NWFB, KMB)

## [0.5.6] - 2025-10-18

### Changed
- **🎨 Unified Route Item Format in Station Details**
  - Station details page (站點詳細頁面) now uses same route item format as "我的" page
  - Replaced `StopRouteTableViewCell` with `BusETATableViewCell` for consistent UI/UX
  - Route items now display with 34pt semibold route numbers, 5x5px company indicators
  - Enhanced visual consistency across route display throughout the app
  - Maintained favorite star button functionality on station details page
  - Station name displayed in route items instead of separate company labels

### Technical
- **StopRoutesViewController Refactoring**
  - Converted `RouteWithETA` data to `BusDisplayData` format for compatibility
  - Registered `BusETATableViewCell` instead of custom `StopRouteTableViewCell`
  - Enhanced cell configuration to include station name and destination information
  - Maintained favorite toggle functionality with proper state updates
  - Removed redundant `StopRouteTableViewCell` class (188 lines cleaned up)

## [0.5.5] - 2025-10-18

### Changed
- **🎨 Optimized "My" Page Layout**
  - Removed star (favorite) button from "我的" page to maximize content display space
  - Star button remains visible and functional on route search page for adding favorites
  - ETA area dynamically expands to right edge when star button is hidden (gains ~52px)
  - Cleaner, more focused interface for viewing saved favorite routes
  - All routes on "我的" page are already favorites, making the star button redundant

### Technical
- **BusETATableViewCell Dynamic Layout**
  - Implemented dual constraint system for ETA trailing anchor
  - `etaTrailingToStarConstraint`: Active when star button is visible (route search page)
  - `etaTrailingToContainerConstraint`: Active when star button is hidden ("我的" page)
  - `setStarButtonVisible()` method dynamically switches constraints based on context
  - ETA width changes from fixed 120px to flexible `greaterThanOrEqualToConstant: 120`
  - BusListViewController hides star button via `cell.setStarButtonVisible(false)`
  - SearchViewController shows star button via `cell.setStarButtonVisible(true)` with full favorite toggle functionality

## [0.5.4] - 2025-10-17

### Changed
- **🎨 Refreshed Tab Bar Design**
  - Renamed tabs for clearer navigation: "巴士時間" → "我的", "路線搜尋" → "路線"
  - Updated tab bar icons for better semantic meaning:
    - "我的" tab: Changed from bus icon to star icon (star/star.fill) representing personal favorites
    - "路線" tab: Changed from magnifying glass to bus icon (bus/bus.fill) directly representing route search
    - "站點" tab: Changed from location icon to map pin icon (mappin.and.ellipse) for better map representation
  - More intuitive iconography aligning with tab content and user expectations

### Technical
- **MainTabBarController Updates**
  - Updated UITabBarItem configurations for all three tabs
  - Implemented SF Symbols for consistent iOS design language
  - Maintained existing tab functionality and navigation logic

## [0.5.3] - 2025-10-02

### Improved
- **🎨 Refined Route Details Header Layout**
  - Set optimal minimum height to 60px for better visual balance
  - Implemented perfect vertical centering for all content and icons
  - Increased horizontal padding from 12px to 20px for more generous spacing
  - Unified layout with all elements (direction label, duration label, swap icon) center-aligned
  - Simplified constraint structure by removing stacked layout in favor of centered positioning

### Technical
- **📐 Layout Optimization**
  - Changed from top/bottom anchored layout to centerYAnchor for all header elements
  - Consistent 20px internal padding throughout header components
  - Streamlined constraint setup for better maintainability and visual consistency

## [0.5.2] - 2025-10-02

### Fixed
- **🧹 Removed Misleading Dummy Data**
  - Eliminated hardcoded "06:00 - 23:30" operating hours that appeared on all routes
  - Removed fake "預計行程時間" (estimated travel time) with hardcoded values (45分鐘 for 793, 50分鐘 for 795X, etc.)
  - Route details now only display genuine API data, providing honest and accurate information
  - Enhanced data validation to prevent display of placeholder or dummy schedule information

### Improved
- **🎨 Enhanced Route Details UI**
  - Added generous padding to route details header (8px top, 12px sides, 72px minimum height)
  - Increased internal padding from 8px to 12px for better visual breathing room
  - Improved spacing between direction label and duration info (2px → 4px)
  - Professional layout with consistent 12px internal padding throughout

- **📱 Enlarged Navigation Title**
  - Increased bus route number font size from 24pt to 32pt (33% larger)
  - Changed font weight from semibold to bold for better prominence
  - Route numbers now much more visible and identifiable at a glance

### Technical
- **🔧 API Service Cleanup**
  - Removed `estimateDuration()` method with hardcoded route time estimates
  - Set `estimatedDuration: nil` and `operatingHours: nil` in route detail creation
  - Simplified UI logic to handle absence of dummy data gracefully
  - Cleaner codebase without misleading placeholder values

## [0.5.1] - 2025-10-02

### Added
- **🔄 Smart ETA Refresh Behavior**
  - Tapping expanded stops now refreshes ETA data instead of collapsing the view
  - Maintains expanded state while updating bus arrival times for better UX
  - Enhanced user interaction model reduces need to repeatedly expand/collapse stops

- **⚡ Auto-Refresh System for Expanded ETA**
  - Implemented 1-minute automatic ETA refresh for expanded stops
  - Timer-based refresh system ensures users always have current bus arrival data
  - Proper timer cleanup in viewWillDisappear prevents memory leaks
  - Auto-refresh works independently of manual refresh cooldown

- **🛡️ API Rate Limiting Protection**
  - Added 5-second cooldown for manual ETA refresh to prevent API overload
  - Silent cooldown behavior - excessive taps are ignored without user feedback
  - forceRefresh parameter allows auto-refresh and auto-expand to bypass cooldown
  - Protects Hong Kong government APIs from rapid-fire requests

### Improved
- **📐 Optimized Route Detail Layout**
  - Minimized stop number padding: 8px→4px leading margin, 30px→24px width
  - Reduced gap between sequence label and route line: 8px→4px spacing
  - Reduced gaps between stop items: 4px→2px top/bottom margins
  - Creates more space for stop names and ETA information display

- **🎨 Visual Alignment Enhancements**
  - Center-aligned swap icon vertically in route detail header
  - Improved visual balance and touch target accessibility
  - Better integration with header text layout

- **🧹 Clean Data Display**
  - Removed dummy/placeholder schedule information from route detail header
  - Only displays real API data: valid travel time and operating hours
  - Hides duration label when no meaningful schedule data available
  - Enhanced data validation to filter out "N/A" and empty values

### Technical
- **🔧 Enhanced Timer Management**
  - Added etaRefreshTimer property for 60-second auto-refresh intervals
  - Proper timer invalidation prevents background activity after view dismissal
  - startETARefreshTimer() and stopETARefreshTimer() methods for lifecycle management

- **⏱️ Cooldown Implementation**
  - lastRefreshTime tracking in RouteStopTableViewCell for individual stop cooldowns
  - loadAndShowETA(forceRefresh:) method supports bypassing cooldown for automated refreshes
  - Cell reuse properly resets refresh timestamps to prevent cross-contamination

- **📊 Layout Constraint Optimization**
  - Reduced padding values throughout RouteStopTableViewCell for better space utilization
  - Maintained visual hierarchy while maximizing information display area
  - Improved readability through strategic spacing adjustments

## [0.5.0] - 2025-10-01

### Fixed
- **🔧 Critical Auto-Expand Bug**: Resolved issue where all bus stops had nil coordinates, preventing auto-expand functionality
  - Enhanced BusAPIService to use local bus_data.json for stop coordinates and names
  - Added LocalBusDataManager methods: `getStopCoordinates()` and `getStopInfo()`
  - Implemented Local JSON → API fallback → Cache strategy for coordinate retrieval
  - Added comprehensive coordinate validation to prevent crashes from invalid data

- **📱 Tab Navigation**: Fixed route tab button in RouteDetailViewController not returning to route search page
  - Improved navigation stack depth detection for smart tab switching
  - Enhanced MainTabBarController delegate logic to distinguish between repeat taps and deep navigation

- **⚡ Location Services**: Updated for iOS 14+ compatibility and improved performance
  - Fixed deprecated CLLocationManager.authorizationStatus calls
  - Enhanced GPS timeout handling (3s → 1.5s) with better error recovery
  - Added backup timer mechanism for location request failures

### Improved
- **🚀 Performance Boost**: Reduced auto-expand trigger time by 83% (2.3s → 0.4s)
  - Optimized delay timings in auto-expand sequence
  - Eliminated unnecessary waiting periods between UI updates
  - Parallelized scrolling and ETA loading operations
  - Enhanced ViewDidAppear triggering with minimal delays

- **📊 Data Integration**: Enhanced coordinate system with local data priority
  - Local bus_data.json now provides coordinates for all 9,222 bus stops
  - Fallback to API calls only when local data unavailable
  - Improved caching strategy for better performance

### Technical
- **🔧 API Compatibility**: Fixed deprecated iOS APIs and warnings
  - Updated UIButton configuration for iOS 15+ compatibility
  - Resolved nil coalescing warnings in sequence parsing
  - Improved error handling and validation throughout coordinate pipeline

## [0.4.4] - 2025-09-29

### Added
- **🔄 Enhanced Direction Switching UI**
  - Moved swap button from navigation bar to beside origin/destination info for better accessibility
  - Made entire header area clickable as single button for improved touch targets
  - Smart auto-switching for 2-direction routes without requiring user selection
  - Larger navigation title font size (24pt semibold) for better visibility
  - Enhanced visual hierarchy with 100% contrast text for origin/destination

- **⚡ Revolutionary In-Cell ETA Display**
  - Clicking stop items now shows ETA data within same cell instead of navigating to new page
  - Integrated loading indicators and error handling directly in route stop cells
  - Toggle functionality to expand/collapse ETA information on demand
  - Real-time ETA fetching with proper loading states and error handling
  - Smooth animations for ETA expansion/collapse

- **🎨 Improved Route Detail UX**
  - Replaced jarring push animations with smooth fade in/out effects for direction switching
  - Minimized all margins around interface elements for cleaner layout
  - Enhanced text contrast: origin/destination at 100% white/black, journey time at clearer visibility
  - Larger route numbers in StopRoutesViewController (increased from 32pt to 40pt)

### Fixed
- **🚨 Critical Crash Resolution**
  - Fixed fatal error "Double value cannot be converted to Int because it is either infinite or NaN"
  - Implemented comprehensive coordinate validation for bus stop latitude/longitude data
  - Added validation for NaN, infinite, and out-of-range coordinate values
  - Enhanced distance calculation with finite value checking
  - Graceful fallback when encountering corrupted coordinate data

- **🔧 String Literal Compilation Errors**
  - Fixed multiple "Unterminated string literal" errors caused by incorrect escape sequences
  - Corrected all `\"` instances to proper `"` in string literals throughout codebase
  - Resolved build failures preventing successful compilation

- **🔧 API Method Signature Correction**
  - Fixed incorrect `searchRoutes(query:)` method call to proper `searchRoutes(routeNumber:completion:)`
  - Ensured proper API service integration for direction fetching functionality

### Enhanced
- **🛡️ Robust Error Handling**
  - Comprehensive latitude/longitude range validation (-90 to 90, -180 to 180)
  - Safe Double to Int conversion using `.rounded()` method
  - Detailed logging for invalid stops with coordinate information
  - Skip processing for invalid stops while continuing with valid ones

- **🎯 RouteStopTableViewCell Enhancement**
  - Added comprehensive ETA display components (etaStackView, loadingIndicator)
  - Integrated route information storage for API calls
  - Enhanced cell state management for ETA display toggle
  - Proper error handling and loading states for in-cell ETA

### Technical Improvements
- Added `.isFinite` validation for all coordinate and distance calculations
- Enhanced coordinate bounds checking for geographic validity
- Improved error logging with detailed coordinate information
- Complete in-cell ETA system with proper state management
- Enhanced RouteDetailViewController with better touch handling and animations
- Maintained auto-navigation functionality for valid stops within 1000m radius
- Ensured build system stability with successful compilation

## [0.4.3] - 2025-09-05

### Fixed
- **🎨 "未有資料" Text Color Consistency**
  - Fixed issue where "未有資料" (No Data) text was incorrectly displaying in blue/teal color instead of gray
  - Modified `createETALabel()` functions in both `BusETATableViewCell.swift` and `StopRoutesViewController.swift` to explicitly check for "未有資料" text and apply gray color
  - Ensured consistent gray color for all no-data states across the app regardless of ETA position priority
  - Maintained `systemTeal` color for actual ETA times while fixing no-data text appearance

### Technical Details
- Added conditional text checking in ETA label creation functions
- Fixed color hierarchy logic to prioritize no-data states over first ETA styling
- Ensured visual consistency across all bus ETA display components

## [0.4.2] - 2025-09-04

### Fixed
- **🔧 Search State Synchronization Issues**
  - Fixed critical state desynchronization between `searchBar.text` (UI state) and `currentSearchText` (internal state)
  - Resolved issue where returning from other pages would cause search bar to show placeholder but retain old search text internally
  - Fixed backspace behavior requiring multiple presses to clear text after using "重設" button or page navigation
  - Added comprehensive state synchronization in `viewDidAppear` lifecycle to ensure UI and internal states match

- **📱 Enhanced Search Bar UX**
  - Implemented dynamic "重設" (Reset) button that only appears when text is entered
  - Improved cancel button behavior to properly clear all search states and reload nearby content
  - Fixed search bar placeholder display issues after page transitions
  - Ensured consistent search bar behavior across both route search and stop search pages

- **📋 Table View Header Behavior Consistency**
  - Changed SearchViewController table view style from `.plain` to `.grouped` for consistent header scrolling behavior
  - "附近路線" (Nearby Routes) headers now scroll with content like "附近站點" (Nearby Stops) headers
  - Improved visual consistency between route search and stop search interfaces

### Technical Improvements
- Added `syncSearchStates()` method in SearchViewController for comprehensive state reconciliation
- Added `syncSearchState()` method in StopSearchViewController for UI state validation
- Enhanced `searchBarCancelButtonClicked` logic to clear both UI and internal search states
- Improved state management with proper bidirectional synchronization
- Added detailed debug logging for search state transitions

## [0.4.1] - 2025-09-04

### Fixed
- **🔧 Custom Keyboard Visual Design**
  - Fixed keyboard button colors in dark theme (changed from white to `systemGray5` with white text)
  - Enhanced keyboard background to dark semi-transparent (`black.withAlphaComponent(0.9)`)
  - Improved button contrast and visibility with proper border and shadow effects
  - Maintained blue highlight for search button to provide visual focus

- **📐 Keyboard Layout Optimization** 
  - Redesigned keyboard with responsive width system - each button is exactly 1/5 of screen width
  - Numbers section: 3 columns taking 3/5 of screen width
  - Letters section: 2 columns taking 2/5 of screen width  
  - Unified 5px spacing between all buttons for consistent visual hierarchy
  - Added 5px separation gap between numbers and letters sections
  - All buttons maintain consistent 50px height across the keyboard

- **🚌 Route Display & ETA Loading Issues**
  - Fixed duplicate nearby routes by implementing intelligent route deduplication
  - Enhanced route-to-stop matching to select closest stop for each unique route
  - Improved ETA loading reliability by pre-resolving stop IDs during route preparation
  - Simplified ETA fetching logic to eliminate complex stop ID lookup failures
  - Better error handling with detailed logging for debugging route matching issues

### Technical Improvements
- Eliminated redundant `findStopIdForRoute` method in favor of direct stop ID resolution
- Enhanced route distance mapping with `(RouteWithDistance, Double)` tuple structure
- Improved constraint-based layout system for responsive keyboard design
- Optimized button positioning with relative constraints instead of fixed calculations

## [0.4.0] - 2025-09-04

### Added
- **⚡ Ultra-Fast Route Loading System**
  - Sub-second nearby route loading using intelligent location strategies
  - Smart location caching with UserDefaults (10-minute validity)
  - Triple-fallback location system: cached → low-accuracy GPS (0.8s timeout) → Central HK
  - Progressive ETA loading with "..." indicators during fetch
  - Batch API protection system (5 routes/batch, 0.5s delays) to prevent server blocking
  - Performance monitoring with detailed timing logs for optimization tracking

- **🎯 Location-Based Route Discovery**
  - Eliminated default routes for instant user-relevant content
  - 1km radius search with maximum 30 stops for optimal speed
  - Smart route deduplication using company+route+direction keys
  - Automatic location saving for future fast launches

- **🔧 Performance Optimizations**
  - Route sorting cache to avoid re-processing 2,090 routes on each request  
  - Reduced GPS accuracy requirement (kCLLocationAccuracyKilometer) for faster responses
  - Location request timeout (3 seconds maximum) to prevent infinite waiting
  - Streamlined nearby stop processing with distance-based sorting

### Changed
- **Route Loading Strategy**: Direct nearby routes instead of default → nearby transition
- **User Experience**: Instant content display within 1 second of app launch
- **Location Accuracy**: Prioritized speed over precision for better UX
- **ETA Display**: Progressive loading with clear loading states ("..." → actual times)
- **Data Processing**: Optimized for minimal latency and maximum responsiveness

### Fixed
- Route loading delays caused by GPS acquisition waiting
- Multiple route loading preventing fast UI updates
- API overload issues with concurrent ETA requests
- Location timeout causing indefinite loading states
- Performance bottlenecks in route sorting and filtering

### Technical Details
- **Performance Target**: <1 second route display achievement
- **Location Strategy**: Multi-tier fallback system ensuring content always appears
- **API Protection**: Intelligent rate limiting prevents server blocking
- **Memory Optimization**: Efficient caching strategies for repeated usage
- **Error Resilience**: Graceful fallbacks maintain functionality under all conditions

## [0.3.1] - 2025-09-04

### Added
- Complete App Icon integration with all iOS device sizes (iPhone + iPad)
- Enhanced Route Search page with custom keyboard interface
- Location-based nearby routes discovery with GPS integration
- Smart route sorting by proximity and route number
- Full-width keyboard overlay design for better screen coverage
- 1px separator lines between route items for visual clarity
- "附近路線" section header to distinguish nearby routes from search results
- Improved touch detection to prevent keyboard dismissal during typing

### Changed  
- Custom keyboard layout to standard number pad format (7-9, 4-6, 1-3, ⌫-0-搜尋)
- Reduced keyboard height from 280pt to 220pt for better screen utilization
- Search bar positioning moved to top edge without extra margins
- Table view now extends full height with keyboard overlay instead of pushing content
- Button spacing unified to 6pt gaps with 8pt internal margins
- Font sizes optimized: 45pt for number buttons, 35pt for letter buttons

### Fixed
- Keyboard typing interruption issues with smart gesture recognition
- Search bar layout optimization to maximize content area
- Content visibility when keyboard is displayed with dynamic content insets
- Visual consistency maintained across route and station pages
- Touch gesture conflicts between keyboard usage and dismissal

## [0.3.0] - 2025-09-04

### Added
- **Ultra-Fast Data Collection System**
  - Complete Hong Kong bus data collection pipeline optimized for speed
  - Production script `collect_bus_data_optimized_concurrent.py` reduces collection time from 2+ hours to 4.5 minutes
  - Comprehensive dataset: 2,090 routes, 9,222 stops, 100% API success rate
  - ThreadPool concurrency for CTB data collection with intelligent caching
  - Progress tracking and detailed statistics during collection process

- **Batch API Optimization**
  - KMB data collection: 3 batch API calls → 5.69 seconds (vs hundreds of individual calls)
  - All KMB stops, routes, and mappings fetched in single API calls
  - CTB data: Concurrent processing with 10-worker ThreadPool for 796 route directions

- **Data Quality & Analysis**
  - Complete data validation and format consistency checking
  - Identified and documented 120 CTB routes with API access restrictions
  - JSON structure optimized for long-term development with bidirectional mapping
  - Multi-language support (Traditional Chinese + English) with geographical coordinates

### Changed
- **Station Tab Enhancement Completed**
  - Eliminated all fake/sample data from station search
  - Enhanced CTB v2 API integration with comprehensive error logging
  - Improved real-time location services with proper fallbacks
  - Optimized nearby stops filtering: 1km primary radius, 3km fallback range
  - Ensured three-company API robustness (KMB/CTB/NWFB)
  - **UI Redesign for Information Density Optimization**:
    - Station names optimized to 21pt semibold font for better readability
    - Route numbers displayed inline (e.g., "1, 2B, 3C, 796X") with smart truncation for 8+ routes
    - Distance-only display on right side (removed redundant location info)
    - Cell height optimized to 80px for proper content spacing and visibility
    - Added 1px separator lines between search result items
    - Reduced margins around section headers ("附近站點") for tighter spacing
    - Enhanced route display logic with overflow handling ("等X條路線")
    - **Proximity Search Optimization**: 1km radius (1000m) with up to 50 nearby stops
    - Fallback search range extended to 3km when no stops found within 1km

### Fixed
- **Data Collection Issues**
  - CTB API 403 Forbidden errors properly handled (120 special/seasonal routes)
  - Race day specials (R suffix), peak hours (P suffix), night services (N prefix) documented
  - Complete error tracking with success rate monitoring (100% for accessible routes)

### Technical Details
- **Performance Improvements**: 50x faster data collection (4.5 minutes vs 2+ hours)
- **Data Coverage**: Complete Hong Kong bus network with 9,223 stop-route mappings
- **File Output**: 17.76 MB JSON with comprehensive bus network data
- **API Efficiency**: Reduced from estimated 800+ calls to 3,363 optimized calls
- **Error Resilience**: Graceful handling of restricted routes with detailed logging

## [0.2.0] - 2025-08-29

### Changed
- **Complete UI Redesign**: Implemented minimalist dark theme
  - Pure black background throughout the app for OLED optimization
  - Removed navigation bar for maximum screen real estate
  - Content now scrolls under status bar with 80% black overlay
  - Edit button now scrolls with content instead of being fixed
  - Reduced cell height from 90px to 82px with 1px spacing
  - Increased bus number font to 34pt regular (removed bold)
  - Company indicators changed from colored borders to 5x5px dots at x:0 y:0
  - Section headers now stick properly to status bar when scrolling

### Fixed
- Small company indicator dots now positioned correctly at cell's absolute top-left
- Eliminated gap above section headers when scrolling
- Edit button now scrolls with content as expected
- Improved visual consistency in edit mode with black backgrounds

## [0.1.0] - 2025-08-20

### Added
- **Core Functionality**
  - Real-time bus ETA display for CTB, KMB, and NWFB
  - Dynamic favorites management with Core Data persistence
  - 50-second auto-refresh with manual pull-to-refresh
  - Basic error handling with user feedback
  
- **Search Features**
  - Full Hong Kong bus route search across all companies
  - Auto-capitalization for route input
  - Debounced search (0.3s delay)
  - Direction selection for multi-direction routes
  - Smart grouping by route number and company
  
- **Route Details**
  - Complete route visualization with all stops
  - Individual stop ETA display
  - Visual route lines with color coding
  - Station-specific favorites system
  
- **Navigation**
  - 3-tab navigation: Bus List, Route Search, Stop Search
  - Smooth transitions and animations
  - Touch feedback and highlights

### Technical Details
- UIKit with programmatic UI (no Storyboard dependency)
- MVC architecture with MVVM patterns
- Core Data for persistence
- 30-minute intelligent caching strategy
- Concurrent API calls with DispatchGroup

## [0.0.1] - 2025-08-15

### Added
- Initial project setup with Xcode
- Basic project structure following MVC pattern
- Core Data model for BusRouteFavorite entity
- API service singleton for Hong Kong transport APIs
- HTML/PHP reference implementation for guidance