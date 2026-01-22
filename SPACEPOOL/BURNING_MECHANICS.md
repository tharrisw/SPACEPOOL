# Burning Mechanics Implementation

## Overview
Implemented a fire spreading mechanic where burning accessories can transfer between balls on collision, dealing damage over time.

## Features Implemented

### 1. **Temp Burning Accessory** (`TempBurningAccessory`)
- New accessory type that spreads on contact
- Deals 1 HP damage every 0.5 seconds
- Wears off automatically after dealing 20 total damage
- Uses the same flame animation as regular burning
- Visual feedback shows fire engulfing the ball

### 2. **Fire Spreading Mechanics**
- When a ball with `burning` or `tempBurning` touches another ball, the other ball gets `tempBurning`
- Spreads both ways: if either ball is burning, it can infect the other
- Regular burning (7-ball only) acts as a permanent source of infection
- Temp burning can chain-spread: if ball A gets temp burning from ball B, and ball A touches ball C, then ball C also gets temp burning

### 3. **Special Interactions**

#### 7-Ball (Burning Ball)
- Gets permanent `burning` accessory on first movement
- **Immune to burning damage** (doesn't take damage from its own fire)
- Can still spread burning to other balls on contact
- Acts as a permanent fire source

#### 11-Ball (Striped Ball)
- **Explodes immediately** when it gets `tempBurning`
- Takes 9999 damage instantly (instant death)
- Cannot survive with burning - it's a one-hit kill

#### All Other Balls
- Take 1 HP damage every 0.5 seconds from temp burning
- Fire wears off after dealing 20 total damage
- Can spread fire while burning
- Can die from reaching 0 HP from burning damage

### 4. **Damage Tracking**
- Temp burning tracks total damage dealt (20 HP max)
- Automatically removes itself after reaching the damage cap
- If a ball reaches 0 HP from burning, it breaks using the crumble effect

## Technical Details

### Code Changes

#### `BallAccessory.swift`
1. **Modified `BurningAccessory`**:
   - Added `isTemporary` parameter to constructor
   - Made 7-balls immune to burning damage

2. **New `TempBurningAccessory` class**:
   - Inherits all flame animation logic
   - Tracks `totalDamageDealt` (0-20 HP)
   - Removes itself when damage cap reached
   - Special 11-ball explosion check in `onAttach`

3. **Updated `BallAccessoryManager`**:
   - Registered `TempBurningAccessory` in `registerDefaultAccessories()`
   - Added `tempBurning` case in `attachAccessory()`
   - New helper method: `hasBurning(ball:)` checks for any burning type

#### `StarfieldScene.swift`
1. **Modified `didBegin(_:)` collision handler**:
   - Added `handleBurningSpread()` call before damage processing
   - Checks both balls for burning before handling collision damage

2. **New `handleBurningSpread(between:and:)` method**:
   - Checks if either ball has burning or tempBurning
   - Spreads tempBurning to the non-burning ball
   - Bidirectional spreading (both ways)

## Behavior Examples

### Example 1: 7-Ball Spreading Fire
1. 7-ball catches fire on first movement (permanent burning)
2. 7-ball collides with cue ball
3. Cue ball gets tempBurning accessory
4. Cue ball starts taking 1 damage every 0.5 seconds
5. After 20 damage (10 seconds), fire wears off from cue ball
6. 7-ball still has permanent burning

### Example 2: Chain Spreading
1. 7-ball (burning) hits 2-ball → 2-ball gets tempBurning
2. 2-ball (tempBurning) hits 3-ball → 3-ball gets tempBurning
3. 3-ball (tempBurning) hits 8-ball → 8-ball gets tempBurning
4. All three balls (2, 3, 8) are now on fire independently
5. Each will wear off after dealing 20 damage to that ball

### Example 3: 11-Ball Instant Death
1. 7-ball (burning) hits 11-ball
2. 11-ball gets tempBurning
3. `TempBurningAccessory.onAttach()` detects 11-ball
4. Immediately deals 9999 damage to 11-ball
5. 11-ball explodes (crumble animation)
6. Player gets +1 score

### Example 4: Ball Dies from Burning
1. Cue ball has 5 HP remaining
2. Gets tempBurning from 7-ball collision
3. Takes 1 damage after 0.5 seconds (4 HP left)
4. Takes 1 damage after 1.0 seconds (3 HP left)
5. Takes 1 damage after 1.5 seconds (2 HP left)
6. Takes 1 damage after 2.0 seconds (1 HP left)
7. Takes 1 damage after 2.5 seconds (0 HP left)
8. Ball breaks with crumble animation
9. Total damage dealt: 5 HP (fire would wear off at 20 HP, but ball died first)

## Debug Output

The system provides detailed console logging:

```
🔥 Temp Burning accessory attached to cue ball (will wear off after 20 damage)
🔥 Burning spread from seven to cue!
🔥 Temp Burning damage: 1 HP to cue ball (total: 1/20)
🔥 Temp Burning damage: 1 HP to cue ball (total: 2/20)
...
🔥 Temp Burning damage: 1 HP to cue ball (total: 20/20)
🔥 Temp Burning wore off after dealing 20 damage!
💥 11-ball got temp burning - EXPLODING IMMEDIATELY!
```

## Balance Considerations

- **Damage Rate**: 1 HP per 0.5 seconds = 2 HP per second
- **Total Damage**: 20 HP over 10 seconds
- **Cue Ball HP**: 100 HP (can survive multiple burns)
- **11-Ball HP**: Doesn't matter (instant death)
- **7-Ball**: Immune (can't kill itself with fire)
- **Fire Spread**: Instant on contact (no delay)
- **Chain Spreading**: Unlimited (fire can spread infinitely)

## Visual Feedback

- Engulfing flame animation with 22+ flame sprites
- Yellow/orange/red gradient flames
- Flickering and bobbing animation
- Same visuals for both burning and tempBurning
- Fire completely surrounds the ball (front, back, sides, top, bottom)

## Future Enhancements (Not Implemented)

Possible additions:
- Fire immunity power-ups
- Fire extinguisher balls
- Fire damage multipliers
- Burning speed boost (faster fire spread)
- Visual distinction between regular and temp burning
- Fire trail effects when balls roll
- Smoke particles above flames
