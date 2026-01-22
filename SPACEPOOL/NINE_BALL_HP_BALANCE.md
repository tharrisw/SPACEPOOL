# 9-Ball HP Balance Change

## Summary
Modified 9-balls to have 50 HP instead of the default 100 HP to balance their powerful zapper ability.

## Changes Made

### BallDamageSystem.swift
- **Updated** `registerBall(_ ball: BlockBall, customHP: CGFloat?)` method
  - Added special case handling for ball-specific HP values
  - 9-balls now default to 50 HP (half of normal)
  - Other balls continue to use config.startingHP (default 100 HP)
  - Custom HP values still override the defaults if provided

## Implementation Details

```swift
// Determine max HP
let maxHP: CGFloat
if let custom = customHP {
    maxHP = custom
} else {
    // Special HP values for specific ball types
    switch ball.ballKind {
    case .nine:
        maxHP = 50  // 9-balls have 50 HP (zapper balls are more fragile)
    default:
        maxHP = config.startingHP  // Default 100 HP
    }
}
```

## Rationale

**Why 50 HP?**
- 9-balls have the **zapper accessory** that unleashes lightning bolts at all nearby balls
- The zapper deals 20 damage to each target in a 150-point radius
- Having full 100 HP made 9-balls too powerful as offensive balls
- With 50 HP, they become **glass cannons**:
  - Strong offensive capability (lightning strikes)
  - But more vulnerable to being destroyed themselves
  - Requires more strategic use (protect them from direct hits)

**Balance Impact:**
- **Cue ball hit**: 10 damage → 5 hits to destroy (down from 10 hits)
- **Ball-to-ball collision**: 1 damage → 50 hits to destroy (down from 100 hits)
- **11-ball explosion**: 80 damage → Instantly destroyed (was 80/100 HP remaining)
- **Burning damage**: 1 HP per 0.5s → Destroyed in 25 seconds (down from 50 seconds)

## Game Design Benefits

1. **Risk vs. Reward**: Players must decide whether to use 9-balls aggressively or protect them
2. **Target Priority**: Opponents have incentive to target 9-balls first
3. **Strategic Depth**: Positioning becomes more important for fragile zapper balls
4. **Power Balance**: Prevents 9-balls from being both powerful AND durable
5. **Distinct Identity**: 9-balls now feel unique compared to other numbered balls

## Testing Notes

- 9-balls should show "50 HP" in debug logs when registered
- Health bar should reflect 50/50 HP at full health
- 5 cue ball hits should destroy a 9-ball (instead of 10)
- 11-ball explosions should one-shot 9-balls (80 damage > 50 HP)

## Future Considerations

This HP system can be extended for other ball types:
- Could give 4-balls extra HP (they're immovable objects)
- Could make 11-balls more fragile (they explode on contact)
- Could make 6-balls (healers) tankier
- Could adjust based on playtesting feedback

The system is designed to be easily extensible by adding more cases to the switch statement.
