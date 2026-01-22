# Settings Overlay Accessory Update

**Date:** January 22, 2026  
**Change:** Updated settings overlay sliders to reflect that ball special abilities are now accessories, and fixed the underlying code to actually make them work

---

## Summary

The settings overlay previously referred to ball-specific abilities (like "4-Ball Pulse Radius" and "11-Ball Max Explosions"). Now that these abilities have been converted to accessories, the UI labels and comments have been updated to reflect this architectural change.

**More importantly:** The PulseAccessory was using hardcoded static properties instead of reading from the config, so the sliders weren't actually working! This has been fixed - see `ACCESSORY_SLIDER_FIX.md` for technical details.

---

## Changes Made

### 1. Updated Slider Labels

#### 4-Ball Damage Pulse Accessory
**Before:**
```swift
label.text = "4-Ball Pulse Radius"
label.text = "4-Ball Max Triggers"
```

**After:**
```swift
label.text = "Damage Pulse Radius"
label.text = "Damage Pulse Max Uses"
```

**Reasoning:** The "damage pulse" is now an accessory that can theoretically be attached to any ball, not just the 4-ball. The settings control the accessory behavior, not the ball itself.

---

#### 11-Ball Explosion Accessory
The labels remain the same:
- "Explosion Radius"
- "Max Explosions"

These were already generic enough to work with the accessory system.

---

### 2. Added Section Header

A new "ACCESSORY SETTINGS" header was added to the gameplay column to visually separate accessory-related settings from general gameplay settings:

```swift
// Accessory settings header
let accessoryHeader = SKLabelNode(fontNamed: "Courier-Bold")
accessoryHeader.text = "ACCESSORY SETTINGS"
accessoryHeader.fontSize = 11
accessoryHeader.fontColor = SKColor(white: 0.6, alpha: 1.0)
```

This makes it clear to users which settings affect accessories vs. general gameplay.

---

### 3. Updated UserDefaults Keys Comments

Added clarifying comments to the `SettingsKey` enum:

```swift
// Accessory settings (for damagePulse accessory on 4-ball)
static let fourBallDamageRadius = "spacepool.fourBallDamageRadius"
static let fourBallMaxTriggers = "spacepool.fourBallMaxTriggers"

// Accessory settings (for explodeOnDestroy accessory on 11-ball)
static let elevenBallExplosionRadius = "spacepool.elevenBallExplosionRadius"
static let elevenBallMaxExplosions = "spacepool.elevenBallMaxExplosions"
```

**Note:** The key names still reference "fourBall" and "elevenBall" for backward compatibility with saved settings, but the comments clarify they're accessory settings.

---

### 4. Updated Code Comments

In `applyLoadedSettings()`:

**Before:**
```swift
// Apply damage system settings
if defaults.object(forKey: SettingsKey.fourBallDamageRadius) != nil {
    // ...
}

// 4-Ball Max Triggers (default 2 if not set)
// ...
```

**After:**
```swift
// Apply accessory settings - damagePulse accessory (on 4-ball)
if defaults.object(forKey: SettingsKey.fourBallDamageRadius) != nil {
    // ...
}

// damagePulse Max Triggers (default 2 if not set)
// ...
```

Similar updates for 11-ball → explodeOnDestroy accessory.

---

### 5. Enhanced Print Statements

Added clarifying print statements when sliders are adjusted:

```swift
// 4-ball damage pulse
print("🎚️ Damage pulse radius set to \(String(format: "%.1f", newValue)) blocks")
print("🎚️ Damage pulse max uses set to \(clamped)×")

// 11-ball explosion
print("🎚️ Explosion radius set to \(String(format: "%.1f", newValue)) blocks")
print("🎚️ Explosion max uses set to \(clamped)×")
```

---

## Visual Changes in UI

### Settings Overlay Layout

```
┌─────────────────────────────────────────┐
│  Options                                │
│  [Ball Preview Sprites]                 │
│                                         │
│  GAMEPLAY          │  PHYSICS           │
│  ─────────         │  ───────           │
│  [Restart Button]  │                    │
│  Damage Mult       │  Friction          │
│  Max Shot Power    │  Linear Damping    │
│  3-Ball Mass       │  Restitution       │
│  Max Shot Dist     │  Base Ang Damping  │
│  Power Exponent    │  High Ang Damping  │
│                    │  ... etc           │
│  ACCESSORY SETTINGS│                    │
│  Damage Pulse Radius      ← Changed!   │
│  Damage Pulse Max Uses    ← Changed!   │
│  Explosion Radius                       │
│  Max Explosions                         │
│                                         │
│  [Reset Progress]                       │
│  [HP Bars Toggle]                       │
│  [Damage Numbers Toggle]                │
│  [Hats Toggle]                          │
└─────────────────────────────────────────┘
```

The new "ACCESSORY SETTINGS" header provides visual separation.

---

## Technical Implementation

### How Accessories Work

1. **damagePulse Accessory** (on 4-ball):
   - Attached via `attachAccessory("damagePulse")` in BlockBall
   - Creates purple shockwave when damaged
   - Damages nearby balls within `fourBallDamageRadius`
   - Limited by `fourBallMaxTriggers` (default 2)

2. **explodeOnDestroy Accessory** (on 11-ball):
   - Attached via `attachAccessory("explodeOnDestroy")` in BlockBall
   - Creates massive explosion when HP reaches 0
   - Explosion radius controlled by `elevenBallExplosionRadius`
   - Can regenerate and explode up to `elevenBallMaxExplosions` times

---

### Settings Flow

```
User drags slider
    ↓
PhysicsAdjusterUI updates value
    ↓
Saves to UserDefaults
    ↓
Updates scene.damageSystem?.config
    ↓
Accessory reads from config when triggered
```

**Important:** The settings are stored in the damage system config, which accessories query when they activate. This allows the same accessory to be used on multiple balls with consistent behavior.

---

## Backward Compatibility

### UserDefaults Keys Unchanged

The actual UserDefaults keys were **NOT** changed:
- `spacepool.fourBallDamageRadius` (still references "fourBall")
- `spacepool.fourBallMaxTriggers`
- `spacepool.elevenBallExplosionRadius`
- `spacepool.elevenBallMaxExplosions`

**Reason:** Preserves existing saved settings across app updates.

### Only UI Text Changed

Users will see the new labels ("Damage Pulse Radius" instead of "4-Ball Pulse Radius"), but their saved settings will continue to work normally.

---

## Future Extensibility

### Why This Matters

Now that abilities are accessories, it's theoretically possible to:
- Attach damagePulse to other ball types
- Attach explodeOnDestroy to other ball types
- Create new accessories with similar effects
- Mix and match accessories on balls

The settings UI now reflects this flexibility by referring to the **accessory** rather than the **ball**.

---

## Testing Checklist

After these changes, verify:

- [ ] Settings overlay opens correctly
- [ ] "ACCESSORY SETTINGS" header appears
- [ ] Damage Pulse Radius slider shows correct label
- [ ] Damage Pulse Max Uses slider shows correct label
- [ ] Sliders work correctly and save settings
- [ ] Settings persist across app restarts
- [ ] 4-ball damage pulse respects radius and max uses settings
- [ ] 11-ball explosion respects radius and max explosions settings
- [ ] Print statements show correct messages when adjusting sliders

---

## Files Modified

- `PhysicsAdjusterUI.swift` - Updated UI labels, comments, and organization

---

## Related Documentation

See also:
- `11BALL_ACCESSORY_CHANGE.md` - Details the switch from explodeOnContact to explodeOnDestroy
- `BallAccessory.swift` - Accessory system implementation
- `BallDamageSystem.swift` - Damage system that accessories interact with

---

## Summary

This update brings the settings overlay UI in line with the architectural shift to accessories. The labels now accurately describe what's being controlled (accessories) rather than implying ball-specific abilities. This makes the code more maintainable and the UI more accurate for future extensibility.
