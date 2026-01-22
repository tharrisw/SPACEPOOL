# 11-Ball Accessory Bug Fix

**Date:** January 21, 2026  
**Issue:** Explosion not triggering on 11-ball destruction  
**Status:** ✅ FIXED

---

## Problem

After changing the 11-ball from `explodeOnContact` to `explodeOnDestroy`, the explosion wasn't triggering when the ball was destroyed. The normal destruction animation played instead.

---

## Root Cause

The `explodeOnDestroy` accessory was **registered** in `BallAccessoryManager.registerDefaultAccessories()`, but was **missing from the switch statement** in `BallAccessoryManager.attachAccessory()`.

This meant when `BlockBall` tried to attach the accessory:
```swift
_ = attachAccessory("explodeOnDestroy")  // Called in BlockBall init
```

The switch statement hit the `default` case and printed:
```
⚠️ Cannot instantiate accessory 'explodeOnDestroy'
```

So the accessory was never actually attached to the ball!

---

## The Fix

**File:** `BallAccessory.swift` (line ~1323)

**Added missing case:**
```swift
case "explodeOnDestroy":
    accessory = ExplodeOnDestroyAccessory()
```

### Before (Broken)
```swift
switch id {
case "flying":
    accessory = FlyingAccessory()
case "burning":
    accessory = BurningAccessory()
case "tempBurning":
    accessory = TempBurningAccessory()
case "explodeOnContact":
    accessory = ExplodeOnContactAccessory()
case "hat_topHat":
    accessory = HatAccessory(style: .topHat)
// ... other hats ...
default:
    print("⚠️ Cannot instantiate accessory '\(id)'")
    return false
}
```

### After (Fixed)
```swift
switch id {
case "flying":
    accessory = FlyingAccessory()
case "burning":
    accessory = BurningAccessory()
case "tempBurning":
    accessory = TempBurningAccessory()
case "explodeOnContact":
    accessory = ExplodeOnContactAccessory()
case "explodeOnDestroy":
    accessory = ExplodeOnDestroyAccessory()  // ✅ ADDED THIS!
case "hat_topHat":
    accessory = HatAccessory(style: .topHat)
// ... other hats ...
default:
    print("⚠️ Cannot instantiate accessory '\(id)'")
    return false
}
```

---

## Why This Happened

The `ExplodeOnDestroyAccessory` class existed and was registered, but wasn't wired up in the switch statement that actually creates instances. This is a common oversight when adding new accessories.

**The accessory manager has two places that need updating:**

1. ✅ **Registration** - `registerDefaultAccessories()` - Was already there!
2. ❌ **Instantiation** - `attachAccessory()` switch - Was MISSING!

---

## Testing After Fix

Now when a 11-ball is destroyed:

1. ✅ Accessory attaches successfully (no warning)
2. ✅ Ball takes damage normally
3. ✅ When HP reaches 0:
   - `handleBallDestruction()` is called
   - Checks `hasExplodeOnDestroy` (now returns `true`)
   - Converts ball to blocks
   - Creates massive explosion
   - Crater appears in felt
   - Nearby balls take damage

Expected debug output:
```
💥 Explode On Destroy accessory attached to eleven ball (invisible)
[after taking damage...]
💀 eleven ball destroyed!
💥 Ball has explodeOnDestroy - creating explosion at death position!
💥 Creating massive explosion at (x, y) with radius 100
```

---

## Related Changes

### 1. BlockBall.swift (line ~351)
Changed from `explodeOnContact` to `explodeOnDestroy`:
```swift
if kind == .eleven {
    _ = attachAccessory("explodeOnDestroy")
}
```

### 2. BallAccessory.swift (line ~1323)
Added switch case to instantiate the accessory (THIS WAS THE FIX):
```swift
case "explodeOnDestroy":
    accessory = ExplodeOnDestroyAccessory()
```

---

## Lesson Learned

When adding new accessories, make sure to update:

1. ✅ Create the accessory class (e.g., `ExplodeOnDestroyAccessory`)
2. ✅ Register it in `registerDefaultAccessories()`
3. ✅ **Add switch case in `attachAccessory()`** ← THIS WAS MISSING!
4. ✅ Use it in ball initialization or gameplay code

A checklist for future accessory additions would help prevent this!

---

## Summary

**Problem:** explodeOnDestroy accessory wasn't attaching  
**Cause:** Missing switch case in `attachAccessory()`  
**Fix:** Added `case "explodeOnDestroy"` to create instances  
**Result:** 11-balls now explode properly when destroyed! 💥
