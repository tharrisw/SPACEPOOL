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

Comprehensive debug logging has been added. Most logs are **throttled** (randomized probability) to avoid console spam while still providing diagnostic information.

### In BlockBall.swift:

**isFeltBlock() method:**
- Logs occasionally (1% chance) to show grid checks are happening
- Shows row/col coordinates and whether position is destroyed

**unsupportedFractionUnderBall() method:**
- Logs when first unsupported sample is detected
- Shows ball position and unsupported fraction
- Logs occasionally (3% chance) when ball should sink based on threshold

**maybeTriggerSink() method:**
- Logs when flying accessory prevents sinking (2% chance to avoid spam)
- Shows speed, unsupported fraction, required threshold, and decision
- Logs every time sink is actually triggered

### In BlockTableBuilder.swift (FeltManager):

**removeBlock() method:**
- Logs every time a felt block is removed from the grid
- Shows row/col coordinates and position

**isGridPositionDestroyed() method:**
- Logs occasionally (2% chance) when destroyed positions are checked
- Logs occasionally (1% chance) when out-of-bounds checks occur

## What to Look For

Run your app in Debug mode and trigger an 11-ball explosion. Watch the console for:

### Expected Flow (Working Correctly):
1. Explosion happens
2. Multiple `🕳️ FeltManager removing block` messages
3. Texture rebakes with holes
4. Ball rolls over hole
5. `🕳️ Checking grid` messages may appear
6. `🕳️ [ball] detecting hole` messages appear
7. `⚠️ [ball] SHOULD sink` message may appear
8. `💧 TRIGGERING SINK` message appears
9. Ball sinks

### Problem Scenarios:

**Scenario A: Grid Not Being Updated**
- Explosion happens
- NO `🕳️ FeltManager removing block` messages
- CAUSE: Blocks aren't being passed to removeBlock()
- FIX: Check BallDamageSystem.destroyFeltBlocks()

**Scenario B: Grid Coordinate Mismatch**
- Grid removal messages show certain row/col values
- Detection messages show different row/col values for same area
- CAUSE: Coordinate system mismatch
- FIX: Verify coordinate calculations match

**Scenario C: Detection Not Running**
- Grid updates correctly
- Ball over hole
- NO detection messages at all
- CAUSE: unsupportedFractionUnderBall() not being called
- FIX: Check if maybeTriggerSink() is called in update()

**Scenario D: Threshold Too High**
- Detection works
- `⚠️ SHOULD sink` appears
- NO `💧 TRIGGERING SINK` message
- CAUSE: Threshold calculation prevents sinking
- FIX: Check minUnsupportedAtZeroSpeed value

**Scenario E: Flying Accessory Bug**
- Detection works
- `🪽 sink PREVENTED by accessory` appears for balls WITHOUT wings
- CAUSE: Flying accessory incorrectly attached
- FIX: Check BallAccessoryManager.preventsSinking()

## Quick Test Steps

1. Build and run in Debug mode
2. Spawn or find an 11-ball
3. Hit the 11-ball to trigger explosion
4. Watch console for `🕳️ FeltManager removing block` messages
5. Roll a ball over the hole
6. Watch for detection messages

## Manual Testing

Test normal pockets first:
1. Spawn a ball over a normal pocket (one of the 6 permanent pockets)
2. Watch for detection messages
3. If normal pockets work but explosion holes don't: grid update issue
4. If neither work: fundamental detection problem

## Common Fixes

### Fix 1: Grid Not Updating
Ensure BallDamageSystem.destroyFeltBlocks() calls feltManager.removeBlock() for each block.

### Fix 2: Coordinate Mismatch
Both removal and detection must use identical coordinate formulas:
```swift
let col = Int((position.x - feltRect.minX) / blockSize)
let row = Int((position.y - feltRect.minY) / blockSize)
```

### Fix 3: Threshold Too High
Temporarily lower threshold to test:
```swift
minUnsupportedAtZeroSpeed = 0.2  // Was 0.4
```

### Fix 4: Sample Depth Too Shallow
Increase sample depth:
```swift
supportSampleDepth = 5.0  // Was 2.5
```

## Note on Throttled Logging

Debug logs use random probability to avoid spam:
- Grid checks: 1% chance per check
- Hole detection: only first sample per check
- Sink threshold checks: 3% chance per frame
- Grid destruction checks: 2% chance per check

This means you may not see every single check, but you'll see enough to diagnose issues. The important messages (like actual block removal and sink triggering) always log.
