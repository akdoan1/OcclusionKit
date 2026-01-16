# OcclusionKit

A Swift library for detecting window occlusion on macOS.

## Features

- **Cross-application detection**: Check if *any* window is occluded, not just your own
- **Exact coverage percentage**: Get precise 0.0-1.0 coverage values, not just binary visible/hidden
- **Query builder**: Find windows by bundle ID, title, process, or custom predicates
- **Reactive APIs**: Combine publishers and AsyncSequence for observing changes
- **Accurate algorithm**: Uses region subtraction to avoid overcounting overlapping occluders

## Requirements

- macOS 10.15+
- Swift 5.9+
- Screen Recording permission: **OPTIONAL** (only needed for window title queries)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/OcclusionKit.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

```swift
import OcclusionKit

// Check if a window is mostly hidden
let isHidden = try await OcclusionKit.isOccluded(windowID, threshold: 0.5)

// Get exact coverage percentage
let coverage = try await OcclusionKit.coverage(for: windowID)
print("Window is \(Int(coverage * 100))% covered")

// Get full analysis
let result = try await OcclusionKit.calculate(for: windowID)
print("Covered by \(result.occludingWindows.count) windows")
print("Visible regions: \(result.visibleRegions)")
```

## Query Builder

Find windows without knowing their IDs:

```swift
// Find Terminal windows
let results = try await OcclusionKit
    .query()
    .bundle("com.apple.Terminal")
    .results()

// Find by title
let claude = try await OcclusionKit
    .query()
    .titleContains("Claude")
    .first()

// Complex queries
let windows = try await OcclusionKit
    .query()
    .process(myPID)
    .minArea(10000)
    .normalLayer()
    .filter { $0.title?.contains("Important") == true }
    .windows()
```

## Reactive Observation

### AsyncSequence

```swift
for await result in OcclusionKit.stream(for: windowID) {
    updateUI(visible: result.visiblePercentage)
}

// With filters
for await result in OcclusionKit.stream(for: windowID).whenOccluded(threshold: 0.7) {
    print("Window is now mostly hidden!")
}
```

### Combine

```swift
OcclusionKit.publisher(for: windowID)
    .filter { $0.coveragePercentage > 0.5 }
    .sink { result in
        print("Window became mostly hidden")
    }
    .store(in: &cancellables)

// Get just the coverage values
OcclusionKit.publisher(for: windowID)
    .coverageOnly()
    .removeDuplicates()
    .sink { coverage in
        print("Coverage changed to \(coverage)")
    }
    .store(in: &cancellables)
```

### Callback-based

```swift
let observer = OcclusionKit.observer(for: windowID) { result in
    print("Coverage: \(result.coveragePercentage)")
}
observer.start()
// Later...
observer.stop()
```

## API Reference

### Main Entry Points

```swift
// Simple checks
OcclusionKit.isOccluded(_ windowID: CGWindowID, threshold: Double = 0.5) async throws -> Bool
OcclusionKit.coverage(for windowID: CGWindowID) async throws -> Double
OcclusionKit.calculate(for windowID: CGWindowID) async throws -> OcclusionResult

// Query builder
OcclusionKit.query() -> WindowQuery

// Window list
OcclusionKit.allWindows() throws -> [WindowInfo]
OcclusionKit.window(_ windowID: CGWindowID) throws -> WindowInfo?

// Observation
OcclusionKit.publisher(for windowID: CGWindowID, interval: TimeInterval = 0.5) -> OcclusionPublisher
OcclusionKit.stream(for windowID: CGWindowID, interval: TimeInterval = 0.5) -> OcclusionStream
OcclusionKit.observer(for windowID: CGWindowID, interval: TimeInterval = 0.5, handler:) -> OcclusionObserver

// Permissions
OcclusionKit.hasPermission: Bool
OcclusionKit.requestPermission()
```

### OcclusionResult

```swift
struct OcclusionResult {
    let targetWindow: WindowInfo
    let coveragePercentage: Double  // 0.0 to 1.0
    let occludingWindows: [WindowInfo]
    let visibleRegions: [CGRect]

    var visiblePercentage: Double
    func isOccluded(threshold: Double = 0.5) -> Bool
    func isVisible(threshold: Double = 0.5) -> Bool
}
```

### WindowInfo

```swift
struct WindowInfo {
    let id: CGWindowID
    let processID: pid_t
    let bundleIdentifier: String?
    let title: String?
    let ownerName: String
    let frame: CGRect
    let layer: Int32
    let alpha: CGFloat
    let isOnScreen: Bool
    let zIndex: Int

    var area: CGFloat
    var isNormalLayer: Bool
    var isVisible: Bool
}
```

### WindowQuery

```swift
query()
    .process(_ pid: pid_t)
    .bundle(_ identifier: String)
    .bundleMatching(_ pattern: String)  // Supports * wildcard
    .title(_ title: String)
    .titleContains(_ substring: String)
    .titleMatching(_ regex: String)
    .owner(_ name: String)
    .windowID(_ id: CGWindowID)
    .minArea(_ area: CGFloat)
    .normalLayer()
    .visible()
    .filter(_ predicate: (WindowInfo) -> Bool)

    // Terminal operations
    .windows() async throws -> [WindowInfo]
    .results() async throws -> [OcclusionResult]
    .first() async throws -> OcclusionResult?
    .count() async throws -> Int
    .exists() async throws -> Bool
```

## Permissions

**Screen Recording permission is OPTIONAL.** Core occlusion features work without it.

### What works WITHOUT permission (no user consent needed):

| Feature | Status |
|---------|--------|
| `isOccluded()`, `coverage()`, `calculate()` | ✅ Works |
| Window bounds, layer, alpha, on-screen status | ✅ Works |
| Process ID, owner name | ✅ Works |
| `query().process()`, `query().owner()`, `query().windowID()` | ✅ Works |
| `query().bundle()` | ✅ Works (via NSRunningApplication) |
| `query().minArea()`, `query().layer()`, `query().normalLayer()` | ✅ Works |

### What REQUIRES Screen Recording permission:

| Feature | Status |
|---------|--------|
| Window titles from other apps | ❌ Returns `nil` without permission |
| `query().title()`, `query().titleContains()`, `query().titleMatching()` | ❌ Won't match other apps' windows |

### Requesting permission (only if needed):

```swift
// Check if you have permission (only matters for title-based queries)
if !OcclusionKit.hasScreenRecordingPermission {
    OcclusionKit.requestScreenRecordingPermission()  // Shows system dialog
}
```

## How It Works

The library uses **region subtraction** to accurately calculate visible area:

```swift
// Start with target window as fully visible
var visibleRegion = RegionSet(rect: targetFrame)

// Subtract each window in front (in z-order)
for window in windowsAbove {
    visibleRegion.subtract(window.frame)
}

// Calculate coverage
let coverage = 1.0 - (visibleRegion.area / targetArea)
```

This is more accurate than summing intersection areas, which overcounts when covering windows overlap each other.

## License

MIT License - see [LICENSE](LICENSE) for details.
