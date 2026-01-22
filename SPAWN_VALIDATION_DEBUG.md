# Spawn Validation Debug Enhancement

**Date:** January 21, 2026  
**Issue:** Cue ball spawning in explosion holes  
**Status:** ✅ Enhanced debug logging to diagnose

---

## Problem

After an 11-ball explosion creates a hole in the felt, the cue ball was respawning at the center `(437.0, 201.0)` which happened to be right in the explosion hole. The ball would immediately sink and trigger another respawn, creating an infinite loop of:

```
Explosion at center → Cue ball respawns at center → Sinks → Respawns → Sinks...
```

---

## Investigation

The `isValidSpawnPoint()` function **already has grid-based checks**:
- ✅ Checks `feltManager.isHole(at:)` - should detect destroyed felt
- ✅ Checks `feltManager.isFelt(at:)` - should verify it's valid felt
- ✅ Checks pocket clearance
- ✅ Checks ball clearance

**However**, the debug logs showed NO output from these checks, which means either:
1. The checks were passing incorrectly
2. The debug builds weren't including the prints
3. There was a timing issue with the grid update

---

## Solution: Enhanced Debug Logging

**File:** `StarfieldScene.swift` - `isValidSpawnPoint()` method

Added comprehensive debug logging to track exactly what's happening:

```swift
private func isValidSpawnPoint(_ p: CGPoint, minClearance: CGFloat) -> Bool {
    #if DEBUG
    print("🔍 Checking spawn point validity: \(p)")
    #endif
    
    // Check felt bounds
    guard let felt = blockFeltRect else { 
        #if DEBUG
        print("   ❌ No felt rect")
        #endif
        return false 
    }
    
    // Check grid
    if let feltManager = feltManager {
        let isHole = feltManager.isHole(at: p)
        let isFelt = feltManager.isFelt(at: p)
        
        #if DEBUG
        print("   Grid checks: isHole=\(isHole), isFelt=\(isFelt)")
        #endif
        
        if isHole {
            #if DEBUG
            print("   ❌ Spawn point rejected: over a hole")
            #endif
            return false
        }
        
        if !isFelt {
            #if DEBUG
            print("   ❌ Spawn point rejected: not on felt")
            #endif
            return false
        }
        
        // ... more checks ...
    }
    
    #if DEBUG
    print("   ✅ Valid spawn point!")
    #endif
    return true
}
```

---

## What This Will Show

Next time the cue ball respawns, you'll see:

### If Grid Detection Works:
```
🔍 Checking spawn point validity: (437.0, 201.0)
   Grid checks: isHole=true, isFelt=false
   ❌ Spawn point rejected: over a hole
⚠️ Center spawn point invalid for respawn, searching for alternative...
🔍 Checking spawn point validity: (523.4, 189.2)
   Grid checks: isHole=false, isFelt=true
   ✅ Passed grid checks
   ✅ Passed pocket clearance check
   ✅ Valid spawn point!
✅ Found alternative respawn point at (523.4, 189.2)
```

### If Grid Detection Fails:
```
🔍 Checking spawn point validity: (437.0, 201.0)
   Grid checks: isHole=false, isFelt=true
   ✅ Passed grid checks
   ✅ Valid spawn point!
✅ Cue ball respawned at (437.0, 201.0)
```

This would indicate a bug in the grid update or query system.

---

## Possible Issues to Watch For

### 1. Timing Issue
The explosion might be updating the grid **after** the spawn validation runs:
```
Ball destroyed → Request respawn → Check spawn (grid not updated yet) → Grid updates → Ball spawns in hole
```

**Fix:** Ensure grid updates happen synchronously before respawn.

### 2. Grid Coordinate Issue
The explosion might not be marking the exact center cells as destroyed:
```
Explosion at (437, 201) → Destroys cells around (437, 201) → Center cell still marked as felt
```

**Fix:** Verify explosion radius calculation and grid cell marking.

### 3. FeltManager Not Connected
If `feltManager` is nil during respawn:
```
🔍 Checking spawn point validity: (437.0, 201.0)
   ❌ FeltManager is nil!
```

**Fix:** Ensure feltManager is always initialized before any ball spawning.

---

## Expected Behavior After Fix

When an explosion happens at the center:

1. ✅ **Grid updated** - Center cells marked as `.destroyed`
2. ✅ **Cue ball destroyed** - Respawn requested
3. ✅ **Validation fails** - Center detected as hole
4. ✅ **Alternative found** - Random spawn point selected
5. ✅ **Ball spawns safely** - Away from the explosion hole
6. ✅ **No sinking loop** - Ball stays on felt

---

## Next Steps

1. **Run the app** with these debug enhancements
2. **Trigger an 11-ball explosion** near the center
3. **Watch the console** for the detailed spawn validation logs
4. **Identify the issue:**
   - If grid checks are failing → Timing or grid update issue
   - If grid checks are passing incorrectly → Grid query bug
   - If FeltManager is nil → Initialization issue

Once we see the actual debug output, we'll know exactly what's wrong and can apply the targeted fix!

---

## Files Modified

- **StarfieldScene.swift** - Added comprehensive debug logging to `isValidSpawnPoint()`

---

## Debug Output to Watch For

Key indicators:

✅ **Good:**
```
Grid checks: isHole=true, isFelt=false
❌ Spawn point rejected: over a hole
✅ Found alternative respawn point
```

❌ **Bad:**
```
Grid checks: isHole=false, isFelt=true  ← Should be true/false!
✅ Valid spawn point!  ← Should be rejected!
```

❌ **Critical:**
```
❌ FeltManager is nil!  ← Should never happen!
```

---

## Summary

The spawn validation code **looks correct** - it's already checking the grid for holes and valid felt. The enhanced debug logging will reveal:

1. Whether the grid checks are actually running
2. What the grid is reporting for the spawn point
3. Where the validation logic is failing

Once you run the app and see the debug output, share it and we can pinpoint the exact issue! 🔍
