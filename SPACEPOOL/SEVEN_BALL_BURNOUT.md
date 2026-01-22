# 7-Ball Burnout Feature

## Overview
The 7-ball now burns itself out when sitting still for too long, and automatically reignites when it starts moving again.

## Behavior

### Initial Ignition
- 7-ball catches fire on **first movement** (speed > 1.0)
- Gets permanent `burning` accessory
- Immune to burning damage (can't hurt itself)
- Can spread fire to other balls on contact

### Burnout When Still
- If the 7-ball sits still (speed < 3.0) for **3 seconds**
- Fire automatically extinguishes
- `burning` accessory is removed
- Ball stops spreading fire
- Visual flames disappear

### Reignition on Movement
- As soon as the 7-ball moves again (speed >= 3.0)
- Fire automatically reignites
- `burning` accessory is reattached
- Visual flames return
- Can spread fire again

## Technical Details

### New State Variables in `BlockBall.swift`

```swift
private var hasCaughtFire = false      // Track if 7-ball has caught fire at least once
private var isBurning = false          // Track if fire is currently active
private var burnoutTimer: TimeInterval = 0.0  // Time spent at rest
private let burnoutDelay: TimeInterval = 3.0  // Seconds at rest before fire goes out
private let burningRestThreshold: CGFloat = 3.0  // Speed threshold to consider ball at rest
```

### Logic Flow

```
7-ball spawned
    ↓
First movement (speed > 1.0)
    ↓
hasCaughtFire = true, isBurning = true
    ↓
Fire attached, spreading enabled
    ↓
Ball stops moving (speed < 3.0)
    ↓
burnoutTimer starts incrementing
    ↓
burnoutTimer reaches 3.0 seconds
    ↓
isBurning = false, burning accessory removed
    ↓
Fire extinguished, no spreading
    ↓
Ball moves again (speed >= 3.0)
    ↓
isBurning = true, burning accessory attached
    ↓
Fire reignited, spreading enabled
```

## Implementation Code

### Update Method Logic
```swift
// Ignite 7-ball on first movement
if kind == .seven && !hasCaughtFire && ls > 1.0 {
    hasCaughtFire = true
    isBurning = true
    _ = attachAccessory("burning")
}

// Handle 7-ball burnout when at rest
if kind == .seven && hasCaughtFire {
    // Check if ball is at rest
    if ls < burningRestThreshold && angSpeed < restAngularSpeedThreshold {
        // Ball is at rest, increment burnout timer
        burnoutTimer += deltaTime
        
        // Check if fire should burn out
        if isBurning && burnoutTimer >= burnoutDelay {
            isBurning = false
            _ = removeAccessory("burning")
            burnoutTimer = 0.0
        }
    } else {
        // Ball is moving
        burnoutTimer = 0.0  // Reset burnout timer
        
        // Reignite if not burning
        if !isBurning {
            isBurning = true
            _ = attachAccessory("burning")
        }
    }
}
```

## Gameplay Examples

### Example 1: Ball Stops in the Open
1. 7-ball is moving and on fire (spreading)
2. Ball slows down and stops (speed < 3.0)
3. After 3 seconds: fire goes out, flames disappear
4. Player shoots ball with cue ball
5. 7-ball starts moving: fire reignites immediately
6. Ball is spreading fire again

### Example 2: Ball Sitting Near Other Balls
1. 7-ball stops near cue ball (fire still active)
2. 2 seconds pass: fire still burning
3. Cue ball touches 7-ball: gets tempBurning
4. 1 more second passes (3 total): 7-ball fire goes out
5. Cue ball still has tempBurning (independent fire)
6. 7-ball rolls slightly: fire reignites
7. Now both balls are on fire

### Example 3: Burnout Timer Reset
1. 7-ball stops (timer starts: 0.0s)
2. 2.5 seconds pass (timer: 2.5s)
3. Ball gets bumped slightly (speed > 3.0)
4. Timer resets to 0.0s
5. Ball stops again
6. Must wait full 3 seconds again for burnout

### Example 4: Multiple Burnout Cycles
1. 7-ball catches fire on first movement
2. Stops for 3 seconds → fire goes out
3. Moves → fire reignites
4. Stops for 3 seconds → fire goes out
5. Moves → fire reignites
6. Can repeat indefinitely

## Balance Considerations

- **Burnout Delay**: 3 seconds (not too fast, not too slow)
- **Rest Threshold**: 3.0 speed units (same as gravity ball)
- **Reignition**: Instant (as soon as ball moves)
- **Immunity**: 7-ball never takes burning damage
- **Spreading**: Only spreads when fire is active

## Strategic Implications

### Offensive Strategy
- Keep 7-ball moving to maintain fire
- Use 7-ball to "tag" enemy balls
- Multiple quick hits more effective than one long contact

### Defensive Strategy
- Try to stop 7-ball in corners/pockets
- Wait for burnout before approaching
- Time attacks during burnout windows

### Risk Management
- Burning 7-ball is more dangerous (constant threat)
- Extinguished 7-ball is safer to approach
- But watch out - one bump reignites it!

## Debug Output

The system provides console logging:

```
🔥 7-ball caught fire on first movement!
🔥 7-ball fire burned out after sitting still for 3.0 seconds
🔥 7-ball reignited after moving!
```

## Visual Feedback

- **Burning State**: Full flame animation engulfing the ball
- **Extinguished State**: No flames, normal ball appearance
- **Reignition**: Flames instantly reappear when moving
- **Same flames as tempBurning**: Consistent visual language

## Performance Notes

- Burnout timer only runs when 7-ball is at rest
- Timer resets immediately when ball moves (no accumulation)
- No performance impact when 7-ball is moving
- Accessory attachment/removal is efficient (reuses existing system)

## Future Enhancements (Not Implemented)

Possible additions:
- Smoke puff effect when fire goes out
- Ember particles during burnout countdown
- Fire "sputtering" before complete burnout
- Sound effects for ignition/extinguishing
- Different burnout times based on ball HP
- Burnout resistance stat
