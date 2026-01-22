# Pocket Sinking Debug Guide

## Issue
Balls are no longer sinking when they're over holes in the felt (created by 11-ball explosions).

## How Ball Sinking Works

### 1. Pocket Detection System
The ball uses a **sampling-based approach** to detect if it's over a hole:

1. **`unsupportedFractionUnderBall()`** - Samples points around the bottom semicircle of the ball
2. **`isFeltBlock()`** - Checks if each sample point has felt underneath it
3. **`FeltManager.isGridPositionDestroyed()`** - Checks the felt grid to see if that position was destroyed by an explosion

### 2. Sinking Threshold
- Balls sink when the **unsupported fraction** exceeds a threshold
- Threshold is speed-dependent:
  - At rest: `minUnsupportedAtZeroSpeed` (default 0.4 = 40% unsupported)
  - At high speed: `maxUnsupportedAtHighSpeed` (default 0.75 = 75% unsupported)
  - In between: interpolated based on speed

### 3. Accessories
- Flying accessory **prevents sinking** (wings deploy over pockets)
- This is checked BEFORE the unsupported fraction test

## Debug Logging Added

I've added comprehensive debug logging to help diagnose the issue:

### In `BlockBall.swift`:

#### `isFeltBlock()` method:
```
🕳️ Checking grid at row:X col:Y for point:(x,y)
   feltRect: ...
   isDestroyed: true/false
```
Logs the first 5 grid checks to see if destruction detection is working.

#### `unsupportedFractionUnderBall()` method:
```
🕳️ [ball type] ball detecting hole: sample X/Y at (x,y)
   Ball position: ...
   Unsupported: X/Y so far

⚠️ [ball type] ball SHOULD sink: unsupported=0.XX, threshold=0.XX
   Position: ...
```
Logs when a ball detects unsupported area and when it should sink.

#### `maybeTriggerSink()` method:
```
🪽 [ball type] ball sink PREVENTED by accessory (flying wings)

🔍 [ball type] ball sink check:
   speed=X.X
   unsupported=0.XX
   required=0.XX
   will sink: true/false

💧 TRIGGERING SINK for [ball type] ball!
```
Shows the sinking decision process and when sink is actually triggered.

### In `BlockTableBuilder.swift` (FeltManager):

#### `removeBlock()` method:
```
🕳️ FeltManager removing block at row:X col:Y position:(x,y)
⚠️ FeltManager: block position out of grid bounds: row:X col:Y
```
Confirms when felt blocks are removed from the grid.

#### `isGridPositionDestroyed()` method:
```
🕳️ Grid position out of bounds: row:X col:Y (bounds: ...)
🕳️ Grid position destroyed: row:X col:Y
```
Shows which grid positions are detected as destroyed (first 10 only).

## What to Look For

Run your app in Debug mode and trigger an 11-ball explosion. Watch the console for:

### ✅ **Expected Flow (Working Correctly)**:
1. Explosion happens
2. Multiple `🕳️ FeltManager removing block` messages
3. Texture rebakes with holes
4. Ball rolls over hole
5. `🕳️ Checking grid` messages show `isDestroyed: true`
6. `🕳️ [ball] detecting hole` messages appear
7. `⚠️ [ball] SHOULD sink` message appears
8. `💧 TRIGGERING SINK` message appears
9. Ball sinks

### ❌ **Problem Scenarios**:

#### Scenario A: Grid Not Being Updated
- Explosion happens
- **NO** `🕳️ FeltManager removing block` messages
- **CAUSE**: Blocks aren't being passed to `removeBlock()`
- **FIX**: Check `BallDamageSystem.destroyFeltBlocks()`

#### Scenario B: Grid Coordinate Mismatch
- Grid removal messages appear
- Ball rolls over hole
- `🕳️ Checking grid` shows **different** row/col than removal
- **CAUSE**: Coordinate system mismatch between removal and detection
- **FIX**: Check coordinate calculations in both methods

#### Scenario C: Detection Not Running
- Grid updates correctly
- Ball over hole
- **NO** `🕳️ Checking grid` or `🕳️ detecting hole` messages
- **CAUSE**: `unsupportedFractionUnderBall()` not being called
- **FIX**: Check if `maybeTriggerSink()` is being called in `update()`

#### Scenario D: Threshold Too High
- All detection works
- `⚠️ SHOULD sink` appears
- **NO** `💧 TRIGGERING SINK` message
- **CAUSE**: Threshold calculation prevents sinking
- **FIX**: Check `minUnsupportedAtZeroSpeed` value or speed-based interpolation

#### Scenario E: Flying Accessory Bug
- All detection works
- `🪽 sink PREVENTED by accessory` appears for balls WITHOUT wings
- **CAUSE**: Flying accessory incorrectly attached
- **FIX**: Check `BallAccessoryManager.preventsSinking()`

## Quick Test

1. Build and run in Debug mode
2. Spawn an 11-ball (if not already on screen)
3. Hit the 11-ball to trigger explosion
4. Watch console for `🕳️ FeltManager removing block` messages
5. Roll a ball over the hole
6. Watch for detection messages

## Potential Fixes

If the issue is found, here are common fixes:

### Fix 1: Grid Not Updating (removeBlock not called)
Check that `BallDamageSystem.destroyFeltBlocks()` is calling `feltManager.removeBlock()` for each destroyed block.

### Fix 2: Coordinate Mismatch
Ensure both removal and detection use the same formula:
```swift
let col = Int((position.x - feltRect.minX) / blockSize)
let row = Int((position.y - feltRect.minY) / blockSize)
```

### Fix 3: Threshold Too High
Temporarily lower the threshold to test:
```swift
// In BlockBall init or configuration
minUnsupportedAtZeroSpeed = 0.2  // Was 0.4
```

### Fix 4: Sample Depth Too Shallow
Increase the sample depth if balls are barely touching holes:
```swift
supportSampleDepth = 5.0  // Was 2.5
```

## Manual Testing

You can manually test pocket detection by:

1. Spawning a ball over a known pocket (normal pocket, not explosion hole)
2. Watch for `🕳️ detecting hole` messages
3. If normal pockets work but explosion holes don't, it's a grid issue
4. If neither work, it's a fundamental detection issue

## Next Steps

After reviewing the debug logs, report back:
- Which messages appear
- Which messages are missing
- Any unexpected values (coordinates, thresholds, etc.)

This will pinpoint exactly where the issue is in the sinking pipeline.
