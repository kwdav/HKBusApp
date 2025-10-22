# Changelog

All notable changes to the HK Bus App project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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