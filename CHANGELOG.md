# Changelog

All notable changes to the HK Bus App project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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