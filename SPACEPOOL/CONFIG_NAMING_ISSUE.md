# Config Property Naming Issue

**Date:** January 22, 2026  
**Issue:** Config properties are named after specific ball types but control accessories that could be on any ball
**Impact:** Confusing API, misleading settings UI

---

## The Problem

### Current Config Property Names (Ball-Specific)

```swift
struct Config {
    /// 4-ball pulse damage radius in blocks (default 18.0)
    var fourBallDamageRadius: CGFloat = 18.0
    
    /// 4-ball pulse delay in seconds before triggering (default 1.0)
    var fourBallPulseDelay: TimeInterval = 1.0
    
    /// Maximum number of times a 4-ball can be triggered before being destroyed (default 2)
    var fourBallMaxTriggers: Int = 2
    
    /// 11-ball explosion radius in blocks (default 10.0)
    var elevenBallExplosionRadius: CGFloat = 10.0
    
    /// Maximum number of times an 11-ball can explode before being destroyed (default 1)
    var elevenBallMaxExplosions: Int = 1
}
```

**Problem:** These properties are named after specific ball types (4-ball, 11-ball), but they actually control **accessories** that could theoretically be attached to any ball!

---

## What They Actually Control

### "4-Ball" Properties → damagePulse Accessory

```swift
// Used by PulseAccessory (currently on 4-balls, but it's an accessory!)
let radiusInBlocks = damageSystem.config.fourBallDamageRadius
let pulseDelay = damageSystem.config.fourBallPulseDelay
let maxTriggers = damageSystem.config.fourBallMaxTriggers
```

**If you attached `damagePulse` to a 7-ball:**
- It would still use `fourBallDamageRadius` 🤔
- The slider says "Damage Pulse Radius" but the config says "fourBall"

---

### "11-Ball" Properties → Explosion Accessories

```swift
// Used by createMassiveExplosion (called by BOTH explodeOnContact AND explodeOnDestroy)
let explosionRadius: CGFloat = config.elevenBallExplosionRadius * blockSize
```

**If you attached `explodeOnDestroy` to a 6-ball:**
- It would still use `elevenBallExplosionRadius` 🤔
- The slider says "Explosion Radius" but the config says "elevenBall"

**Both `explodeOnContact` AND `explodeOnDestroy` use the same radius setting!**

---

## Current Behavior (Correct but Confusing)

✅ **Sliders DO work correctly:**
- "Damage Pulse Radius" slider → updates `config.fourBallDamageRadius` → PulseAccessory reads it
- "Explosion Radius" slider → updates `config.elevenBallExplosionRadius` → createMassiveExplosion reads it

❌ **But the naming is misleading:**
- A 7-ball with damagePulse would use "fourBall" settings
- A 6-ball with explodeOnDestroy would use "elevenBall" settings
- The code looks like it's ball-specific when it's actually accessory-generic

---

## Ideal Solution (Breaking Change)

### Rename Config Properties to be Accessory-Specific

```swift
struct Config {
    // Pulse Accessory Settings
    var pulseDamageRadius: CGFloat = 18.0
    var pulseDamageDelay: TimeInterval = 1.0
    var pulseDamageMaxTriggers: Int = 2
    
    // Explosion Accessory Settings (shared by explodeOnContact and explodeOnDestroy)
    var explosionRadius: CGFloat = 10.0
    var explosionMaxUses: Int = 1  // For regenerating explosions
}
```

**Benefits:**
- ✅ Names match what they actually control (accessories, not balls)
- ✅ Clear that settings apply to accessories regardless of which ball has them
- ✅ Easier to understand and maintain

**Problem:**
- ❌ **Breaks UserDefaults compatibility!** Saved settings would be lost
- ❌ Requires migration code to preserve user settings

---

## Temporary Solution (Non-Breaking)

### Keep Current Names, Add Clarifying Comments

```swift
struct Config {
    // NOTE: Despite the name, these control the damagePulse ACCESSORY (not just 4-balls)
    
    /// Damage pulse radius in blocks (used by damagePulse accessory, default 18.0)
    var fourBallDamageRadius: CGFloat = 18.0
    
    /// Damage pulse delay in seconds before triggering (used by damagePulse accessory, default 1.0)
    var fourBallPulseDelay: TimeInterval = 1.0
    
    /// Maximum number of times damage pulse can trigger (used by damagePulse accessory, default 2)
    var fourBallMaxTriggers: Int = 2
    
    // NOTE: Despite the name, these control ALL explosion accessories (not just 11-balls)
    
    /// Explosion radius in blocks (used by explodeOnContact and explodeOnDestroy accessories, default 10.0)
    var elevenBallExplosionRadius: CGFloat = 10.0
    
    /// Maximum number of times a ball can explode before permanent destruction (used by explodeOnContact, default 1)
    var elevenBallMaxExplosions: Int = 1
}
```

**Benefits:**
- ✅ No breaking changes
- ✅ Comments clarify actual usage
- ✅ Saved settings preserved

**Drawbacks:**
- ❌ Still confusing property names
- ❌ Code doesn't reflect architectural reality

---

## Migration Path (If We Want to Fix This Properly)

### Step 1: Add New Properties with Correct Names

```swift
struct Config {
    // NEW: Properly named accessory settings
    var pulseDamageRadius: CGFloat { fourBallDamageRadius }
    var pulseDamageDelay: TimeInterval { fourBallPulseDelay }
    var pulseDamageMaxTriggers: Int { fourBallMaxTriggers }
    var explosionRadius: CGFloat { elevenBallExplosionRadius }
    var explosionMaxUses: Int { elevenBallMaxExplosions }
    
    // OLD: Deprecated but kept for UserDefaults compatibility
    @available(*, deprecated, message: "Use pulseDamageRadius instead")
    var fourBallDamageRadius: CGFloat = 18.0
    
    @available(*, deprecated, message: "Use pulseDamageDelay instead")
    var fourBallPulseDelay: TimeInterval = 1.0
    
    // ... etc
}
```

### Step 2: Update UserDefaults Keys

```swift
// Add migration logic in PhysicsAdjusterUI
private enum SettingsKey {
    // New keys (preferred)
    static let pulseDamageRadius = "spacepool.pulseDamageRadius"
    static let explosionRadius = "spacepool.explosionRadius"
    
    // Old keys (for migration)
    static let fourBallDamageRadius_LEGACY = "spacepool.fourBallDamageRadius"
    static let elevenBallExplosionRadius_LEGACY = "spacepool.elevenBallExplosionRadius"
}

func migrateOldSettings() {
    let defaults = UserDefaults.standard
    
    // Migrate old "fourBall" settings to new "pulse" settings
    if let oldRadius = defaults.object(forKey: SettingsKey.fourBallDamageRadius_LEGACY) {
        if defaults.object(forKey: SettingsKey.pulseDamageRadius) == nil {
            defaults.set(oldRadius, forKey: SettingsKey.pulseDamageRadius)
        }
    }
    
    // ... migrate other settings
}
```

### Step 3: Update Code to Use New Properties

```swift
// PulseAccessory.swift
let radiusInBlocks = damageSystem.config.pulseDamageRadius  // New name!
let pulseDelay = damageSystem.config.pulseDamageDelay       // New name!
let maxTriggers = damageSystem.config.pulseDamageMaxTriggers // New name!

// BallDamageSystem.swift
let explosionRadius: CGFloat = config.explosionRadius * blockSize  // New name!
```

### Step 4: Update UI Labels to Match New Names

```swift
// PhysicsAdjusterUI.swift
label.text = "Pulse Damage Radius"     // Already done!
label.text = "Pulse Max Uses"          // Already done!
label.text = "Explosion Radius"        // Already done!
```

**Timeline:**
1. Version X.0: Add new properties, keep old ones working
2. Version X.1: Migrate user settings from old keys to new keys
3. Version X.2+: Remove old properties entirely

---

## Recommendation

### For Now: Add Clarifying Comments

Update the comments in `BallDamageSystem.Config` to clarify that these properties control **accessories**, not specific ball types.

```swift
/// Damage pulse radius in blocks - controls damagePulse accessory (default 18.0)
/// NOTE: Despite the property name, this applies to any ball with damagePulse accessory
var fourBallDamageRadius: CGFloat = 18.0
```

### For Future: Proper Renaming with Migration

When time allows, implement the full migration path to rename properties to match their actual purpose (controlling accessories, not ball types).

---

## Technical Notes

### Why This Happened

The config properties were created when abilities were ball-specific:
- "4-ball has pulse ability" → `fourBallDamageRadius`
- "11-ball explodes" → `elevenBallExplosionRadius`

Later, abilities were converted to accessories:
- 4-ball → gets `damagePulse` accessory
- 11-ball → gets `explodeOnDestroy` accessory

But the config properties were never renamed because:
1. UserDefaults backward compatibility concerns
2. The settings still work correctly (just confusing names)
3. Initially only those specific balls had those accessories

---

## Current State (After Slider Fix)

✅ **What Works:**
- Sliders update config correctly
- Accessories read from config correctly
- Settings persist correctly
- Gameplay works as expected

❌ **What's Confusing:**
- Property names suggest ball-specific behavior
- Actually controls accessories (ball-agnostic)
- Code reads `config.fourBallDamageRadius` for pulse accessory
- Code reads `config.elevenBallExplosionRadius` for ALL explosions

**Bottom Line:** It works, but the naming is a legacy artifact from before the accessory system.
