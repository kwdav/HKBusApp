# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal
Create a user friendly iOS HK Bus App

## Architecture Overview

This project is converting an existing HTML/PHP web app into a native iOS app. The HTML reference implementation demonstrates the core functionality and UI patterns to follow.

### Data Flow Architecture
- **Bus Data Configuration**: Static array of bus stops with stopId, route, companyId, direction, and display subtitle
- **API Integration**: Real-time ETA data from Hong Kong government APIs for CTB and KMB bus companies
- **Caching Strategy**: Stop names are cached to reduce API calls
- **Auto-refresh**: ETA data refreshes every 50 seconds with manual refresh capability

### Key Components Structure
1. **Data Models**: Bus route configuration with company-specific API endpoints
2. **API Services**: Separate handling for CTB (Citybus) and KMB (Kowloon Motor Bus) APIs
3. **UI Components**: Route display with ETA times, stop names, and destinations
4. **Utility Functions**: Time calculation and formatting for ETA display

### API Endpoints Used
- **CTB**: `https://rt.data.gov.hk/v2/transport/citybus/`
- **NWFB**: `https://rt.data.gov.hk/v2/transport/citybus/`
- **KMB**: `https://data.etabus.gov.hk/v1/transport/kmb/`

### Search API Endpoints
- **CTB Route List**: `https://rt.data.gov.hk/v2/transport/citybus/route/CTB`
- **NWFB Route List**: `https://rt.data.gov.hk/v2/transport/citybus/route/NWFB`
- **KMB Route List**: `https://data.etabus.gov.hk/v1/transport/kmb/route`

## Reference Implementation
HTML reference code is located in `my html reference/` directory:
- `index.php`: Main page with bus data configuration
- `js/bus_time.js`: Core JavaScript functionality for API calls and UI updates
- `style/general.css`: Dark theme styling with mobile-optimized layout

## Development Commands
This is a new iOS project. No existing build commands yet - will need to be created with Xcode project structure.

## API Information
城巴的實時抵站時間及相關資料
https://data.gov.hk/tc-data/dataset/ctb-eta-transport-realtime-eta
https://www.citybus.com.hk/datagovhk/bus_eta_data_dictionary.pdf

九龍巴士及龍運巴士路線實時到站數據
https://data.gov.hk/tc-data/dataset/hk-td-tis_21-etakmb

專線小巴的實時到站數據
https://data.gov.hk/tc-data/dataset/hk-td-sm_7-real-time-arrival-data-of-gmb

## Development Status (Updated: 2025-08-20)

### ✅ Phase 1 (MVP) - COMPLETED
**Essential Features Implemented**
1. ✅ Real-time bus ETA display (CTB + KMB + NWFB APIs)
2. ✅ Dynamic favorites management (add/remove/reorder)
3. ✅ 50-second auto-refresh + manual pull-to-refresh
4. ✅ Basic error handling with user feedback
5. ✅ iOS native navigation with UITabBarController
6. ✅ **ENHANCED**: Full Hong Kong bus route search functionality

**Technical Implementation**
- ✅ UITabBarController for navigation (3 tabs: Bus List + Route Search + Stop Search)
- ✅ URLSession for concurrent API calls with DispatchGroup
- ✅ Core Data stack with BusRouteFavorite entity for persistence
- ✅ Pull-to-refresh with UIRefreshControl
- ✅ Loading states and error handling
- ✅ Custom table view cells with compact design
- ✅ **ENHANCED**: Advanced caching strategy (30-minute intelligent cache)
- ✅ **NEW**: Real-time route search across CTB, NWFB, KMB APIs
- ✅ **NEW**: Auto-capitalization for route input (KMB compatibility)
- ✅ **NEW**: Debounced search with 0.3s delay
- ✅ **NEW**: Enhanced data models for route search results
- ✅ **NEW**: Complete iOS appearance system integration (light/dark mode)

### 📝 Current Project Structure
```
HKBusApp/
├── AppDelegate.swift - Core Data initialization
├── SceneDelegate.swift - Programmatic UI setup
├── Models/
│   ├── BusRoute.swift - Route configuration with Company enum + Enhanced Search Models
│   │   ├── BusRouteDetail - Complete route with stops information
│   │   ├── BusStop - Individual stop data with coordinates
│   │   ├── RouteSearchResult - Grouped search results by route
│   │   └── DirectionInfo - Route direction with origin/destination
│   └── BusETA.swift - ETA data models and formatting + API Response Models
│       ├── CTBRouteListResponse - CTB/NWFB route list API response
│       └── KMBRouteListResponse - KMB route list API response
├── Services/
│   ├── BusAPIService.swift - Singleton API service for CTB/KMB/NWFB + Enhanced Search
│   │   ├── searchRoutes() - Full HK route search across all companies
│   │   ├── searchCTBRoutes() - City Bus route search
│   │   ├── searchNWFBRoutes() - New World First Bus route search
│   │   ├── searchKMBRoutes() - Kowloon Motor Bus route search
│   │   ├── fetchRouteDetail() - Get complete route with all stops
│   │   └── fetchStopETA() - Get real-time ETA for individual stops
│   ├── CoreDataStack.swift - Core Data persistence layer
│   └── FavoritesManager.swift - CRUD operations for favorites
├── Controllers/
│   ├── MainTabBarController.swift - Tab navigation setup with dark theme
│   ├── BusListViewController.swift - Main ETA display with edit mode
│   ├── SearchViewController.swift - **ENHANCED** Performance optimized route search
│   ├── RouteDetailViewController.swift - **NEW** Complete route with all stops
│   └── StopETAViewController.swift - **NEW** Individual stop ETA with auto-refresh
├── Views/
│   ├── BusETATableViewCell.swift - Compact cell design (90px height)
│   ├── SearchResultTableViewCell.swift - Search results display
│   ├── RouteStopTableViewCell.swift - **NEW** Visual route stop cells with color coding
│   └── ETATableViewCell.swift - **NEW** Individual ETA display with time formatting
└── Resources/
    ├── Assets.xcassets/ - App icons and accent colors
    ├── Main.storyboard - Interface Builder files
    └── LaunchScreen.storyboard - Launch screen
```

### 🎯 Key Features Successfully Implemented
1. **Dynamic Favorites System**: Users can add, remove, and reorder routes with Core Data persistence
2. **Efficient API Integration**: Concurrent calls to CTB, NWFB, and KMB APIs with caching
3. **Compact UI Design**: 90px cell height, prominent bus numbers (32pt font), company-colored borders
4. **Performance Optimized Search**: Only API calls when user types, no preloading for faster startup
   - Search input with auto-capitalization (KMB compatibility)
   - Debounced search (0.3s delay) to reduce API calls
   - Auto-focus search bar on tab switch
   - Direction selection for multi-direction routes
   - Smart grouping by route number and company
   - Touch-to-dismiss keyboard functionality
5. **Complete Route Visualization**: Detailed route view with all stops
   - Visual route line with color coding (green=start, red=end, blue=middle)
   - Stop sequence numbers and names
   - Company branding and route information
   - Smooth slide-in animations
6. **Individual Stop ETA Display**: Real-time bus arrival times
   - Color-coded ETA (red=arriving, orange=2min, green=normal)
   - Auto-refresh every 30 seconds
   - Pull-to-refresh manual update
   - Next bus highlighting
   - Empty state handling
7. **Auto-refresh**: Timer-based updates every 50 seconds with manual refresh capability
8. **Edit Mode**: Swipe-to-delete and drag-to-reorder for favorites management
9. **Meaningful Transitions**: Custom animations between views
   - Slide-in transitions for route details
   - Fade animations for view appearances
   - Touch feedback and highlights

### ✅ Phase 2 (Enhanced Features) - COMPLETED
**Complete Search Flow Implementation**
1. ✅ **Performance Optimized Search** - Only API calls on user input, no preloading
2. ✅ **Route Detail Page** - Complete route visualization with all stops
3. ✅ **Stop ETA View** - Individual stop real-time ETA display
4. ✅ **Meaningful Transitions** - Smooth slide and fade animations
5. ✅ **Auto-Focus Search** - Automatic keyboard activation
6. ✅ **Visual Route Lines** - Color-coded start/end/middle stops

### 🏗️ Phase 2 (Enhanced Features) - COMPLETED
**Performance & UX Improvements**
1. ✅ **Extended Cache Duration** - 30-minute cache for better performance
2. ✅ **Async Stop Name Loading** - Real-time stop name fetching with UI updates
3. ✅ **Refined Favorites System** - Station-specific route ETA favorites (not route-wide)
4. ✅ **Complete Route Visualization** - All stops displayed with real API data
5. ✅ **Enhanced Error Handling** - Graceful fallbacks and user feedback
6. ✅ **3-Tab Navigation** - Bus List, Route Search, Stop Search
7. ✅ **Light & Dark Mode Support** - Full iOS system appearance support

### 🚀 Phase 3 (Advanced Features) - FUTURE
**Value-Added Features**
1. MapKit integration for stop visualization
2. iOS Widget support for home screen
3. Push notifications for bus arrivals
4. Apple Watch companion app
5. Siri Shortcuts integration
6. Enhanced offline mode with cached ETA data
7. Accessibility improvements (VoiceOver support)

## Build & Development Information
- **Project Type**: Native iOS App (Swift 5.0)
- **Minimum iOS Version**: iOS 18.2
- **Architecture**: MVC with MVVM patterns
- **Persistence**: Core Data with BusRouteFavorite entity
- **API Integration**: Hong Kong government real-time transport APIs
- **UI Framework**: UIKit with programmatic UI (no Storyboard dependency)

## Search Functionality (Updated: 2025-08-20)

### 🔍 **Current Search Implementation**
The app now supports comprehensive route search across all major Hong Kong bus companies:

**Search Features:**
- **Real-time API Integration**: Searches CTB, NWFB, and KMB route databases simultaneously
- **Auto-capitalization**: Input automatically converts to uppercase (e.g., "1a" → "1A")
- **Debounced Search**: 0.3-second delay prevents excessive API calls during typing
- **Smart Grouping**: Results grouped by route number and company, with multiple directions combined
- **Direction Selection**: Action sheet for routes with multiple directions (outbound/inbound)
- **Keyboard Management**: Touch outside search area dismisses keyboard

**Search Flow:**
1. User types route number in search bar (e.g., "793", "A21", "N170")
2. App searches all three bus company APIs in parallel
3. Results display as "COMPANY ROUTE" with direction information
4. User selects route → direction selection (if multiple) → route detail page → stop ETA

**API Integration:**
```
┌─ User Input: "793" ─┐
│                     ├─ CTB API Search
│                     ├─ NWFB API Search  
│                     └─ KMB API Search
└─ Combined Results ──┘
   ├─ CTB 793: 雍明苑 → 機場博覽館 | 機場博覽館 → 雍明苑
   └─ [Other matching routes from other companies]
```

### 🎯 **Supported Route Types**
- **Regular Routes**: 1, 2, 3... 999
- **Express Routes**: 1A, 2X, 3M...
- **Airport Routes**: A10, A21, E23...
- **Night Routes**: N170, N260...
- **Special Routes**: R8, S1...

### 📱 **User Interface**
- Clean search bar at top of screen
- Cancel button for easy search clearing
- Real-time results as user types
- Company-coded results (CTB=yellow, KMB=red borders)
- Direction info shown as "Origin → Destination"

## Testing Status
- ✅ Project builds successfully with xcodebuild
- ✅ All Swift files compile without errors
- ✅ Core Data model generates properly
- ✅ Info.plist configured for programmatic UI
- ✅ **ENHANCED**: Complete search flow tested (search → route detail → stop ETA)
- ✅ **ENHANCED**: API integration verified for CTB, NWFB, KMB endpoints
- ✅ **ENHANCED**: 30-minute caching system working properly
- ✅ **NEW**: Async stop name loading with real API integration
- ✅ **NEW**: Station-specific favorites system (stop + route combination)
- ✅ **NEW**: Performance optimized search with no preloading
- ✅ **NEW**: Visual transitions and animations working properly
- ✅ **NEW**: Individual stop ETA display with auto-refresh
- ✅ **NEW**: Light & Dark Mode appearance tested across all views

