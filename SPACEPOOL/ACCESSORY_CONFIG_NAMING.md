# Accessory Config Naming Clarification

**Date:** January 22, 2026  
**Issue:** Config property names reference specific balls but control accessories
**Resolution:** Added clarifying comments, documented for future refactoring

---

## Summary

You correctly identified that the explosion settings are named `elevenBallExplosionRadius` and `elevenBallMaxExplosions`, but the 11-ball isn't what's exploding anymore—it's the **`explodeOnDestroy` accessory** that causes the explosion. That accessory could theoretically be attached to any ball.

**The sliders ARE working correctly**, but the underlying config property names are misleading legacy artifacts from before the accessory system.

---

## What Actually Happens

### The Config Properties

```swift
// BallDamageSystem.Config
var fourBallDamageRadius: CGFloat = 18.0        // Controls damagePulse ACCESSORY
var fourBallPulseDelay: TimeInterval = 1.0      // Controls damagePulse ACCESSORY
var fourBallMaxTriggers: Int = 2                // Controls damagePulse ACCESSORY
var elevenBallExplosionRadius: CGFloat = 10.0   // Controls ALL explosion accessories
var elevenBallMaxExplosions: Int = 1            // Controls explodeOnContact regeneration
```

### What They Control

**`fourBall*` properties → Control the `damagePulse` accessory:**
```swift
// PulseAccessory.swift - reads from config at runtime
let radiusInBlocks = damageSystem.config.fourBallDamageRadius
let pulseDelay = damageSystem.config.fourBallPulseDelay
let maxTriggers = damageSystem.config.fourBallMaxTriggers
```

**`elevenBall*` properties → Control ALL explosion accessories:**
```swift
// BallDamageSystem.swift - used by createMassiveExplosion()
let explosionRadius: CGFloat = config.elevenBallExplosionRadius * blockSize

// This is called by:
// - explodeOnContact accessory (instant explosion on damage)
// - explodeOnDestroy accessory (explosion when HP reaches 0)
```

---

## Why This Is Confusing

### Scenario 1: Attach damagePulse to a Different Ball

```swift
// What if we did this?
if ballKind == .seven {
    _ = attachAccessory("damagePulse")  // 7-ball with pulse ability!
}
```

**Result:**
- The 7-ball would pulse when damaged ✅
- It would use `config.fourBallDamageRadius` 🤔
- The setting is named "fourBall" but controlling a 7-ball
- **Confusing!** But it works correctly

### Scenario 2: Attach explodeOnDestroy to a Different Ball

```swift
// What if we did this?
if ballKind == .six {
    _ = attachAccessory("explodeOnDestroy")  // 6-ball explodes on death!
}
```

**Result:**
- The 6-ball would explode when HP reaches 0 ✅
- It would use `config.elevenBallExplosionRadius` 🤔
- The setting is named "elevenBall" but controlling a 6-ball
- **Confusing!** But it works correctly

---

## Why the Names Are Like This

**Historical Context:**

1. **Before Accessories (old system):**
   - 4-ball had a built-in pulse ability
   - 11-ball had a built-in explosion ability
   - Config: `fourBallDamageRadius` made sense!

2. **After Accessories (current system):**
   - 4-ball gets `damagePulse` accessory attached
   - 11-ball gets `explodeOnDestroy` accessory attached
   - Config: `fourBallDamageRadius` is misleading!

3. **Why Not Renamed:**
   - UserDefaults backward compatibility
   - Saved settings would be lost
   - The code still works (just confusing names)

---

## What We Fixed

### Added Clarifying Comments in BallDamageSystem

```swift
// MARK: Accessory Settings
// NOTE: Despite the property names referencing specific balls, these settings control
// ACCESSORIES that can be attached to any ball. The names are legacy from before the
// accessory system was implemented.

/// Damage pulse radius in blocks - controls damagePulse ACCESSORY (default 18.0)
/// Used by any ball with the damagePulse accessory (currently 4-balls)
var fourBallDamageRadius: CGFloat = 18.0

/// Explosion radius in blocks - controls ALL explosion accessories (default 10.0)
/// Used by both explodeOnContact and explodeOnDestroy accessories (currently 11-balls)
var elevenBallExplosionRadius: CGFloat = 10.0
```

**Now it's clear:**
- ✅ Properties control accessories, not specific ball types
- ✅ Comments explain actual usage
- ✅ Developers know what they're configuring

---

## Verification: Do the Sliders Work?

**YES! Let's trace the flow:**

### Damage Pulse Radius Slider

```
User drags "Damage Pulse Radius" slider
    ↓
PhysicsAdjusterUI.update4BallRadiusSlider() called
    ↓
damageSystem.config.fourBallDamageRadius = newValue
    ↓
Saved to UserDefaults
    ↓
PulseAccessory.unleashPulse() reads config at runtime
    ↓
let radiusInBlocks = damageSystem.config.fourBallDamageRadius
let radius = radiusInBlocks * blockSize
    ↓
✅ Pulse uses the slider value!
```

### Explosion Radius Slider

```
User drags "Explosion Radius" slider
    ↓
PhysicsAdjusterUI.update11BallExplosionRadiusSlider() called
    ↓
damageSystem.config.elevenBallExplosionRadius = newValue
    ↓
Saved to UserDefaults
    ↓
BallDamageSystem.createMassiveExplosion() called (by explosion accessory)
    ↓
let explosionRadius = config.elevenBallExplosionRadius * blockSize
    ↓
✅ Explosion uses the slider value!
```

**Both work correctly!** The naming is just confusing.

---

## Current State

✅ **What Works:**
- All sliders update the correct config properties
- All accessories read from config at runtime
- Settings apply to accessories regardless of which ball has them
- UserDefaults persistence works correctly

❌ **What's Confusing:**
- Config properties named after balls (`fourBall`, `elevenBall`)
- Actually control accessories (`damagePulse`, `explodeOnDestroy`)
- Could theoretically be on ANY ball, not just 4s and 11s

---

## Future Improvement

If we want to fix the naming properly (breaking change):

### Rename Config Properties

```swift
// Instead of:
var fourBallDamageRadius: CGFloat = 18.0
var elevenBallExplosionRadius: CGFloat = 10.0

// Use:
var pulseDamageRadius: CGFloat = 18.0
var explosionRadius: CGFloat = 10.0
```

**Benefits:**
- Names match what they control (accessories)
- No confusion about which ball they apply to
- Clearer API

**Cost:**
- Breaks UserDefaults compatibility
- Requires migration code
- Users lose saved settings (or need migration)

**See `CONFIG_NAMING_ISSUE.md` for full migration plan.**

---

## Bottom Line

**Your observation was 100% correct!** The settings are named after specific balls (`elevenBall`) but they actually control accessories that could be on any ball. The sliders ARE working correctly—the naming is just a legacy artifact from before accessories existed.

We've added comments to clarify this, but a proper renaming would require a migration strategy to preserve user settings.
