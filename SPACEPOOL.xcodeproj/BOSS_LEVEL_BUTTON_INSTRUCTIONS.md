# Boss Level Button - PhysicsAdjusterUI Implementation Instructions

## Overview
A button has been added to trigger boss levels on demand via the settings overlay. The StarfieldScene is now set up to handle this, but you need to add the button to your PhysicsAdjusterUI class.

## Changes Made to StarfieldScene.swift

### 1. Added Boss Level State Variables
```swift
// MARK: - Boss Level State
private var isBossLevel: Bool = false
private var bossLevelTimer: TimeInterval = 0
private let bossLevelDuration: TimeInterval = 10.0
private var bossLevelTimerLabel: SKLabelNode?
private var forceBossLevelNext: Bool = false  // Flag to force next level to be boss level
```

### 2. Updated setupPhysicsAdjusterUI()
Added a new callback registration:
```swift
physicsAdjusterUI?.onBossLevel { [weak self] in
    guard let self = self else { return }
    // Complete current level and load boss level next
    self.triggerBossLevel()
}
```

### 3. Added triggerBossLevel() Method
This method:
- Sets the `forceBossLevelNext` flag to true
- Completes the current level (if in gameplay)
- Triggers a transition to a boss level

### 4. Updated loadCurrentLevel()
Now checks both conditions:
```swift
if levelNumber % 10 == 0 || forceBossLevelNext {
    print("👹 BOSS LEVEL!")
    forceBossLevelNext = false  // Reset flag after using it
    setupBossLevel()
}
```

### 5. Added Boss Level Implementation
Complete boss level system with:
- `setupBossLevel()` - Creates screen boundaries and UI
- `displayBossLevelTitle()` - Shows pulsing "BOSS LEVEL" text
- `displayBossLevelTimer()` - Creates countdown display
- `updateBossLevelTimer()` - Updates timer color as time runs out
- `spawnBossLevelCueBall()` - Spawns cue ball at center
- `completeBossLevel()` - Handles completion

## What You Need to Add to PhysicsAdjusterUI

### 1. Add a Boss Level Button Property
```swift
private var bossLevelButton: UIButton?
private var onBossLevelCallback: (() -> Void)?
```

### 2. Add the Callback Registration Method
```swift
func onBossLevel(_ callback: @escaping () -> Void) {
    self.onBossLevelCallback = callback
}
```

### 3. Create the Button in Your UI Setup
Add this to wherever you create your other buttons (Reset, Restart, etc.):

```swift
// Boss Level Button
let bossButton = UIButton(type: .system)
bossButton.setTitle("🎮 Boss Level", for: .normal)
bossButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
bossButton.backgroundColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.8)
bossButton.setTitleColor(.white, for: .normal)
bossButton.layer.cornerRadius = 8
bossButton.addTarget(self, action: #selector(bossLevelButtonTapped), for: .touchUpInside)
// Position it appropriately in your layout
// bossButton.frame = CGRect(...)
self.bossLevelButton = bossButton
// Add to your overlay view
```

### 4. Add the Button Action Handler
```swift
@objc private func bossLevelButtonTapped() {
    print("🎮 Boss Level button tapped!")
    onBossLevelCallback?()
}
```

### 5. Update Your Layout Method
Make sure to include the boss level button in your layout calculations alongside Reset and Restart buttons.

## Button Behavior

When the button is pressed:
1. **On Title Screen**: Advances to next level and makes it a boss level
2. **During Gameplay**: Completes the current level and transitions to a boss level
3. **During Level Transition**: Ignores the press (safety check)

## Boss Level Features

- Plays on the starfield (no table)
- Screen edges act as bouncing walls
- 10-second countdown timer
- Dramatic "BOSS LEVEL" title that pulses
- Timer changes color (white → orange → red)
- Just bounce around to survive!

## Testing

To test the button:
1. Start the game
2. Open the settings overlay (physics adjuster toggle button)
3. Press the "🎮 Boss Level" button
4. The current level should complete and transition to a boss level
5. Bounce around for 10 seconds
6. Next level loads normally (unless level % 10 == 0)

## Suggested Button Placement

Place it near the Reset and Restart buttons, perhaps:
```
┌─────────────────────┐
│  Settings Overlay   │
├─────────────────────┤
│ [Physics Controls]  │
│ ...                 │
├─────────────────────┤
│ [ 🔄 Restart ]      │
│ [ 🗑 Reset ]        │
│ [ 🎮 Boss Level ]   │  ← New button
└─────────────────────┘
```

## Notes

- The boss level system is fully implemented in StarfieldScene
- Boss levels automatically occur every 10 levels
- The button provides a way to test or manually trigger them
- The `forceBossLevelNext` flag ensures the next level is always a boss level when triggered manually
- After the boss level completes, normal level progression resumes
