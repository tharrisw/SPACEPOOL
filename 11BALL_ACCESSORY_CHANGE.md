# 11-Ball Accessory Change

**Date:** January 21, 2026  
**Change:** Swapped accessories on 11-ball  

---

## What Changed

### Before
```swift
// 11-ball had explodeOnContact accessory
if kind == .eleven {
    _ = attachAccessory("explodeOnContact")
}
```

**Behavior:** 11-ball explodes **instantly on ANY contact** with any other ball, regardless of collision force.

---

### After
```swift
// 11-ball now has explodeOnDestroy accessory
if kind == .eleven {
    _ = attachAccessory("explodeOnDestroy")
}
```

**Behavior:** 11-ball explodes **only when its HP reaches 0** (when destroyed through repeated collisions).

---

## Behavior Differences

### `explodeOnContact` (OLD - Removed)
- ✅ **Triggers:** Instantly on first contact with ANY ball
- ✅ **Bypasses:** Impulse threshold (even gentle touches trigger it)
- ✅ **Chain reactions:** Other 11-balls in explosion radius also instantly explode
- ✅ **Regeneration:** Can regenerate and explode multiple times (up to `elevenBallMaxExplosions`)
- ⚠️ **Risk:** Very dangerous - even gentle touches cause massive explosions

**Use case:** Ultra-volatile balls that explode at the slightest touch

---

### `explodeOnDestroy` (NEW - Added)
- ✅ **Triggers:** Only when HP reaches 0 (after accumulating damage)
- ✅ **Requires:** Multiple collisions or one very hard collision to destroy
- ✅ **Creates:** Massive explosion at death position (same explosion effect)
- ✅ **More strategic:** Players must decide whether it's worth destroying it
- ⚠️ **Risk:** Still dangerous when destroyed, but takes effort to destroy

**Use case:** Strategic targets that explode when defeated

---

## Gameplay Impact

### Old Behavior (explodeOnContact)
```
Cue ball touches 11-ball gently
  ↓
11-ball INSTANTLY EXPLODES
  ↓
Huge crater in felt
  ↓
Nearby balls take massive damage
  ↓
Chain reactions possible
```

**Problem:** Too volatile - even trying to avoid it could trigger explosion

---

### New Behavior (explodeOnDestroy)
```
Cue ball hits 11-ball hard (50 damage)
  ↓
11-ball takes damage (HP: 50/100)
  ↓
Cue ball hits 11-ball again (50 damage)
  ↓
11-ball HP reaches 0
  ↓
11-ball EXPLODES on destruction
  ↓
Huge crater in felt
  ↓
Nearby balls take massive damage
```

**Benefit:** More strategic - players can choose to destroy it or leave it alone

---

## Technical Details

### Both Accessories Create Same Explosion
Both use `createMassiveExplosion()` which:
- Creates large crater in felt (grid-based destruction)
- Spawns debris particles
- Deals massive damage to nearby balls
- Creates visual flash effect
- Same radius (~100 points)

**Only difference is WHEN the explosion triggers:**
- `explodeOnContact`: On first touch
- `explodeOnDestroy`: When HP depleted

---

### Code Location

**File:** `BlockBall.swift` (lines ~350-352)

**Accessory definitions:** `BallAccessory.swift`
- `ExplodeOnContactAccessory` (lines 933-963)
- `ExplodeOnDestroyAccessory` (lines 968-998)

**Damage handling:** `BallDamageSystem.swift`
- explodeOnContact: lines 439-595 (instant explosion on any damage)
- explodeOnDestroy: lines 607-634 (explosion only at death)

---

## Visual Differences

### None!
Both accessories are **completely invisible** - they're pure ability modifiers.

The 11-ball's **striped red appearance** is the visual indicator that it's dangerous, regardless of which explosion accessory it has.

---

## Recommended Testing

After this change, verify:

- [ ] 11-ball spawns correctly in levels
- [ ] 11-ball takes damage from collisions normally
- [ ] 11-ball **does NOT** explode on first contact
- [ ] 11-ball **DOES** explode when HP reaches 0
- [ ] Explosion creates crater in felt
- [ ] Explosion damages nearby balls
- [ ] Explosion has same visual effect as before

---

## Revert Instructions

If you want to revert to instant-explosion behavior:

```swift
// Change line ~351 in BlockBall.swift from:
_ = attachAccessory("explodeOnDestroy")

// Back to:
_ = attachAccessory("explodeOnContact")
```

---

## Summary

**Old:** Touch 11-ball → BOOM! 💥  
**New:** Destroy 11-ball → BOOM! 💥

The 11-ball is now more strategic and less "instant death" - players can approach it carefully without triggering accidental explosions, but destroying it still creates a massive explosion as a reward/punishment.
