# ExplodeOnDestroy Accessory

## Overview

The `explodeOnDestroy` accessory causes a ball to create a massive explosion **when it's destroyed** (HP reaches 0), leaving a crater in the felt at its final position.

## Differences from ExplodeOnContact

| Feature | explodeOnContact | explodeOnDestroy |
|---------|------------------|------------------|
| **Triggers** | On ANY collision/damage | On death (HP = 0) |
| **Current Use** | 11-balls (striped red) | Available for any ball |
| **Behavior** | Instant explosion | Explosion at death |
| **Can be killed** | No (instant explosion) | Yes (takes damage first) |

## Usage

### Basic Attachment

```swift
// Attach to any ball
let ball = BlockBall(kind: .eight, ...)
_ = BallAccessoryManager.shared.attachAccessory(id: "explodeOnDestroy", to: ball)

// Or use the convenience method:
_ = ball.attachAccessory("explodeOnDestroy")
```

### In BlockBall Init

```swift
// Inside BlockBall initialization or after creation:
if kind == .twelve {  // Example: make 12-balls explode on death
    _ = attachAccessory("explodeOnDestroy")
}
```

### Checking if Ball Has It

```swift
let hasExplosion = BallAccessoryManager.shared.hasAccessory(ball: ball, id: "explodeOnDestroy")

if hasExplosion {
    print("This ball will explode when destroyed!")
}
```

## How It Works

1. **Ball takes damage** - Works normally, HP decreases
2. **HP reaches 0** - Ball is destroyed
3. **Accessory check** - `BallDamageSystem` checks for `explodeOnDestroy`
4. **Explosion triggered** - `createMassiveExplosion()` is called
5. **Crater created** - Grid-based explosion creates hole in felt
6. **Ball removed** - Ball destruction completes

## Implementation Details

### In BallAccessory.swift
```swift
final class ExplodeOnDestroyAccessory: BallAccessoryProtocol {
    let id = "explodeOnDestroy"
    let visualNode = SKNode()  // Empty - no visuals
    var preventsSinking: Bool { return false }
    
    // Purely a marker accessory - behavior handled by BallDamageSystem
}
```

### In BallDamageSystem.swift
```swift
private func handleBallDestruction(_ ball: BlockBall, health: BallHealth) {
    // Check for explode on destroy accessory
    let hasExplodeOnDestroy = BallAccessoryManager.shared.hasAccessory(
        ball: ball, 
        id: "explodeOnDestroy"
    )
    
    if hasExplodeOnDestroy {
        // Convert to blocks before explosion
        ball.convertToBlocks()
        // Create massive explosion at death position
        createMassiveExplosion(at: ball.position, ball: ball)
    }
    // ... rest of destruction logic
}
```

## Use Cases

### 1. Boss Balls
```swift
// Create a tough ball that explodes dramatically when finally defeated
let bossBall = BlockBall(kind: .four, ...)  // Heavy ball
_ = bossBall.attachAccessory("explodeOnDestroy")
// Takes 10 hits to kill, then explodes!
```

### 2. Mine Balls
```swift
// Balls that reward precision - kill them carefully or they explode
let mineBall = BlockBall(kind: .eight, ...)
_ = mineBall.attachAccessory("explodeOnDestroy")
// Player must sink it gently into pocket, not destroy it
```

### 3. Combo Chains
```swift
// Create chain reactions - destroy one, it explodes and damages others
let chainBall = BlockBall(kind: .nine, ...)
_ = chainBall.attachAccessory("explodeOnDestroy")
// When destroyed by explosion, creates new explosion
```

### 4. Level-Specific Balls
```swift
// Add to level generation
if level.hasExplosiveBalls {
    for ball in targetBalls where ball.ballKind == .ten {
        _ = ball.attachAccessory("explodeOnDestroy")
    }
}
```

## Visual Indicators (Optional)

Currently the accessory is **invisible** (no visual indicator). To add a visual cue:

### Option 1: Glowing Outline
```swift
func onAttach(to ball: BlockBall) {
    self.ball = ball
    
    // Add pulsing glow effect
    let glow = SKShapeNode(circleOfRadius: 15)
    glow.strokeColor = .red
    glow.lineWidth = 2
    glow.fillColor = .clear
    glow.alpha = 0.5
    
    let pulse = SKAction.sequence([
        SKAction.fadeAlpha(to: 0.8, duration: 0.5),
        SKAction.fadeAlpha(to: 0.3, duration: 0.5)
    ])
    glow.run(SKAction.repeatForever(pulse))
    
    visualNode.addChild(glow)
    ball.visualContainer.addChild(visualNode)
}
```

### Option 2: Warning Symbol
```swift
func onAttach(to ball: BlockBall) {
    self.ball = ball
    
    // Add small warning icon
    let warning = SKSpriteNode(imageNamed: "warningIcon")
    warning.size = CGSize(width: 8, height: 8)
    warning.position = CGPoint(x: 0, y: 12)  // Above ball
    visualNode.addChild(warning)
    
    ball.visualContainer.addChild(visualNode)
}
```

### Option 3: Particle Effect
```swift
func onAttach(to ball: BlockBall) {
    self.ball = ball
    
    // Add sparks/embers
    if let emitters = SKEmitterNode(fileNamed: "Sparks.sks") {
        emitters.position = .zero
        emitters.targetNode = ball.scene
        visualNode.addChild(emitters)
    }
    
    ball.visualContainer.addChild(visualNode)
}
```

## Configuration

The explosion uses the same settings as 11-ball explosions:

```swift
// In BallDamageSystem.DamageConfig:
var elevenBallExplosionRadius: CGFloat = 10.0  // Radius in blocks
var elevenBallMaxExplosions: Int = 1           // (N/A for explodeOnDestroy)
```

## Performance

- ✅ **No overhead** - Invisible accessory, just a marker
- ✅ **Grid-based explosions** - Fast (5-8ms per explosion)
- ✅ **Single texture rebake** - Efficient hole creation
- ✅ **Debris particles** - Visual feedback without physics cost

## Debugging

```swift
#if DEBUG
// Check if ball has the accessory
let hasExplosion = BallAccessoryManager.shared.hasAccessory(
    ball: ball, 
    id: "explodeOnDestroy"
)
print("Ball has explodeOnDestroy: \(hasExplosion)")

// Will log when explosion triggers:
// "💥 Ball has explodeOnDestroy - creating explosion at death position!"
#endif
```

## Testing Checklist

- [ ] Attach accessory to test ball
- [ ] Damage ball until HP reaches 0
- [ ] Verify explosion occurs at ball's position
- [ ] Check that hole appears in felt
- [ ] Confirm debris particles spawn
- [ ] Verify ball is removed after explosion
- [ ] Test with multiple explodeOnDestroy balls
- [ ] Verify chain reactions work (explosion damages nearby balls)

## Example: Level with Explosive Balls

```swift
// In level generation:
func generateLevel10() {
    // Create target balls
    let targetBalls = [
        BlockBall(kind: .eight, ...),
        BlockBall(kind: .nine, ...),
        BlockBall(kind: .ten, ...)
    ]
    
    // Make some explode on death
    for (index, ball) in targetBalls.enumerated() {
        if index % 2 == 0 {  // Every other ball
            _ = ball.attachAccessory("explodeOnDestroy")
        }
    }
    
    // Strategy: Destroy non-explosive balls first!
}
```

## Notes

- **Stacks with other accessories** - Ball can have multiple accessories
- **No limit on count** - Any number of balls can have this
- **Works with all ball types** - Cue balls, numbered balls, etc.
- **Grid system** - Uses fast grid-based explosion (no block mode switching)
- **Backward compatible** - Doesn't affect existing gameplay

---

**Result:** A powerful new gameplay mechanic that rewards careful play and creates dramatic moments when balls are destroyed! 💥
