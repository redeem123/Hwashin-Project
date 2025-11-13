# AR Quality Inspection System - User Manual

## Table of Contents
1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Scanning Workflow](#scanning-workflow)
4. [Recognition & Comparison](#recognition--comparison)
5. [Viewing Results](#viewing-results)
6. [Tips & Best Practices](#tips--best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Getting Started

### System Requirements
- iPad Pro (2020 or later) with LiDAR scanner
- iOS 14.0 or higher
- Sufficient storage for template database (minimum 2GB recommended)
- Good lighting conditions (indoor lighting preferred)

### First Time Setup

1. **Launch the Application**
   - Tap the AR Quality Inspection icon
   - Grant permissions when prompted:
     - Camera access
     - Photos access (for saving results)

2. **Import Templates**
   - Navigate to Settings → Template Database
   - Tap "Import Templates"
   - Select CAD files provided by HWASHIN (.stl, .obj, or .step files)
   - Wait for import completion

3. **Calibration**
   - First scan: Point device at a known good part
   - Follow on-screen calibration instructions
   - Confirm when calibration is successful

---

## Interface Overview

### Main Screen Elements

```
┌─────────────────────────────────────┐
│  ☰  AR Quality Inspection      ⚙️  │  ← Header
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Ready to scan              │   │  ← Status Bar
│  └─────────────────────────────┘   │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░    │  ← Progress Bar
│                                     │
│                                     │
│        [AR Camera View]             │  ← AR View
│                                     │
│                                     │
│                                     │
│  ┌───────────────────────────────┐ │
│  │[Start] [Recognize][Compare]   │ │  ← Control Panel
│  │          [Results]             │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Button Functions

| Button | Function | When Available |
|--------|----------|----------------|
| **Start Scan** | Begin/stop LiDAR scanning | Always |
| **Recognize** | Identify scanned part | After successful scan |
| **Compare** | Analyze against template | After recognition |
| **Results** | View detailed report | After comparison |

---

## Scanning Workflow

### Step 1: Prepare the Part

✅ **Do:**
- Place part on stable surface
- Ensure good, even lighting
- Remove any loose debris
- Have clear space around part (360° access)

❌ **Don't:**
- Scan in direct sunlight
- Place part on reflective surfaces
- Have people/objects moving nearby
- Rush the scanning process

### Step 2: Start Scanning

1. **Position Device**
   - Hold iPad/iPhone 30-50cm from part
   - Point camera at center of part
   - Ensure entire part is visible

2. **Tap "Start Scan"**
   - Green border appears around viewfinder
   - Point cloud begins accumulating
   - Status bar shows point count

3. **Move Around Part**
   - Slow, steady circular motion
   - Maintain 30-50cm distance
   - Tilt to capture top and bottom
   - Complete full 360° circuit

4. **Monitor Progress**
   - Watch progress bar fill
   - Green = good quality
   - Yellow = acceptable
   - Red = insufficient (rescan needed)
   - Target: >70% scan quality

5. **Stop Scanning**
   - Tap "Stop Scan" when progress bar is green
   - System processes point cloud
   - Confirmation message appears

### Scan Quality Indicators

| Color | Quality | Action |
|-------|---------|--------|
| 🟢 Green | Excellent (>80%) | Proceed to recognition |
| 🟡 Yellow | Good (60-80%) | Can proceed, but consider rescan |
| 🔴 Red | Poor (<60%) | Rescan required |

---

## Recognition & Comparison

### Step 3: Recognize Part

1. **Tap "Recognize" Button**
   - System searches template database
   - Machine learning analysis in progress
   - Wait 2-5 seconds

2. **Review Results**
   - Part name displayed
   - Confidence percentage shown
   - Alternative matches listed (if any)

3. **Confirm or Select**
   - If correct: proceed to comparison
   - If incorrect: select correct part from alternatives
   - If not found: add to database or rescan

### Recognition Confidence Guide

| Confidence | Reliability | Recommendation |
|-----------|-------------|----------------|
| 90-100% | Excellent | Proceed with confidence |
| 80-90% | Good | Review alternative matches |
| 70-80% | Fair | Verify part identification |
| <70% | Poor | Rescan or manual selection |

### Step 4: Compare with Template

1. **Tap "Compare" Button**
   - System loads CAD template
   - Calculates point-to-surface distances
   - Generates deviation map
   - Wait 3-8 seconds

2. **View Heat Map Overlay**
   - Color-coded visualization appears on part
   - Blue = within tolerance (good)
   - Green = slight deviation (acceptable)
   - Yellow = borderline (inspect closely)
   - Orange = exceeds tolerance (warning)
   - Red = significant deviation (fail)

3. **Interact with Visualization**
   - Pinch to zoom
   - Rotate device to view different angles
   - Tap specific areas for detailed measurements

---

## Viewing Results

### Step 5: Detailed Results

1. **Tap "Results" Button**
   - Results panel slides up
   - Three main sections displayed

2. **Summary Section**
   ```
   Status: PASSED ✓
   Inspection Date: Jan 15, 2026 14:30
   Max Deviation: 0.42 mm
   Avg Deviation: 0.15 mm
   ```

3. **Measurements Section**
   - List of critical dimensions
   - Measured vs. nominal values
   - Pass/fail indicators (✓ or ✗)
   - Tolerance limits shown

4. **Statistics Section**
   ```
   Total Points: 45,231
   In Tolerance: 44,089 (97.5%)
   Out of Tolerance: 1,142 (2.5%)
   Processing Time: 4.2 seconds
   ```

### Saving Results

1. **Screenshot Method**
   - Tap camera icon
   - Image saved to Photos
   - Includes heat map overlay

2. **Export Report**
   - Tap share icon
   - Select format (PDF/CSV)
   - Email or save to Files

3. **Inspection History**
   - Access from Settings
   - View past inspections
   - Compare results over time

---

## Tips & Best Practices

### For Best Results

🎯 **Scanning Tips:**
- Move slowly (5-10 seconds per circuit)
- Keep device steady
- Overlap scan passes slightly
- Capture all angles including hidden areas

🎯 **Environmental Tips:**
- Use consistent indoor lighting
- Avoid shadows on part
- Stable temperature (no thermal expansion)
- Minimal vibration

🎯 **Part Preparation:**
- Clean surface (no oil or dust)
- Secure part (prevent movement)
- Mark orientation if needed
- Note serial number for tracking

### Common Workflows

**Quick Inspection (2-3 minutes)**
1. Quick scan (1 circuit)
2. Auto-recognize
3. Compare and review heat map
4. Screenshot results

**Detailed Inspection (5-10 minutes)**
1. Thorough scan (2-3 circuits)
2. Manual part verification
3. Full comparison analysis
4. Export detailed report
5. Document anomalies

**Batch Inspection**
1. Scan multiple parts sequentially
2. Queue recognition and comparison
3. Generate batch report
4. Statistical analysis across batch

---

## Troubleshooting

### Issue: Scan Quality Too Low

**Symptoms:**
- Progress bar stays red/yellow
- Warning: "Insufficient scan data"

**Solutions:**
1. ✓ Improve lighting conditions
2. ✓ Move slower around part
3. ✓ Get closer to part (30-40cm)
4. ✓ Clean part surface
5. ✓ Check for obstructions

### Issue: Recognition Failed

**Symptoms:**
- "No match found" error
- Very low confidence (<50%)

**Solutions:**
1. ✓ Verify part is in database
2. ✓ Rescan with better coverage
3. ✓ Check part orientation
4. ✓ Clean camera lens
5. ✓ Update template database

### Issue: Inaccurate Comparison

**Symptoms:**
- Heat map doesn't align
- Unrealistic deviation values

**Solutions:**
1. ✓ Recalibrate system
2. ✓ Verify correct template selected
3. ✓ Check part for deformation
4. ✓ Ensure stable mounting
5. ✓ Restart application

### Issue: App Performance Slow

**Symptoms:**
- Low frame rate (<30 FPS)
- Long processing times (>10s)

**Solutions:**
1. ✓ Close other apps
2. ✓ Restart device
3. ✓ Check available storage
4. ✓ Update iOS
5. ✓ Reduce template database size

### Issue: Heat Map Not Visible

**Symptoms:**
- Comparison completes but no overlay
- Black screen after comparison

**Solutions:**
1. ✓ Adjust opacity setting
2. ✓ Check AR tracking quality
3. ✓ Reposition device
4. ✓ Toggle visualization mode
5. ✓ Restart AR session

---

## Advanced Features

### Custom Tolerances

1. Navigate to part in database
2. Tap "Edit Tolerances"
3. Adjust upper/lower limits
4. Save and recompare

### Comparison Settings

**Visualization Options:**
- Heat map (default)
- Wireframe overlay
- Point cloud view
- Hybrid mode

**Measurement Display:**
- Show all measurements
- Critical dimensions only
- Out-of-tolerance only

### Data Export

**Supported Formats:**
- PDF report with images
- CSV data for Excel
- JSON for system integration
- Screenshots (PNG/JPEG)

---

## Keyboard Shortcuts (iPad with keyboard)

| Shortcut | Action |
|----------|--------|
| `Space` | Start/stop scan |
| `R` | Recognize part |
| `C` | Compare |
| `V` | View results |
| `S` | Save/screenshot |
| `⌘ + Z` | Undo last action |
| `⌘ + Q` | Quit application |

---

## Quick Reference Card

### Standard Inspection Workflow

1. **Prepare** → Clean part, stable position
2. **Scan** → 360° circuit, >70% quality
3. **Recognize** → >80% confidence
4. **Compare** → Review heat map
5. **Results** → Save/export report

### Quality Criteria

- ✅ **PASSED:** All measurements within tolerance
- ⚠️ **CONDITIONAL:** Non-critical deviations only
- ❌ **FAILED:** Critical measurements out of spec

### Contact Support

- **Technical Issues:** toan.nguyenduc@hust.edu.vn
- **Template Updates:** templates@hwashin.co.kr
- **Training:** support@hwashin.co.kr

---

**Document Version:** 1.0
**Last Updated:** January 2026
**For:** HWASHIN-HUST AR Quality Inspection System

*For technical details, refer to Technical Documentation*
*For API integration, refer to API Reference*
