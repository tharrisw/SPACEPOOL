# Spawner Accessory Refactor

## Summary
Moved the 2-ball's cue ball spawning ability from hardcoded behavior in `BlockBall.onDamage()` into a reusable `SpawnerAccessory`. This makes the spawning mechanic modular and allows it to be attached to any ball type.

## Changes Made

### 1. BallAccessory.swift
**Added `SpawnerAccessory` class:**
- New accessory that spawns a duplicate cue ball when the host ball takes damage from a cue ball
- Implements the same spawn logic that was previously in `BlockBall.onDamage()`
- Includes intelligent spawn position finding with fallback strategies:
  1. Try position to the right of the spawner ball
  2. Try other directions (left, up, down, diagonals)
  3. Use random spawn system as last resort
  4. Use original candidate position if all else fails
- Validates spawn positions using the grid-based felt system
- Sets temporary collision immunity between new cue ball and spawner
- Applies impulses to push balls apart and prevent immediate re-collision

**Updated `BallAccessoryManager`:**
- Registered `SpawnerAccessory` in `registerDefaultAccessories()`
- Added `"spawner"` case to accessory instantiation switch
- Added helper methods:
  - `hasSpawner(ball:)` - Check if a ball has the spawner ability
  - `getSpawnerAccessory(for:)` - Get the spawner accessory instance for a ball

### 2. BlockBall.swift
**Simplified `onDamage()` method:**
- Removed all the 2-ball spawn logic (100+ lines)
- Now just an empty method with a comment that spawning is handled by the accessory

**Attached spawner to 2-balls:**
- Added `_ = attachAccessory("spawner")` for 2-balls in `init`
- Placed after ball is added to scene so accessory has access to `ball.scene`

**Made `sceneRef` accessible:**
- Changed `private weak var sceneRef` to `internal weak var sceneRef`
- Allows accessories to access the scene reference when `ball.scene` is nil

### 3. BallDamageSystem.swift
**Updated damage application to trigger spawner:**
- After calling `ball.onDamage()`, checks if ball has spawner accessory
- If spawner exists and damage source is a cue ball, triggers `spawner.triggerSpawn()`
- Passes the ball, source cue ball, and damage system reference
- Follows same pattern as existing zapper accessory trigger

## Benefits

1. **Modularity**: Spawning is now a reusable component, not hardcoded to 2-balls
2. **Consistency**: Spawner follows same pattern as other accessories (flying, zapper, etc.)
3. **Extensibility**: Any ball type can now have spawning ability by attaching the accessory
4. **Maintainability**: Spawn logic is in one place, not duplicated
5. **Cleaner Code**: Removed 100+ lines of spawn logic from `BlockBall.onDamage()`

## Testing
- Verify 2-balls still spawn cue balls when hit by a cue ball
- Verify spawn positions are valid (not in holes, not on other balls)
- Verify temporary collision immunity prevents immediate re-collision
- Verify new cue balls are properly registered with the damage system
- Verify new cue balls are added to the scene's cue ball list

## Future Enhancements
- Could make spawned ball type configurable (not just cue balls)
- Could add visual indicator (e.g., glowing aura) for balls with spawner
- Could add spawn cooldown to prevent spam
- Could add spawn limit per ball (e.g., max 3 spawns before ability deactivates)
