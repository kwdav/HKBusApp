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
- **hk-bus-crawling**: `https://data.hkbus.app/routeFareList.min.json`
  - Used for offline stop coordinates and bilingual names
  - 15,079 total stops across all companies
  - Attribution required: "HK Bus Crawling@2021, https://github.com/hkbus/hk-bus-crawling" (GPL-2.0)

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
- Add/remove/reorder routes with swipe gestures
- Station-specific route ETA favorites (stop + route combination)
- Contextual star button: hidden on "我的" page, visible on route search page

### 2. Real-Time ETA Display
- Concurrent API calls to CTB, NWFB, KMB with 30-minute caching
- Color-coded ETA (red=arriving, orange=2min, green=normal)
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

### 4. Route Detail View
- Visual route line with color coding (green=start, red=end, blue=middle)
- In-cell ETA display with tap-to-refresh (5s cooldown)
- Auto-refresh every 60 seconds for expanded stops
- Smart direction switching with fade animations
- Auto-expand nearest stop within 1000m

### 5. Station Search
- Recent stops history with persistent storage
- 1km proximity search (fallback to 3km)
- Inline route display with smart truncation
- GPS-based nearby stations

### 6. Location Services
- Smart location caching (10-minute validity)
- Triple-fallback: cached → low-accuracy GPS (1.5s timeout) → Central HK
- Sub-second nearby route loading

### 7. Navigation
- 3-tab interface: 我的 (star icon), 路線 (bus icon), 站點 (map pin icon)
- Tab bar with translucent blur effect
- Smart tab switching with navigation stack management

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
3. **Destination**: 14pt light gray (updated in v0.6.1)
4. **ETA Times**: 17pt, right-aligned, color-coded by urgency (updated in v0.6.1)

### Typography
- Bus numbers: 34pt semibold
- Station names: 24pt semibold (in station search, updated in v0.6.1)
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
- **State Synchronization**: Dual-state system with circular update prevention
  - `searchBar.text` (UI state) synced with `currentSearchText` (internal state)
  - `isUpdatingFromKeyboard` flag prevents infinite update loops
  - Search consistency validation before API calls

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

**Latest Version**: v0.6.1 (2025-10-22)
- Enhanced font sizes across the app: all normal fonts increased by 3pt for better readability
- Updated font scale system with new baselines: stop names 16pt, destinations 14pt, ETA times 17pt
- Improved developer tools with "Clear All Favorites Only" option for testing empty states
- Complete settings page with font management and hidden developer menu
- Previous: Fixed "我的" page scroll indicator positioning and section header spacing

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

## Future Enhancements (Phase 3)

1. Theme customization system with user-selectable themes
2. MapKit integration for stop visualization
3. iOS Widget support for home screen
4. Push notifications for bus arrivals
5. Apple Watch companion app
6. Siri Shortcuts integration
7. Enhanced offline mode with cached ETA data
8. Accessibility improvements (VoiceOver support)
