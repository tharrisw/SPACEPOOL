# Config Property Renaming Complete

**Date:** January 22, 2026  
**Change:** Renamed ball-specific config properties to accessory-specific names  
**Migration:** Automatic migration from old UserDefaults keys to new ones

---

## What Changed

### Old Names (Ball-Specific)
```swift
// BallDamageSystem.Config
var fourBallDamageRadius: CGFloat = 18.0
var fourBallPulseDelay: TimeInterval = 1.0
var fourBallMaxTriggers: Int = 2
var elevenBallExplosionRadius: CGFloat = 10.0
var elevenBallMaxExplosions: Int = 1
```

### New Names (Accessory-Specific)
```swift
// BallDamageSystem.Config
var pulseDamageRadius: CGFloat = 18.0
var pulseDamageDelay: TimeInterval = 1.0
var pulseDamageMaxTriggers: Int = 2
var explosionRadius: CGFloat = 10.0
var explosionMaxUses: Int = 1
```

---

## Why This Matters

**Before:** Config properties were named after specific ball types (`fourBall`, `elevenBall`), even though they controlled accessories that could be attached to ANY ball.

**After:** Config properties are now named after the accessories they control (`pulseDamage`, `explosion`), making it clear these settings are ball-agnostic.

### Example Scenario

**If you attach `damagePulse` to a 7-ball:**

**Before (Confusing):**
```swift
// 7-ball with damagePulse accessory
let radius = damageSystem.config.fourBallDamageRadius  // 🤔 Why "fourBall" for a 7-ball?
```

**After (Clear):**
```swift
// 7-ball with damagePulse accessory
let radius = damageSystem.config.pulseDamageRadius  // ✅ Makes sense! It's pulse damage.
```

---

## Automatic Migration

When the app loads, old settings are automatically migrated to new keys:

```swift
private func migrateOldSettings() {
    let defaults = UserDefaults.standard
    
    // Migrate fourBallDamageRadius → pulseDamageRadius
    if let oldValue = defaults.object(forKey: "spacepool.fourBallDamageRadius") as? Double {
        if defaults.object(forKey: "spacepool.pulseDamageRadius") == nil {
            defaults.set(oldValue, forKey: "spacepool.pulseDamageRadius")
        }
    }
    
    // ... migrate other settings
}
```

**User Impact:** Zero! Settings are preserved automatically.

---

## Files Modified

### BallDamageSystem.swift
- ✅ Renamed `fourBallDamageRadius` → `pulseDamageRadius`
- ✅ Renamed `fourBallPulseDelay` → `pulseDamageDelay`
- ✅ Renamed `fourBallMaxTriggers` → `pulseDamageMaxTriggers`
- ✅ Renamed `elevenBallExplosionRadius` → `explosionRadius`
- ✅ Renamed `elevenBallMaxExplosions` → `explosionMaxUses`
- ✅ Updated all references to use new names

### BallAccessory.swift (PulseAccessory)
- ✅ Updated `triggerPulse()` to read `config.pulseDamageDelay`
- ✅ Updated `triggerPulse()` to read `config.pulseDamageMaxTriggers`
- ✅ Updated `unleashPulse()` to read `config.pulseDamageRadius`

### PhysicsAdjusterUI.swift
- ✅ Added new UserDefaults keys:
  - `pulseDamageRadius`
  - `pulseDamageMaxTriggers`
  - `explosionRadius`
  - `explosionMaxUses`
- ✅ Added legacy keys for migration:
  - `fourBallDamageRadius_LEGACY`
  - `fourBallMaxTriggers_LEGACY`
  - `elevenBallExplosionRadius_LEGACY`
  - `elevenBallMaxExplosions_LEGACY`
- ✅ Added `migrateOldSettings()` method
- ✅ Updated `applyLoadedSettings()` to use new property names
- ✅ Updated `resetSettings()` to remove both old and new keys
- ✅ Updated all slider methods to use new property names

---

## Property Mapping

| Old Property Name | New Property Name | Controls |
|------------------|-------------------|----------|
| `fourBallDamageRadius` | `pulseDamageRadius` | damagePulse accessory radius |
| `fourBallPulseDelay` | `pulseDamageDelay` | damagePulse accessory charge time |
| `fourBallMaxTriggers` | `pulseDamageMaxTriggers` | damagePulse accessory max uses |
| `elevenBallExplosionRadius` | `explosionRadius` | All explosion accessories radius |
| `elevenBallMaxExplosions` | `explosionMaxUses` | explodeOnContact regeneration limit |

---

## UserDefaults Keys

### New Keys (Active)
```swift
"spacepool.pulseDamageRadius"
"spacepool.pulseDamageMaxTriggers"
"spacepool.explosionRadius"
"spacepool.explosionMaxUses"
```

### Legacy Keys (For Migration)
```swift
"spacepool.fourBallDamageRadius"
"spacepool.fourBallMaxTriggers"
"spacepool.elevenBallExplosionRadius"
"spacepool.elevenBallMaxExplosions"
```

**Migration Flow:**
1. App loads → calls `migrateOldSettings()`
2. Checks if old keys exist
3. If old key exists and new key doesn't, copies value to new key
4. From then on, only new keys are used
5. Old keys remain for backward compatibility (not deleted)

---

## Testing Checklist

After renaming, verify:

- [ ] App loads without errors
- [ ] Settings overlay opens correctly
- [ ] Sliders show correct current values
- [ ] Adjusting sliders updates config correctly
- [ ] **Settings persist after app restart** (migration test)
- [ ] Damage pulse radius works correctly
- [ ] Damage pulse max uses works correctly
- [ ] Explosion radius works correctly
- [ ] Explosion max uses works correctly
- [ ] Old saved settings are migrated automatically

---

## Backward Compatibility

✅ **Fully backward compatible!**

- Old UserDefaults keys are automatically migrated to new keys
- Users won't lose their saved settings
- Migration happens silently on first launch after update
- Old keys are preserved (not deleted) for safety

---

## Benefits of Renaming

### 1. Clarity
Property names now match what they actually control (accessories, not balls)

### 2. Extensibility
If we attach damagePulse to other ball types in the future, the config name makes sense

### 3. Consistency
All accessory settings use descriptive names based on the accessory type

### 4. Maintainability
Developers immediately understand what each property controls

---

## Example Usage

### Before Renaming
```swift
// Confusing: Why "fourBall" when it could be on any ball?
let radius = damageSystem.config.fourBallDamageRadius
let maxTriggers = damageSystem.config.fourBallMaxTriggers
let explosionRadius = damageSystem.config.elevenBallExplosionRadius
```

### After Renaming
```swift
// Clear: These control the accessories, not specific balls
let radius = damageSystem.config.pulseDamageRadius
let maxTriggers = damageSystem.config.pulseDamageMaxTriggers
let explosionRadius = damageSystem.config.explosionRadius
```

---

## Migration Log Example

On first launch after update, the console will show:

```
✅ Migrated fourBallDamageRadius → pulseDamageRadius
✅ Migrated fourBallMaxTriggers → pulseDamageMaxTriggers
✅ Migrated elevenBallExplosionRadius → explosionRadius
✅ Migrated elevenBallMaxExplosions → explosionMaxUses
```

This confirms that user settings were preserved.

---

## Summary

The config properties have been successfully renamed from ball-specific names to accessory-specific names. This makes the code more accurate, maintainable, and extensible. User settings are automatically migrated, so there's no impact on existing players.

**Key Takeaway:** Config properties now correctly reflect that they control **accessories** (which can be on any ball), not specific ball types.
