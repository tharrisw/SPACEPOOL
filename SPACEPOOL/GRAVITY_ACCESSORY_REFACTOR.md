# Gravity Accessory Refactoring

## Summary
Moved the 1-ball's gravity ability from hardcoded BlockBall logic into a reusable `GravityAccessory` that can be attached to any ball.

## Changes Made

### 1. BallAccessory.swift
- **Added** `GravityAccessory` class that implements `BallAccessoryProtocol`
  - Manages gravity field activation/deactivation based on ball movement and rest state
  - Shows/hides visual gravity field indicator (pulsing yellow circle)
  - Applies gravitational pull to nearby balls within 150-point radius
  - Tracks whether ball has moved at least once before activating gravity
  - Uses same parameters as original implementation:
    - `gravityRadius: 150.0` (30 blocks × 5 points per block)
    - `gravityStrength: 0.15` (weak attraction force)
    - `gravityRestThreshold: 3.0` (speed threshold to consider ball at rest)

- **Updated** `BallAccessoryManager.registerDefaultAccessories()`
  - Added `GravityAccessory()` registration

- **Updated** `BallAccessoryManager.attachAccessory(id:to:)`
  - Added case for `"gravity"` to instantiate `GravityAccessory`

### 2. BlockBall.swift
- **Removed** gravity-specific properties:
  - `hasMovedOnce`
  - `isGravityActive`
  - `gravityRadius`
  - `gravityStrength`
  - `gravityRestThreshold`
  - `gravityFieldNode`

- **Removed** gravity methods:
  - `showGravityField()`
  - `hideGravityField()`
  - `applyGravityEffect()`

- **Removed** gravity update logic from `update(deltaTime:)` method:
  - Movement tracking for 1-ball
  - Gravity activation/deactivation checks
  - Gravity effect application

- **Removed** gravity field cleanup from `deinit`

- **Added** gravity accessory attachment in initializer:
  ```swift
  // Attach gravity accessory to 1-balls
  // (attracts nearby balls when at rest)
  if kind == .one {
      _ = attachAccessory("gravity")
  }
  ```

## Benefits

1. **Separation of Concerns**: Gravity logic is now self-contained in the accessory system
2. **Reusability**: Any ball can now have gravity by attaching the accessory
3. **Consistency**: Gravity follows the same pattern as other abilities (flying, burning, zapping, etc.)
4. **Maintainability**: Easier to modify gravity behavior without touching core ball logic
5. **Extensibility**: Can easily create variations (stronger/weaker gravity, different radius, etc.)

## Behavior Preserved

The gravity accessory maintains identical behavior to the original implementation:
- Gravity activates only after the ball has moved at least once
- Gravity field appears when ball comes to rest (speed < 3.0)
- Visual indicator is a pulsing yellow circle with 150-point radius
- Attracts all nearby balls (including cue balls) with linear falloff
- Gravity deactivates when ball starts moving again

## Testing Notes

- 1-balls should automatically get the gravity accessory on creation
- Gravity field should appear after the ball moves and comes to rest
- All balls within 150 points should be slowly pulled toward the 1-ball
- Gravity should deactivate when the 1-ball starts moving
- Debug prints should show "🌍 Gravity" messages instead of "🌍 1-ball"

## Future Enhancements

Now that gravity is an accessory, we could:
- Create stronger/weaker gravity variants
- Apply gravity to other ball types
- Make gravity radius/strength configurable via UI
- Add repulsion (reverse gravity) accessories
- Combine gravity with other accessories (flying gravity ball, burning gravity ball, etc.)
