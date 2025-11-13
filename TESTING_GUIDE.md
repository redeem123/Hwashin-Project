# AR Quality Inspection - Testing Guide

## 🧪 How to Test This Application

This guide will help you build, deploy, and test the AR Quality Inspection system.

---

## Prerequisites

### Required Hardware
- ✅ **Mac computer** running macOS 11.0 or later
- ✅ **iPad Pro (2020+)** with LiDAR scanner, OR
- ✅ **iPhone 12 Pro or later** with LiDAR scanner
- ✅ **USB cable** to connect device to Mac

### Required Software
- ✅ **Xcode 12.0+** (Download free from Mac App Store)
- ✅ **Apple Developer Account** (Free tier is fine)
  - Sign up at: https://developer.apple.com

### Recommended
- 📦 Sample CAD files (.stl, .obj, or .step format)
- 🔧 Physical manufactured parts to scan
- 💡 Good indoor lighting

---

## Step 1: Install Xcode

```bash
# Option A: Install from Mac App Store
# 1. Open App Store on Mac
# 2. Search for "Xcode"
# 3. Click "Get" then "Install"
# 4. Wait for download (~12GB)

# Option B: Install from command line
xcode-select --install

# Verify installation
xcodebuild -version
# Should show: Xcode 12.0 or higher
```

---

## Step 2: Clone & Set Up Project

```bash
# 1. Clone the repository (if not already done)
git clone https://github.com/redeem123/Hwashin-Project.git
cd Hwashin-Project

# 2. Switch to the feature branch with all code
git checkout claude/plan-tell-feature-011CV5TCsvf96kr8caReGavL

# 3. Verify files are present
ls -la ARQualityInspection/Source/
# Should see: Models/, Services/, ViewControllers/
```

---

## Step 3: Create Xcode Project

Since we have Swift source files but no `.xcodeproj` file yet, you need to create one:

### 3A. Create New Xcode Project

1. **Open Xcode**

2. **File → New → Project**

3. **Select Template:**
   - Choose: **iOS** → **App**
   - Click **Next**

4. **Configure Project:**
   - **Product Name:** `ARQualityInspection`
   - **Team:** Select your Apple ID
   - **Organization Identifier:** `com.hwashin.iet` (or your own)
   - **Interface:** Storyboard
   - **Language:** Swift
   - **Use Core Data:** Unchecked
   - **Include Tests:** Checked (optional)

5. **Save Location:**
   - Navigate to: `/home/user/Hwashin-Project/`
   - Click **Create**

### 3B. Add Source Files

1. **Delete default files:**
   - In Xcode project navigator, delete:
     - `ViewController.swift`
     - `SceneDelegate.swift` (if present)

2. **Add our source files:**
   - Right-click on `ARQualityInspection` folder
   - Select **Add Files to "ARQualityInspection"...**
   - Navigate to `ARQualityInspection/Source/`
   - Select all folders: `Models`, `Services`, `ViewControllers`
   - ✅ Check **"Copy items if needed"**
   - ✅ Check **"Create groups"**
   - Click **Add**

3. **Verify structure:**
   ```
   ARQualityInspection/
   ├── Models/
   │   └── Part.swift
   ├── Services/
   │   ├── LiDARScanningService.swift
   │   ├── ObjectRecognitionEngine.swift
   │   ├── GeometricComparisonEngine.swift
   │   ├── TemplateDatabaseManager.swift
   │   └── ARVisualizationEngine.swift
   └── ViewControllers/
       └── MainARViewController.swift
   ```

---

## Step 4: Configure Project Settings

### 4A. Configure Info.plist

1. **Open Info.plist** (in project navigator)

2. **Add camera permission:**
   - Click **+** to add new row
   - Key: `Privacy - Camera Usage Description`
   - Value: `AR Quality Inspection requires camera access for LiDAR scanning`

3. **Add photo library permission:**
   - Add new row
   - Key: `Privacy - Photo Library Usage Description`
   - Value: `Save inspection results and screenshots`

4. **Add AR requirement:**
   - Add new row
   - Key: `Required device capabilities`
   - Type: Array
   - Add item: `arkit`

### 4B. Enable Capabilities

1. **Select project** in navigator

2. **Select target** `ARQualityInspection`

3. **Go to "Signing & Capabilities" tab**

4. **Enable required capabilities:**
   - Click **+ Capability**
   - Add: **Camera**
   - Add: **ARKit** (may need to scroll)

5. **Set up signing:**
   - **Team:** Select your Apple ID / development team
   - **Bundle Identifier:** Keep default or use `com.hwashin.iet.ARQualityInspection`

### 4C. Update AppDelegate

Replace the content of `AppDelegate.swift`:

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)

        // Set root view controller
        let mainVC = MainARViewController()
        window?.rootViewController = mainVC
        window?.makeKeyAndVisible()

        return true
    }
}
```

---

## Step 5: Connect Your Device

1. **Connect iPad/iPhone** to Mac via USB cable

2. **Trust computer on device:**
   - On device: Tap **Trust** when prompted
   - Enter device passcode

3. **Enable Developer Mode** (iOS 16+):
   - On device: Settings → Privacy & Security → Developer Mode
   - Toggle **ON**
   - Restart device

4. **In Xcode:**
   - Top toolbar: Select your device from dropdown
   - Should show: "Your iPhone/iPad Name"

---

## Step 6: Build and Run

### 6A. First Build

```bash
# In Xcode, press:
⌘ + B    # Build project
```

**Expected:**
- ✅ Build should succeed
- ⚠️ May see warnings (normal for first build)
- ❌ If errors, see Troubleshooting section below

### 6B. Deploy to Device

```bash
# In Xcode, press:
⌘ + R    # Build and Run
```

**What happens:**
1. Xcode compiles the app
2. App installs on your device
3. App launches automatically
4. You'll see permission prompts

### 6C. Grant Permissions

On your device:
1. **Allow camera access** → Tap **OK**
2. **Allow photos access** → Tap **Allow**

---

## Step 7: Test the Application

### Test 1: Check UI Loads

**Expected:**
- ✅ AR camera view appears
- ✅ Status bar at top shows "Ready to scan"
- ✅ Four buttons at bottom: [Start Scan] [Recognize] [Compare] [Results]
- ✅ Recognize, Compare, Results buttons are disabled (grayed out)

**If not working:** See Troubleshooting section

### Test 2: Test LiDAR Scanning

1. **Find a test object:**
   - Use any medium-sized object (10cm - 1m)
   - Good lighting, stable surface
   - Examples: box, tool, household item

2. **Start scanning:**
   - Tap **[Start Scan]** button
   - Button changes to "Stop Scan" (red)

3. **Scan the object:**
   - Hold device 30-50cm from object
   - Move slowly around object (360°)
   - Watch progress bar fill up
   - Look for green color (good quality)

4. **Stop scanning:**
   - Tap **[Stop Scan]** when progress bar is green (>70%)
   - Status should show: "Scan complete: [X] points"
   - **[Recognize]** button should enable

**Expected Results:**
- ✅ Point cloud captures (watch status bar for point count)
- ✅ Progress bar shows scan quality
- ✅ Can complete scan in 15-30 seconds
- ✅ Recognize button enables after scan

### Test 3: Test Recognition (Without Templates)

**Note:** Since you don't have templates imported yet, recognition will fail (expected).

1. Tap **[Recognize]** button
2. Wait 2-3 seconds
3. Should see error: "No match found in database"

**This is expected!** We'll add templates next.

### Test 4: Import Test Template

For testing without real CAD files:

1. **Create a simple test template:**
   - Download a free STL file from Thingiverse.com
   - Or use any .obj file
   - Save to your device

2. **Import to app** (feature to be added):
   - Currently manual import needed
   - Place files in app's Documents directory

**For now, you can test the scan and recognition UI flow.**

---

## Step 8: Advanced Testing

### Test with Simulator (Limited)

**Note:** iPhone Simulator doesn't support LiDAR, so you can only test UI.

```bash
# In Xcode:
# 1. Select "iPhone 14 Pro" from device dropdown
# 2. Press ⌘ + R
```

**What works in Simulator:**
- ✅ UI layout and buttons
- ✅ Navigation flow
- ❌ LiDAR scanning (will fail)
- ❌ AR visualization (will fail)

### Performance Testing

Monitor performance while scanning:

1. **In Xcode:**
   - Window → Show Debug Area (⌘ + Shift + Y)
   - Debug → Performance → Debug Performance

2. **Watch metrics:**
   - FPS (should be 30+)
   - Memory usage
   - CPU usage

### Test Different Scenarios

**Good Conditions:**
- ✅ Indoor lighting
- ✅ Matte surfaces
- ✅ Stable object
- ✅ Medium size (20cm - 1m)

**Challenging Conditions:**
- ⚠️ Bright sunlight
- ⚠️ Reflective surfaces (metal, glass)
- ⚠️ Very small (<10cm) or large (>2m) objects
- ⚠️ Transparent materials

---

## Troubleshooting

### Build Errors

**Error: "No such module 'ARKit'"**
```
Solution:
1. Project Settings → Build Phases
2. Link Binary With Libraries
3. Click + and add: ARKit.framework
```

**Error: "Command CodeSign failed"**
```
Solution:
1. Signing & Capabilities
2. Select your Team
3. Check "Automatically manage signing"
```

**Error: Swift version mismatch**
```
Solution:
1. Build Settings
2. Search for "Swift Language Version"
3. Set to: Swift 5
```

### Runtime Errors

**App crashes on launch**
```
Check Console (⌘ + Shift + C) for error messages

Common causes:
- Missing Info.plist permissions
- ARKit not linked
- Device doesn't support LiDAR
```

**"LiDAR not supported" error**
```
Solution:
- Ensure device is iPad Pro 2020+ or iPhone 12 Pro+
- Check device compatibility
```

**Camera permission denied**
```
Solution:
1. Device: Settings → ARQualityInspection
2. Toggle Camera permission ON
3. Restart app
```

### Performance Issues

**Low FPS (<30)**
```
Solutions:
- Close other apps
- Restart device
- Check Debug console for errors
- Reduce scan resolution in code
```

**App running slowly**
```
Solutions:
- Build in Release mode: Product → Scheme → Edit Scheme → Run → Release
- Check available storage
- Update iOS to latest version
```

---

## Testing Checklist

### Basic Functionality
- [ ] App launches successfully
- [ ] UI loads correctly
- [ ] Camera permission granted
- [ ] AR session starts
- [ ] LiDAR scanning captures points
- [ ] Scan quality indicator works
- [ ] Stop scan completes successfully
- [ ] Recognize button enables after scan
- [ ] Recognition attempt completes (even if no match)
- [ ] Error handling displays properly

### Performance
- [ ] FPS stays above 30 during scanning
- [ ] Point cloud captures smoothly
- [ ] No memory leaks (check Instruments)
- [ ] Battery usage reasonable
- [ ] App remains responsive

### User Experience
- [ ] Buttons enable/disable appropriately
- [ ] Status messages are clear
- [ ] Progress indicators work
- [ ] Error messages are helpful
- [ ] No app crashes

---

## Next Steps After Basic Testing

### 1. Add Real Templates

To test full workflow:
1. Get CAD files from HWASHIN (.stl, .obj, .step)
2. Implement file import UI
3. Test recognition with real parts

### 2. Test Full Workflow

Complete inspection process:
1. Scan real part
2. Recognize against template
3. Compare and generate deviation map
4. View AR heat map overlay
5. Check results and export

### 3. Optimize Performance

Based on testing:
1. Adjust scan resolution
2. Optimize recognition algorithms
3. Tune visualization parameters
4. Reduce memory usage

---

## Alternative Testing Options

### Option 1: Without Physical Device

**Use iOS Simulator** (UI only):
- Can test UI layout and flow
- Cannot test LiDAR or AR features
- Good for code review and debugging

### Option 2: Remote Testing

**TestFlight Distribution:**
1. Archive app in Xcode
2. Upload to App Store Connect
3. Invite testers via TestFlight
4. They can install and test on their devices

### Option 3: Unit Testing

**Test individual components:**

```swift
// Example: Test object recognition
import XCTest

class RecognitionTests: XCTestCase {
    func testFeatureExtraction() {
        let extractor = FeatureExtractor()
        let mockData = createMockScanData()
        let features = extractor.extract(from: mockData)

        XCTAssertNotNil(features)
        XCTAssertGreaterThan(features?.boundingBox.maxX ?? 0, 0)
    }
}
```

---

## Getting Help

### Error? Issue? Need Support?

1. **Check Console:**
   - View → Debug Area → Show Debug Area
   - Look for error messages

2. **Enable Verbose Logging:**
   ```swift
   // Add to AppDelegate:
   #if DEBUG
   print("Debug mode enabled")
   #endif
   ```

3. **Contact Team:**
   - Technical: toan.nguyenduc@hust.edu.vn
   - GitHub Issues: (repo URL)

---

## Quick Reference Commands

```bash
# Build project
⌘ + B

# Run on device
⌘ + R

# Clean build
⌘ + Shift + K

# Stop running
⌘ + .

# Show console
⌘ + Shift + C

# Debug area
⌘ + Shift + Y
```

---

## Summary

**Minimum to test basic functionality:**
1. ✅ Mac with Xcode
2. ✅ iPad Pro/iPhone Pro with LiDAR
3. ✅ Create Xcode project
4. ✅ Add source files
5. ✅ Configure permissions
6. ✅ Build and run
7. ✅ Test scanning

**Expected test time:** 30-60 minutes for first setup

**Status:** Ready to test! 🚀

---

*For detailed usage instructions, see [User Manual](ARQualityInspection/Documentation/UserManual.md)*
*For technical details, see [Technical Documentation](ARQualityInspection/Documentation/README.md)*
