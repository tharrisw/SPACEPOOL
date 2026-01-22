# Accessory Slider Fix

**Date:** January 22, 2026  
**Issue:** Settings sliders appeared to control accessories but weren't actually working
**Fix:** Updated accessories to read from BallDamageSystem config at runtime instead of using static properties

---

## The Problem

The settings overlay sliders were updating `BallDamageSystem.config` values:
- `config.fourBallDamageRadius`
- `config.fourBallMaxTriggers`
- `config.elevenBallExplosionRadius`
- `config.elevenBallMaxExplosions`

However, the `PulseAccessory` class was using its own **static properties** that were never synced with the config:
```swift
// OLD - These were never updated by sliders!
static var pulseRadius: CGFloat = 90.0
static var pulseDelay: TimeInterval = 1.0
static var maxTriggers: Int = 2
```

This meant:
- ✅ Sliders saved values to UserDefaults correctly
- ✅ Config was loaded on startup correctly
- ❌ **PulseAccessory ignored the config and used its own hardcoded static values**
- ❌ **Changing sliders had no effect on actual gameplay**

---

## The Solution

### 1. Removed Static Properties from PulseAccessory

**Before:**
```swift
final class PulseAccessory: BallAccessoryProtocol {
    // Configuration
    static var pulseRadius: CGFloat = 90.0  // 18 blocks * 5 points per block
    static var pulseDelay: TimeInterval = 1.0
    static var maxTriggers: Int = 2
    
    private var triggerCount: Int = 0
}
```

**After:**
```swift
final class PulseAccessory: BallAccessoryProtocol {
    // Configuration is read from BallDamageSystem.config at runtime
    private var triggerCount: Int = 0
}
```

---

### 2. Updated triggerPulse to Read Config

**Before:**
```swift
func triggerPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
    print("💜 Pulse triggered! Charging for \(PulseAccessory.pulseDelay)s...")
    
    triggerCount += 1
    let shouldDestroyAfter = (triggerCount >= PulseAccessory.maxTriggers)
    
    startChargingAnimation(ball: ball)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + PulseAccessory.pulseDelay) {
        // ...
    }
}
```

**After:**
```swift
func triggerPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
    // Read configuration from damage system at runtime
    let pulseDelay = damageSystem.config.fourBallPulseDelay
    let maxTriggers = damageSystem.config.fourBallMaxTriggers
    
    print("💜 Pulse triggered! Charging for \(pulseDelay)s...")
    
    triggerCount += 1
    let shouldDestroyAfter = (triggerCount >= maxTriggers)
    
    startChargingAnimation(ball: ball, pulseDelay: pulseDelay)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + pulseDelay) {
        // ...
    }
}
```

---

### 3. Updated startChargingAnimation

**Before:**
```swift
private func startChargingAnimation(ball: BlockBall) {
    let pulseCount = Int(PulseAccessory.pulseDelay / 0.6)
    let colorShiftDuration = PulseAccessory.pulseDelay / 4
    // ...
}
```

**After:**
```swift
private func startChargingAnimation(ball: BlockBall, pulseDelay: TimeInterval) {
    let pulseCount = Int(pulseDelay / 0.6)
    let colorShiftDuration = pulseDelay / 4
    // ...
}
```

Now accepts `pulseDelay` as a parameter instead of reading from static property.

---

### 4. Updated unleashPulse to Read Radius

**Before:**
```swift
private func unleashPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
    let blockSize: CGFloat = 5.0
    let radius = PulseAccessory.pulseRadius  // Static property
    let center = ball.position
    
    print("💜💜💜 PULSE UNLEASHED from \(ball.ballKind) ball!")
}
```

**After:**
```swift
private func unleashPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
    // Read configuration from damage system
    let radiusInBlocks = damageSystem.config.fourBallDamageRadius
    let blockSize: CGFloat = 5.0
    let radius = radiusInBlocks * blockSize  // Convert blocks to points
    let center = ball.position
    
    print("💜💜💜 PULSE UNLEASHED from \(ball.ballKind) ball! Radius: \(radiusInBlocks) blocks (\(radius) pts)")
}
```

Now reads radius from config and converts blocks to points dynamically.

---

## What Already Worked

### Explosion Accessories (No Changes Needed)

The explosion system was **already correct**:

```swift
private func createMassiveExplosion(at position: CGPoint, ball: BlockBall) {
    let explosionRadius: CGFloat = config.elevenBallExplosionRadius * blockSize // ✅ Already using config!
    // ...
}
```

The explosion max count was also correct:
```swift
if health.explodeOnContactCount >= config.elevenBallMaxExplosions {
    // Destroy completely
}
```

**So explosions always respected slider settings!** Only the pulse accessory was broken.

---

## Data Flow (Now Fixed)

### Before Fix
```
User adjusts slider
    ↓
PhysicsAdjusterUI updates config
    ↓
Config saved to UserDefaults
    ↓
[CONFIG IGNORED BY PULSE ACCESSORY]
    ↓
PulseAccessory uses hardcoded static values
    ↓
❌ Slider changes have no effect
```

### After Fix
```
User adjusts slider
    ↓
PhysicsAdjusterUI updates config
    ↓
Config saved to UserDefaults
    ↓
PulseAccessory reads config at runtime
    ↓
✅ Slider changes take effect immediately
```

---

## Configuration Values

All accessory settings are stored in `BallDamageSystem.Config`:

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

These values are:
1. ✅ Loaded from UserDefaults on app launch
2. ✅ Updated when sliders move
3. ✅ Saved to UserDefaults for persistence
4. ✅ **Now actually used by accessories at runtime**

---

## Testing Checklist

After this fix, verify:

- [ ] Open settings overlay
- [ ] Adjust "Damage Pulse Radius" slider
- [ ] Hit a 4-ball with the cue ball
- [ ] **Verify pulse radius matches slider setting** (you should see the purple ring match the size)
- [ ] Adjust "Damage Pulse Max Uses" slider to 5
- [ ] Hit 4-ball 5 times
- [ ] **Verify it pulses 5 times before breaking** (not just 2)
- [ ] Adjust "Explosion Radius" slider
- [ ] Destroy an 11-ball (hit it until HP reaches 0)
- [ ] **Verify explosion radius matches slider setting**
- [ ] Adjust "Max Explosions" slider to 3
- [ ] Destroy an 11-ball that can regenerate
- [ ] **Verify it can explode 3 times before dying completely**

---

## Files Modified

- `BallAccessory.swift` - Updated PulseAccessory to read config at runtime
- `PhysicsAdjusterUI.swift` - Updated labels and comments (already done in previous commit)

---

## Why This Bug Existed

The `PulseAccessory` was originally designed as a standalone class with its own configuration. When the settings system was added later, the config was created in `BallDamageSystem` but the connection to `PulseAccessory` was never made. The explosion accessories were added later and correctly used the config from the start, so they worked fine.

---

## Design Pattern Lesson

### ❌ Don't Do This
```swift
class MyAccessory {
    static var setting: CGFloat = 10.0  // Hardcoded value
    
    func doThing() {
        let value = MyAccessory.setting  // Using static property
    }
}
```

### ✅ Do This Instead
```swift
class MyAccessory {
    func doThing(config: Config) {
        let value = config.setting  // Read from config at runtime
    }
}
```

**Why:** Static properties are fixed at compile time. Runtime configuration should come from a config object that can be modified by UI/settings.

---

## Summary

The sliders were technically "working" (they saved values correctly), but the PulseAccessory was ignoring those values and using hardcoded static properties instead. This fix makes the accessory read from the config at runtime, so slider changes now actually affect gameplay.

**Impact:**
- ✅ Damage Pulse Radius slider now works
- ✅ Damage Pulse Max Uses slider now works
- ✅ Explosion sliders continue to work (already working)
- ✅ All accessory settings now properly configurable from UI
