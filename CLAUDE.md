# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Goal
Create a user-friendly iOS HK Bus App with real-time ETA display, route search, and location-based features.

## Architecture Overview

### Data Flow
- **Local Bus Data**: Complete HK bus network from `bus_data.json` (17.76MB, 2,090 routes, 9,223 stops)
- **Location-Based Loading**: Instant nearby routes using GPS/cached location within 1km radius
- **API Integration**: Real-time ETA data from Hong Kong government APIs (CTB, NWFB, KMB)
- **Performance Optimized**: Sub-second route loading with intelligent caching and batch ETA requests
- **Auto-refresh**: Progressive ETA refreshing with API rate limiting protection

### Key Components
1. **Data Models**: Bus route configuration with company-specific API endpoints
2. **API Services**: Real-time ETA fetching and route search across all HK bus companies
3. **UI Components**: Route display with in-cell ETA, stop names, and destinations
4. **Location Services**: GPS-based nearby route discovery with smart caching

## API Endpoints

### ⚠️ CRITICAL: Must Use v2 API for CTB/NWFB
- **CTB/NWFB**: `https://rt.data.gov.hk/v2/transport/citybus/` (v2 only, v1 deprecated)
  - Route List: `/route/{CTB|NWFB}`
  - Stop List: `/stop/{CTB|NWFB}`
  - ETA Data: `/eta/{CTB|NWFB}/{stopId}/{route}`
- **KMB**: `https://data.etabus.gov.hk/v1/transport/kmb/` (v1 API)
  - Route List: `/route`
  - Stop List: `/stop`
  - ETA Data: `/eta/{stopId}/{route}/{serviceType}`

**Important Notes**:
- NWFB routes merged into CTB as of July 1, 2023 - use CTB endpoints
- V1.0 and V1.1 CTB/NWFB APIs will be discontinued soon
- Some CTB routes (120 special/seasonal routes with R/P/N suffixes) may return 403 Forbidden

### Data Source
- **Custom Python Script** (`collect_bus_data_optimized_concurrent.py`):
  - Runs on NAS server with scheduled automated execution
  - Direct API integration: v2 CTB/NWFB API + v1 KMB API
  - Generates complete bus network data (2,090 routes, 9,223 stops)
  - Auto-uploads to Firebase Storage with security protection
- **Firebase Storage Distribution**:
  - App downloads `bus_data.json` (17.76MB) via Firebase SDK
  - Protected by Firebase Security Rules (app-only access)
  - Automatic update mechanism with version checking
  - No public API exposure - secure authenticated downloads only

## Current Project Structure

```
HKBusApp/
├── AppDelegate.swift - Core Data initialization
├── SceneDelegate.swift - Programmatic UI setup
├── Models/
│   ├── BusRoute.swift - Route models with Company enum
│   │   ├── BusRouteDetail - Complete route with all stops
│   │   ├── BusStop - Individual stop with coordinates
│   │   ├── RouteSearchResult - Grouped search results
│   │   └── DirectionInfo - Route direction with origin/destination
│   └── BusETA.swift - ETA data models and API responses
├── Services/
│   ├── BusAPIService.swift - Singleton API service for all companies
│   ├── LocalBusDataManager.swift - Local JSON data management (17.76MB bus_data.json)
│   ├── CoreDataStack.swift - Core Data persistence layer
│   └── FavoritesManager.swift - CRUD operations for favorites
├── Controllers/
│   ├── MainTabBarController.swift - 3-tab navigation
│   ├── BusListViewController.swift - Main ETA display with category management
│   ├── SearchViewController.swift - Ultra-fast nearby route loading
│   ├── RouteDetailViewController.swift - Complete route with in-cell ETA display
│   ├── StopETAViewController.swift - Individual stop ETA with auto-refresh
│   ├── StopSearchViewController.swift - Station search with recent history
│   └── StopRoutesViewController.swift - Station-specific route display
├── Views/
│   ├── BusETATableViewCell.swift - Cell with dynamic star button visibility (82px height)
│   ├── SearchResultTableViewCell.swift - Search results display
│   ├── RouteStopTableViewCell.swift - Route stop cells with in-cell ETA
│   └── BusRouteKeyboard.swift - Custom responsive keyboard
└── Resources/
    ├── Assets.xcassets/ - App icons and accent colors
    └── bus_data.json - Complete HK bus network data
```

## Key Features

### 1. Dynamic Favorites System
- Core Data persistence with category management
- Edit mode with standard iOS table view editing (delete & reorder)
- Station-specific route ETA favorites (stop + route combination)
- Contextual star button: hidden on "我的" page, visible on route search page
- Empty state with visual guidance for first-time users
- No automatic default data loading - user-driven experience
- **Tap-to-navigate**: Tap favorite routes in "我的" page to view full route details
- **Smart stop expansion**: Auto-expands the favorited stop (not nearest stop) when entering from favorites

### 2. Real-Time ETA Display
- Concurrent API calls to CTB, NWFB, KMB with 30-minute caching
- **WCAG AAA compliant color system for ALL text elements** (7.0:1+ contrast ratio)
  - First ETA: Deep blue `#003D82` (light mode) / systemTeal (dark mode) - 7.5:1 contrast
  - Second/third ETA: 85% opacity white/black for subtle hierarchy - 7.3:1 contrast
  - Destination labels ("→ 目的站點"): 85% opacity white/black - 7.3:1 contrast (AAA)
  - Search result directions: 85% opacity white/black - 7.3:1 contrast (AAA)
  - Smart opacity-based visual differentiation while maintaining AAA accessibility
- 50-second auto-refresh with unified manual pull-to-refresh across all pages
- Standardized pull-to-refresh UI with dark mode-adaptive styling
- Contextual refresh text labels ("更新路線", "更新站點", "更新到站時間")
- In-cell ETA display (no navigation required)

### 3. Route Search
- Performance-optimized search (API calls only on user input)
- Auto-capitalization and debounced search (0.3s delay)
- Smart grouping by route number and company
- Direction selection for multi-direction routes
- Custom keyboard with responsive layout and instant button state changes
- Circular update prevention with dual-state synchronization
- Float-left letter button layout (visible buttons flow without gaps)
- **Pull-to-refresh disabled during search**: `refreshControl = nil` when showing search results
- Refresh control automatically restored when returning to nearby routes mode

### 4. Route Detail View
- Visual route line with color coding (green=start, red=end, blue=middle)
- In-cell ETA display with tap-to-refresh (5s cooldown)
- **Expanded stop highlighting**: 10% blue background when showing ETA for clear visual feedback
- Auto-refresh every 50 seconds for expanded stops
- Smart direction switching with fade animations
- **Intelligent auto-expand**: Priority-based expansion system
  - From favorites ("我的" page): Auto-expands the specific stop user favorited
  - From search/station: Auto-expands nearest stop within 1000m
  - Seamless fallback mechanism for all entry points

### 5. Station Search
- Recent stops history with persistent storage
- 1km proximity search (fallback to 3km)
- Inline route display with smart truncation
- GPS-based nearby stations

### 6. Location Services
- Smart location caching (10-minute validity)
- Triple-fallback: cached → low-accuracy GPS (1.5s timeout) → Central HK
- Sub-second nearby route loading

### 7. Navigation & Tab Memory System
- 3-tab interface: 我的 (star icon), 路線 (bus icon), 站點 (map pin icon)
- Tab bar with translucent blur effect
- Smart tab switching with navigation stack management
- **Intelligent Tab Restoration**:
  - App remembers last used tab across app launches (stored in UserDefaults)
  - Kill app and reopen restores your last selected tab automatically
  - First-time users (no saved tab) see "路線" tab if no favorites, "我的" tab if favorites exist
  - Navigation stack resets to first page when restoring tabs for clean state
  - Tab selection persists regardless of favorites data changes
- **Unified Navigation Experience**:
  - Consistent CATransition animations across all entry points (0.3s, moveIn from right)
  - Navigation bar visibility managed automatically (shown in route details, hidden in favorites list)
  - Edit mode check prevents navigation during reordering/deletion operations

### 8. Empty State Experience
- Professional onboarding for new users with visual illustration
- Clear guidance: "未有收藏路線" + "前往路線或站點頁面，點擊星號按鈕即可加入收藏"
- ScrollView support for small screens with preserved pull-to-refresh
- High-contrast text (label/secondaryLabel) for excellent readability
- Empty state asset: 325x225px image in Assets.xcassets

### 9. Floating Refresh Button
- **Visual Design**: iOS 18 Liquid Glass effect with capsule shape (160px × 48px, corner radius 24px)
  - systemThinMaterial blur + UIVibrancyEffect for enhanced glass appearance
  - Semi-transparent with subtle shadow (offset: 0,4 | opacity: 0.15 | radius: 8px)
  - Fixed position: bottom center, 16px above tab bar
- **Interactive Animation**: Smooth morphing transition
  - Shrinks to perfect 48px circle on tap (0.3s spring animation, damping 0.7)
  - Loading spinner rotates for 3 seconds
  - Expands back to capsule (0.3s spring animation)
  - 4-second total lock period (3s loading + 1s post-animation cooldown)
- **Smart Behavior**:
  - Auto-hides in empty state (no favorites) and edit mode
  - Prevents rapid re-tapping during animation cycle
  - Integrated with pull-to-refresh mechanism (both trigger `loadData()`)
- **Adaptive Typography**:
  - Normal font: 16pt medium "重新整理"
  - Large font: 18pt medium "重新整理"
  - Responds to FontSizeManager changes in real-time
- **Layout Optimization**:
  - Added 80px bottom padding to table view content inset
  - Prevents last item occlusion by floating button

## UI/UX Design Philosophy

### Minimalist Dark Theme
- **Maximum Content Area**: No navigation bar, content scrolls under status bar
- **High Contrast**: Pure black background with white text
- **Minimal Chrome**: Only essential UI elements
- **Subtle Branding**: 5x5px company color indicators (CTB=yellow, KMB=red, NWFB=orange)
- **Efficient Space**: Tight spacing (1px gaps) to maximize visible routes

### Visual Hierarchy
1. **Bus Number**: 34pt semibold, primary focus
2. **Stop Name**: 16pt semibold white (updated in v0.6.1)
3. **Destination**: 15pt regular, 85% opacity white/black - 7.3:1 contrast (updated in v0.8.3)
4. **ETA Times**: WCAG AAA compliant colors (updated in v0.8.2-v0.8.3)
   - First ETA: 17pt, deep blue #003D82 (light mode) / systemTeal (dark mode) - 7.5:1 contrast
   - Second/third ETA: 15pt, 85% opacity white/black - 7.3:1 contrast
   - All ETA times and destination labels meet AAA accessibility standards

### Typography
- Bus numbers: 34pt semibold
- Station names: 24pt semibold (in station search, updated in v0.6.1)
- Destination labels: 15pt regular (updated in v0.8.3, +1pt from v0.6.1)
- Section headers: 16pt medium (updated in v0.6.1)
- Regular text: 17pt medium (updated in v0.6.1)
- Small text: 15pt regular (updated in v0.6.1)
- Route numbers in detail: 32pt bold navigation title

### Layout Optimization
- Cell heights: 82px (bus list), 80px (station search)
- Company indicators: vertically centered, positioned at x:0 y:0
- Section headers: minimal margins (32px height, 12px left margin)
- Route detail header: 60px minimum height with 20px internal padding
- Dynamic ETA width: extends to right edge (~52px extra space) when star button hidden

## Build & Development Information

- **Project Type**: Native iOS App (Swift 5.0)
- **Minimum iOS Version**: iOS 18.2
- **Architecture**: MVC with MVVM patterns
- **Persistence**: Core Data with BusRouteFavorite entity
- **UI Framework**: UIKit with programmatic UI (no Storyboard dependency)
- **Local Data**: 17.76MB bus_data.json containing complete HK bus network

## 🚨 CRITICAL SETUP REQUIREMENT

### Must Add `bus_data.json` to Xcode Bundle Resources

The ultra-fast route loading depends on `bus_data.json` being included in the app bundle.

**Setup Steps:**
1. Open Xcode project
2. Right-click `HKBusApp` folder → "Add Files to 'HKBusApp'"
3. Select `bus_data.json` file
4. Ensure "Add to target" has `HKBusApp` checked
5. Click "Add"

**Alternative Method:**
1. Select project file → `HKBusApp` target
2. "Build Phases" → "Copy Bundle Resources" → "+"
3. Add `bus_data.json`

**Verification:**
App logs should show:
```
✅ LocalBusDataManager: Loaded bus data successfully
📊 Routes: 2090, Stops: 9223
⚡ 快速載入設置完成，耗時: 0.XXX秒
```

**Without this file, nearby routes will not load and the app will appear empty.**

### Firebase Configuration & Security

**IMPORTANT: GoogleService-Info.plist is NOT in version control**

The `GoogleService-Info.plist` file contains sensitive Firebase API credentials and is intentionally excluded from Git tracking.

**Setup for New Developers:**
1. Contact project maintainer to obtain `GoogleService-Info.plist`
2. Place file in `HKBusApp/HKBusApp/` directory
3. **DO NOT** add to Git (already in .gitignore)
4. Verify file is ignored: `git check-ignore -v HKBusApp/HKBusApp/GoogleService-Info.plist`

**Security Protection:**
- `.gitignore` contains `GoogleService-Info.plist*` (wildcard protects all variants)
- File purged from Git history (commit: 78cb036)
- API key restricted to iOS Bundle ID: `com.answertick.HKBusApp`
- API key restricted to Firebase services: Storage, Installations

**Firebase Services Used:**
- **Firebase Storage**: Bus data distribution (`bus_data.json`)
- **Firebase Auth**: Anonymous authentication for Security Rules
- **Firebase Analytics**: Disabled (IS_ANALYTICS_ENABLED = false)

**Security Documentation:**
- Complete incident response guide: `FIREBASE_API_KEY_REGENERATION.md`
- Security verification report: `APP_SECURITY_CHECK_REPORT.md`

**Verification:**
App logs should show on launch:
```
✅ Firebase initialized
```

**CocoaPods Dependencies:**
- Firebase/Core
- Firebase/Storage
- Firebase/Auth
- Total: 17 pods installed

## Search Functionality

### Route Search Features
- **Real-time API Integration**: Searches CTB, NWFB, KMB simultaneously
- **Auto-capitalization**: Input converts to uppercase (e.g., "1a" → "1A")
- **Debounced Search**: 0.3s delay prevents excessive API calls (unified across all inputs)
- **Smart Grouping**: Results grouped by route and company
- **Direction Selection**: Action sheet for multiple directions
- **Custom Keyboard**: Responsive layout with 1/5 screen width buttons
  - Instant button state changes (no animations)
  - Float-left letter button behavior (visible buttons flow continuously)
  - Dynamic row reorganization when button visibility changes
- **State Synchronization**: Robust dual-state system with race condition protection (v0.10.1)
  - `searchBar.text` (UI state) synced with `currentSearchText` (internal state)
  - `isUpdatingFromKeyboard` flag with synchronous reset using `defer` statement
  - Prevents race conditions during rapid key presses
  - Timer-based validation ensures consistency before API calls
  - No recursive calls in `performSearch()` - direct state updates only

### Supported Route Types
- Regular Routes: 1, 2, 3... 999
- Express Routes: 1A, 2X, 3M...
- Airport Routes: A10, A21, E23...
- Night Routes: N170, N260...
- Special Routes: R8, S1...

### Station Search Features
- GPS-based nearby stops (1km radius, up to 50 stops)
- Single character search support (minimum 1 character, 0.5s debounce)
- Recent stops history (10 most recent)
- Inline route display with truncation
- Distance-only display for cleaner layout

## Performance Optimizations

### Location Strategy
- UserDefaults-based location cache (10-minute validity)
- Low-accuracy GPS with 1.5s timeout
- Fallback to Central HK coordinates
- Route sorting cache to avoid re-processing 2,090 routes

### API Protection
- 30-minute intelligent caching for all API responses
- Batch ETA loading (5 routes/batch, 0.5s delays)
- 5-second cooldown on manual ETA refresh
- Progressive UI updates with loading indicators

### Data Loading
- Local JSON for stop coordinates (no API calls needed)
- Async stop name loading with fallback
- Coordinate validation (NaN, infinite, out-of-range checks)
- Smart deduplication using company+route+direction keys

## Recent Changes

See [CHANGELOG.md](CHANGELOG.md) for detailed update history.

**Latest Version**: v0.14.3 (2025-12-30)
- **Invalid Route Filtering & Validation System**:
  - 3-layer defense system: search filtering → direction validation → error handling
  - Keyboard-level validation prevents typing invalid route numbers
  - Example: Typing "9" disables "C" button (9C has no stops), typing "90" enables "C" (90C has stops)
  - Single-direction routes (e.g., A28X) correctly hide direction switch button
  - LocalBusDataManager.swift: Enhanced getPossibleNextCharacters() with stop data validation
  - SearchViewController.swift: Direction validation before selection sheet
  - RouteDetailViewController.swift: Fixed fetchAvailableDirections() to use filtered local data

**Previous Versions**:
- **v0.14.1** (2025-12-22): Firebase API Key Security Update (regeneration, Git history cleanup, protection)
- **v0.14.0** (2025-12-22): Custom keyboard reliability fixes (re-appearance bug, animation conflicts)
- **v0.13.0** (2025-12-22): Station search optimization (10x scrolling performance, caching, loading states)
- **v0.12.3** (2025-12-18): Toast notification appearance mode fix
- **v0.12.2** (2025-12-18): Settings page update indicator, smart download logic
- **v0.12.1** (2025-12-13): Firebase rsync error fix for Xcode 15+ compatibility
- **v0.12.0** (2025-12-13): Firebase Storage integration with auto-update mechanism

## Known Issues & Limitations

1. **CTB Special Routes**: 120 routes (R/P/N suffix) may return 403 Forbidden
   - Race day specials, peak hours, night services
   - Non-critical for daily use

2. **Location Services**: Requires user authorization
   - Fallback to Central HK if denied
   - Cached location used when available

3. **API Rate Limiting**: Government APIs may throttle excessive requests
   - Built-in protection with delays and cooldowns
   - Progressive loading to distribute load

## Firebase Data Distribution & Google Analytics Integration (In Progress)

### Implementation Phases

#### Phase 1: Python Data Collection Validation ✅
- Enhanced validation rules (10-layer validation system)
- Generate `bus_data_metadata.json` with version, MD5, SHA256 checksums
- Automatic backup mechanism (keep last 7 versions)
- Generate validation report `validation_report.json`

#### Phase 2: Firebase Manual Upload Flow 🔄
- Create Firebase project and configure Storage
- Implement `manual_upload_firebase.py` standalone script
- Configure Firebase Security Rules (app-only access)
- Upload data file + metadata file

#### Phase 3: iOS App Smart Download Mechanism 📱
- New `FirebaseDataManager.swift` (version check, download, verification)
- Modify `LocalBusDataManager.swift` (support reading from Documents)
- Auto check for updates on app launch (24-hour throttling)
- Manual update button in Settings page
- **Download only when updates available to save traffic**

#### Phase 4: Google Analytics Integration 📊
- Install Firebase Analytics SDK
- Implement `AnalyticsManager.swift` (track all core behaviors)
- Integrate tracking events in 8 pages
- Privacy settings (first launch consent + toggle in Settings)
- Track: route search, view, favorite, refresh, data updates

#### Phase 5: Future Automation (Post-Launch) 🤖
- Integrate Firebase upload into Python script
- Configure QNAP NAS Cron job (auto-run every 3 days)
- Implement data monitoring script (warn if >7 days old)
- Complete logging and email notifications

### Key Features
- **Smart Version Control**: Unix timestamp version + MD5/SHA256 verification
- **Traffic Savings**: 24-hour check throttling + download only when updated
- **Security**: Firebase Security Rules (authenticated iOS App only)
- **Comprehensive Analytics**: Track all core user behaviors + privacy compliant
- **Automated Operations**: Cron jobs + monitoring scripts + backup mechanism

### Timeline
- Week 1-4: Complete Phase 1-4
- Week 5: Testing and launch preparation
- Post-Launch: Implement Phase 5 (automation)

## Future Enhancements (Phase 3)

1. MapKit integration for stop visualization
2. iOS Widget support for home screen
3. Push notifications for bus arrivals
4. Apple Watch companion app
5. Siri Shortcuts integration
6. Enhanced offline mode with cached ETA data
7. Accessibility improvements (VoiceOver support)
