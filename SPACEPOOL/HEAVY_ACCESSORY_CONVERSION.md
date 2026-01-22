# Heavy Accessory Conversion

## Summary
Converted the 3-ball's "heavy" ability from hardcoded mass modification to a proper accessory system implementation.

## Changes Made

### 1. Created HeavyAccessory Class (BallAccessory.swift)
- New `HeavyAccessory` class that implements `BallAccessoryProtocol`
- Applies 10x mass multiplier when attached to a ball
- Stores original mass and restores it on detachment
- Purely functional - no visual component needed

```swift
final class HeavyAccessory: BallAccessoryProtocol {
    let id = "heavy"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private let massMultiplier: CGFloat = 10.0  // 10x heavier than normal
    private var originalMass: CGFloat = 0.17  // Default normal mass
    
    func onAttach(to ball: BlockBall) {
        // Stores original mass and multiplies by 10x
    }
    
    func onDetach(from ball: BlockBall) {
        // Restores original mass
    }
}
```

### 2. Registered HeavyAccessory (BallAccessory.swift)
- Added to `registerDefaultAccessories()` method
- Added to accessory instantiation switch statement in `attachAccessory()`
- Added helper method `hasHeavy(ball:)` to BallAccessoryManager

### 3. Updated BlockBall (BlockBall.swift)
- **Removed** hardcoded mass modification in `buildPhysics()` for 3-balls
- **Added** automatic heavy accessory attachment for 3-balls in initializer
- **Updated** comment for `Kind.three` to indicate it uses an accessory
- **Preserved** 4-ball's hardcoded mass (100x) until it's converted to an accessory

### 4. Physics Behavior
- Normal balls: mass = 0.17
- 3-ball with heavy accessory: mass = 1.7 (0.17 × 10)
- 4-ball (not yet converted): mass = 17.0 (0.17 × 100)

## Benefits

1. **Consistency**: 3-ball now follows the same accessory pattern as other special balls (1-ball gravity, 5-ball flying, 9-ball zapper, etc.)

2. **Modularity**: Heavy ability can now be:
   - Attached to any ball type at runtime
   - Removed/detached dynamically
   - Tested independently

3. **Maintainability**: Mass modifications are centralized in the accessory, not scattered through physics code

4. **Extensibility**: Easy to create variations:
   - Super heavy accessory (50x mass)
   - Light accessory (0.5x mass)
   - Dynamic mass that changes over time

## Future Work

Consider converting 4-ball's "immovable" ability to an accessory:
- Create `ImmovableAccessory` with 100x mass multiplier
- Attach to 4-balls automatically
- Remove hardcoded mass check in `buildPhysics()`

## Testing Notes

- 3-balls should behave identically to before (10x heavier than normal)
- They should resist movement from collisions significantly
- Mass should be restored if accessory is removed (though this doesn't happen in normal gameplay)
- Debug logs confirm mass changes on attachment/detachment

## Code Quality

- Follows existing accessory pattern (similar to GravityAccessory, FlyingAccessory)
- Includes debug logging for mass changes
- No visual component needed (behavior-only accessory)
- Clean separation of concerns
