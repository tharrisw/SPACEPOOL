# AI Codebase Map - SpacePool
**Created for AI Assistant Context**
**Last Updated:** January 22, 2026

## 🎯 Project Overview
**SpacePool** is an iOS pool/billiards game with unique block-style pixel art visuals set in a starfield background. Features physics-based gameplay with special ball abilities, damage system, and progressive difficulty.

---

## 📁 Core Architecture Files

### **AppDelegate.swift** (22 lines)
- Entry point for the app
- Creates and displays `GameViewController` as root view controller
- Sets window background to black
- Standard UIKit app lifecycle

### **GameStateManager.swift** (151 lines)
- Manages game progression: level, score, difficulty
- Persists state to `UserDefaults`
- **Properties:**
  - `currentLevel`, `currentScore`, `currentDifficulty`
  - Weak references to UI labels for auto-updating
- **Key Methods:**
  - `advanceToNextLevel()` - Increments level and difficulty
  - `addScore(_:)`, `setScore(_:)`, `resetScore()`
  - `resetProgress()` - Reset all game state
  - `incrementDifficulty()` - Difficulty scaling
- **Persistence Keys:** 
  - `"CurrentLevel"`, `"CurrentScore"`, `"CurrentDifficulty"`

---

## 🎨 Scene & Rendering

### **StarfieldScene.swift** (2748 lines) ⭐ MAIN GAME SCENE
- Main `SKScene` for gameplay
- Implements `SKPhysicsContactDelegate` and `BallDamageSystemDelegate`
- **Major Responsibilities:**
  - Star background animation with twinkling/supernovas/comets
  - Pool table rendering and physics
  - Ball spawning and lifecycle management
  - Physics simulation and collision handling
  - UI overlays (score, level, speed display)
  - Level progression and color themes
  - Boss level management with full-screen play area
- **Key Properties:**
  - `gameStateManager`, `tableConfig`, `physicsConfig`
  - `stars` array, starfield animation state
  - Theme colors (`ThemeColor1`, `ThemeColor2`)
  - 12 color schemes for table variety
  - `isBossLevel` - Boss level state (internal for FeltManager access)
- **Key Methods:**
  - `isValidSpawnPoint()` - Grid-based spawn validation
  - `randomSpawnPoint()` - Find valid spawn with 500 attempts
  - `spawnBlockCueBallAtCenter()` - Smart cue ball spawning with fallback
  - `respawnBlockCueBallAtCenter()` - Respawn after destruction
  - `spawnBall(type:customHP:)` - Public API for spawning any ball type
  - `spawnBalls(type:count:customHP:)` - Public API for spawning multiple balls
  - `setupBossLevel()` - Configure full-screen boss level
  - `createBossLevelFeltManager()` - Create full-screen grid system
  - Ball collision and damage handling
  - Level advancement logic
- **Performance:** Uses grid-based validation (O(1)) instead of node traversal

### **StarfieldScene+TableDrawing.swift** (104 lines)
- Extension for table rendering helpers
- Likely contains drawing utilities for pool table visualization

### **StarManager.swift** (628 lines)
- Manages starfield background effects
- **Features:**
  - Star spawning at configurable intervals
  - Star growth, movement, and fadeout
  - Twinkling animations (60% of stars)
  - Special events: supernovas, comets (1 in 10,000 chance)
- **Configuration:**
  - Max 300 stars, spawns every 0.15s
  - Initial star count: 100
  - Size range: 2-75 points
  - Speed scaling based on difficulty
- **Key Methods:**
  - `populateInitialStars()` - Create initial star field
  - `update(deltaTime:)` - Update all stars, spawn new ones
  - `spawnStar(at:isInitial:angle:)` - Create individual star
  - `triggerRandomSpecialEvent()` - Supernova/comet spawning
  - `spawnManualSupernova()`, `spawnComet()`
- **Uses:** `SeededRandom` for deterministic randomness

---

## 🎱 Ball System

### **BlockBall.swift** (2109 lines) ⭐ CORE GAMEPLAY OBJECT
- Main ball class, extends `SKNode`
- **Features:**
  - 5x5 block visual style with circular physics
  - 15 ball types (cue + 1-15) with special abilities
  - Damage/HP system integration
  - Aiming and shooting mechanics
  - Sinking detection and pocket physics
  - Ball accessories (wings, fire, gravity, etc.)
- **Ball Types (Kind enum):**
  - `.cue` - Player's white ball
  - `.one` - Gravity ball (attracts others when stationary)
  - `.two` - Spawns duplicate cue ball when hit
  - `.three` - Heavy ball (10x mass)
  - `.four` - Pulse ball (charges then releases damage pulse)
  - `.five` - Flying ball (levitates over pockets with wings)
  - `.six` - Healing ball (heals nearby cue balls)
  - `.seven` - Burning ball (catches fire, immune to burn damage)
  - `.eight` - Classic 8-ball (black solid)
  - `.nine` - 9-ball (yellow striped)
  - `.ten` - Speedy ball (2x speed and collision power)
  - `.eleven` - Explodes instantly when hit
  - `.twelve` - `.fifteen` - Standard striped balls
- **Visual Shapes:** circle, square, diamond, triangle, hexagon
- **Key Properties:**
  - Physics tuning (maxImpulse, damping, friction, restitution)
  - Aiming state (isAiming, canShoot, touchStart)
  - Sinking state (isSinking, pocketInfoPrinted)
  - Ball-specific state (hasCaughtFire, hasHealerMovedOnce, etc.)
- **Key Methods:**
  - `spawnAt(_:scene:shape:)` - Create ball in scene
  - `update(deltaTime:)` - Physics updates, state checks
  - `touchesBegan/Moved/Ended()` - Aiming and shooting
  - `checkSinkingConditions()` - Pocket detection using radial sampling
  - `onDamage()` - Damage response, special effects
  - Ball-specific behavior (gravity attraction, healing pulse, etc.)
- **Critical:** 2-ball split spawning now uses multi-directional fallback (see SPAWN_VALIDATION_IMPROVEMENTS.md)

### **BallSpriteGenerator.swift** (309 lines)
- Generates ball textures with spots/stripes
- **Features:**
  - 17 spot positions (8 center + 8 edge + 1 hidden)
  - Supports solid and striped balls
  - 3D rotation simulation for stripe rendering
  - Pixel-perfect 5x5 grid rendering
  - **Optional outline rendering** for edge blocks (used by 8-ball)
- **Key Enum:** `SpotPosition` - All possible white spot locations
- **Key Methods:**
  - `generateTexture(fillColor:spotPosition:shape:isStriped:outlineColor:)` - Single texture
  - `generateAllTextures()` - All 17 positions for a ball
  - `generate(fillColor:shape:isStriped:stripeColor:outlineColor:)` - Static convenience
  - `isEdgeBlock(cx:cy:)` - Detects perimeter blocks for outline
- **Color Definitions:** lightRed, darkRed, darkGreen, maroon, vibrantYellow
- **3D Projection:** Uses sphere projection math to render stripes correctly
- **8-Ball Special:** Black with subtle grey outline (0.25 white) for starfield visibility

### **BallAccessory.swift** (3016 lines)
- Ball accessories system - visual decorations + special abilities
- **CRITICAL DESIGN PRINCIPLE:** Accessories are PURELY VISUAL (no physics)
- **Protocol:** `BallAccessoryProtocol`
  - `id: String` - Unique identifier
  - `visualNode: SKNode` - Visual representation
  - `preventsSinking: Bool` - Can prevent pocket sinking
  - `onAttach/onDetach/update()` - Lifecycle methods
- **Accessory Types:**
  - `FlyingAccessory` - Wings, prevents sinking, rescue flight
  - `BurningAccessory` - Fire particles, damages nearby balls/felt
  - `GravityAccessory` - Attracts other balls, visual rings
  - `HeavyAccessory` - 10x mass increase
  - `DamagePulseAccessory` - Charges then releases damage wave
  - `HealingAccessory` - Healing particles, restores HP to nearby cue balls
  - `SpeedBoostAccessory` - 2x speed multiplier
- **Key Features:**
  - Wings added directly to scene (not ball) to avoid physics issues
  - Fire damages felt via `FeltManager.createBurnMark()`
  - Gravity uses force application on nearby balls
  - All accessories update every frame
- **Performance:** Accessories don't affect ball physics or collisions

### **BallDamageSystem.swift** (1600 lines)
- Health/damage management for all balls
- **Configuration (DamageConfig):**
  - Starting HP: 100
  - Cue ball collision damage: 80
  - Same-type damage: 4 (cue), 1 (8-ball)
  - Cue ball armor: 75%
  - Min damage impulse: 50
  - Global damage multiplier
  - Accessory settings (pulse radius/delay, explosion radius)
- **Destruction Effects:** explode (fast burst) or crumble (slow fall)
- **Delegate Methods:**
  - `didDestroyBall(_:)` - Ball HP reached 0
  - `didClearAllTargets()` - All non-cue balls destroyed (level win)
  - `shouldRespawnCueBall()` - Cue ball destroyed
  - `twoBall:tookDamageFrom:` - 2-ball damage (optional)
- **Key Methods:**
  - `trackBall(_:)` - Register ball for HP tracking
  - `applyDamage(_:to:from:)` - Apply damage with armor calculation
  - `handleCollision(between:and:impulse:)` - Collision damage logic
  - `applyAreaDamage(at:radius:)` - Explosion/pulse damage
  - Visual feedback (health bars, damage numbers)

### **CueBallController.swift** (225 lines)
- Modular controller for cue ball (alternative to BlockBall's built-in)
- **Features:**
  - Spawning, input handling, physics, visuals
  - Aiming line with arrow head
  - Power curve mapping (drag distance → impulse)
  - Rest detection for shot readiness
- **Configuration (Config struct):**
  - Radius, maxPower, maxShotDistance
  - Rest thresholds, damping, restitution
  - Visual settings (line color, arrow style)
- **Key Methods:**
  - `spawnCueBall(at:)` - Create cue ball with physics
  - `touchesBegan/Moved/Ended()` - Shooting input
  - `update(deltaTime:)` - Rest detection
  - `setMaxPower(_:)` - Adjust shot power (persisted)
- **Persistence:** Saves `maxPower` to UserDefaults
- **Note:** This appears to be an older/alternative approach; BlockBall has its own shooting

---

## 🏓 Table System

### **BlockTableBuilder.swift** (1146 lines) ⭐ TABLE CONSTRUCTION
- Builds pool table with physics, pockets, and grid system
- **Result Struct:** `BlockTableResult`
  - `container`, `allNodes`, `physicsNodes`
  - `feltRect`, `pocketCenters`, `pocketRadius`
  - `feltManager` - Dynamic felt state management
  - `tableGrid` - Unified grid system
- **FeltManager Class:**
  - Manages felt texture rendering
  - Handles explosions and burn marks
  - Tracks scorched cells from burning balls
  - **NO BLOCK MODE** - Uses grid-only explosions
  - Methods: `createInitialTexture()`, `rebakeTexture()`, `createExplosion(at:radius:)`
- **TableGrid Class (implied):**
  - Grid-based collision detection for felt holes
  - O(1) lookups for spawn validation
  - Methods: `generateFeltTexture()`, `isHole(at:)`, `isFelt(at:)`
- **Key Features:**
  - Block-style visual construction
  - Physics rails around perimeter
  - Pocket physics with sinking detection
  - Dynamic felt destruction and rendering
  - Scorch marks from burning balls

### **TableConfiguration.swift** (33 lines)
- Configuration for table appearance
- **Properties:**
  - `selectedSchemeIndex` - Current color scheme (0-11)
  - `feltColor`, `frameColor` - Reference ThemeColors from StarfieldScene
- **Methods:**
  - `randomScheme()` - Generate random table appearance
- **Note:** Ties into StarfieldScene's 12 color schemes

---

## 🔧 Utilities & Helpers

### **SeededRandom.swift** (163 lines)
- Deterministic random number generator
- **Algorithm:** Linear Congruential Generator (LCG)
- **Features:**
  - Persistent call counter (survives app restarts)
  - Periodic state retransformation for variety
  - Golden ratio hashing for better distribution
- **Methods:**
  - `next()` - Next UInt64
  - `nextDouble()` - Double in 0...1
  - `nextDouble(in:)` - Double in range
  - `nextInt(in:)` - Int in range
  - `saveCounter()` - Persist state
- **Persistence:**
  - Key: `"StarfieldRandomCounter"`
  - Saves every 100 calls
  - Retransforms every 1000 calls
- **Purpose:** Consistent starfield/gameplay across app launches

### **LogoRenderer.swift** (181 lines)
- Renders "SPACEPOOL" logo using pixel blocks
- **Features:**
  - 5x7 grid letter patterns with italic slant
  - Configurable color and position
  - Block-by-block rendering
- **Methods:**
  - `renderLogo(centerPoint:color:yOffset:)` - Draw logo
  - `hideLogo()`, `showLogo()` - Visibility control
  - `updateColor(_:)` - Change logo color
- **Letter Patterns:** S, P, A, C, E, O, L defined as 2D arrays
- **Used For:** Title screen and UI branding

---

## 📊 Configuration & Data

### **SPAWN_VALIDATION_IMPROVEMENTS.md** (204 lines)
- Documentation of spawn system improvements
- **Changes:**
  - Grid-based validation (O(1) vs O(n))
  - Enhanced `isValidSpawnPoint()` - checks holes, felt, pockets, balls
  - Improved `randomSpawnPoint()` - 500 attempts, detailed logging
  - Smart cue ball spawning with progressive fallback
  - 2-ball split spawn intelligence (8 directions + random)
- **Performance:** ~1000x faster spawn validation
- **Test Cases:** Normal, center hole, crowded, heavily damaged, 2-ball split
- **Files Modified:** StarfieldScene.swift, BlockBall.swift

---

## 🎮 Game Flow

### **Startup Sequence:**
1. `AppDelegate` creates `GameViewController`
2. GameViewController (not shown) creates `StarfieldScene`
3. StarfieldScene initializes:
   - `GameStateManager` - Loads level/score/difficulty
   - `SeededRandom` - Deterministic randomness
   - `StarManager` - Background starfield
   - Table via `BlockTableBuilder` → `FeltManager`, `TableGrid`
   - Physics world and contact delegate
4. Spawn initial cue ball and target balls based on level
5. Game loop begins via SpriteKit's `update()`

### **Game Loop (every frame):**
1. `StarfieldScene.update(currentTime:)`
2. Update starfield (`StarManager.update()`)
3. Update balls (`BlockBall.update()`)
4. Update accessories (`BallAccessory.update()`)
5. Physics simulation (SpriteKit)
6. Check sinking conditions
7. Handle collisions (`BallDamageSystem.handleCollision()`)
8. Update UI labels (speed, score, level)

### **Level Progression:**
1. Player shoots cue ball to hit target balls
2. Ball collisions apply damage via `BallDamageSystem`
3. When ball HP reaches 0:
   - `didDestroyBall()` called
   - Ball removed with destruction effect
4. When all non-cue balls destroyed:
   - `didClearAllTargets()` called
   - `GameStateManager.advanceToNextLevel()`
   - Table color theme changes
   - Difficulty increases
   - Spawn new set of target balls

### **Boss Levels (Every 10th Level):**
- Triggered automatically at levels 10, 20, 30, etc.
- Can be manually triggered via Boss Level button in settings
- **Full-screen gameplay:**
  - `blockFeltRect` set to entire screen bounds
  - No visible table, just starfield background
  - Full-screen `TableGrid` created (all cells marked as felt)
  - `FeltManager` prevents balls from sinking
  - Physics edges at screen boundaries cause bouncing
- **Enemy-based progression** (Updated Jan 22, 2026):
  - Level ends when all enemy balls are destroyed
  - Currently spawns 1 8-ball as boss enemy
  - Uses same completion system as regular levels (`didClearAllTargets`)
  - Easily configurable for more enemies or different types
- **No pockets:** `blockPocketCenters = []`, `blockPocketRadius = 0`
- **UI:** "BOSS LEVEL" title (pulsing red text)
- **Settings button remains clickable** (UIKit overlay)

### **Special Ball Behaviors:**
- **1-ball (Gravity):** Attracts nearby balls when stationary
- **2-ball (Duplicate):** Spawns extra cue ball when damaged
- **3-ball (Heavy):** 10x mass, harder to move
- **4-ball (Pulse):** Charges 1s then releases damage wave
- **5-ball (Flying):** Wings prevent sinking, rescue flight when over pocket
- **6-ball (Healing):** Heals nearby cue balls when stationary
- **7-ball (Burning):** Catches fire on first move, damages felt/balls
- **11-ball (Explode):** Instantly explodes when hit

---

## 🔑 Key Design Patterns

### **Grid-Based Validation**
- `TableGrid` provides O(1) hole/felt checks
- Used for: spawn validation, explosion detection, sinking logic
- Replaced expensive node traversal

### **Accessory System**
- Protocol-based design (`BallAccessoryProtocol`)
- Visual-only (no physics modification)
- Composable abilities (ball can have multiple accessories)

### **Manager Pattern**
- `GameStateManager` - Level/score/difficulty
- `StarManager` - Starfield effects
- `FeltManager` - Table surface state
- `BallDamageSystem` - Health/damage logic

### **Delegate Pattern**
- `BallDamageSystemDelegate` - Damage events
- `SKPhysicsContactDelegate` - Collision events

### **Persistence**
- `UserDefaults` for simple state (level, score, difficulty, random counter)
- Keys prefixed by purpose (e.g., "CurrentLevel", "StarfieldRandomCounter")

---

## 🐛 Known Issues & TODOs

### **Spawn System (ADDRESSED)**
- ✅ Fixed: Balls no longer spawn in holes or on other balls
- ✅ Fixed: Multi-directional fallback for 2-ball splits
- ✅ Fixed: Grid-based validation for performance

### **Boss Level System (ADDRESSED - Jan 22, 2026)**
- ✅ Fixed: Boss levels now use full-screen play area (not regular table size)
- ✅ Fixed: Balls no longer sink in boss levels (FeltManager + TableGrid created)
- ✅ Fixed: Pockets properly cleared for boss levels
- ✅ Verified: Settings overlay button remains clickable
- ✅ Fixed: Ball spawning from settings overlay now works on boss levels
- ✅ Fixed: Felt effects (holes, scorching) disabled on boss levels
- ✅ Fixed: Explosions still work on boss levels (visual effects + damage, no felt mods)

### **Potential Areas to Review**
- GameViewController.swift (not seen - main view controller)
- PhysicsConfiguration (referenced but not seen)
- TitleAnimationManager (referenced but not seen)
- PhysicsAdjusterUI (referenced but not seen)

---

## 📝 Important Files Not Yet Reviewed
Based on references in code, these files likely exist but weren't shown:
- **GameViewController.swift** - Main view controller (43 lines)
- **PhysicsConfiguration.swift** - Physics settings struct
- **TitleAnimationManager.swift** - Title screen animations
- **Star.swift** - Star data structure (likely a simple struct)

## 🎮 UI & Settings

### **PhysicsAdjusterUI.swift** (NEW)
- Physics and game settings overlay
- **Features:**
  - Toggle button (⚙️) in top-right corner
  - Semi-transparent full-screen overlay
  - Reset Progress, Restart Game, Trigger Boss Level
  - **Texture Cache Reset** - Forces ball texture regeneration
  - Ball spawning grid (types 1-15)
- **Key Methods:**
  - `createToggleButton()` - Creates settings button
  - `showOverlay()` / `hideOverlay()` - Toggle overlay visibility
  - `handleClearTextureCache()` - Clear and regenerate textures
  - `handleSpawnBall(_:)` - Spawn balls from UI
  - Touch handling for overlay interaction

## 📚 Documentation Files
- **SPAWN_VALIDATION_IMPROVEMENTS.md** - Documents spawn system improvements (204 lines)
- **BOSS_LEVEL_BUTTON_INSTRUCTIONS.md** - Instructions for boss level button (145 lines)
- **BOSS_LEVEL_FULLSCREEN_FIX.md** - Documents full-screen boss level fix (Jan 22, 2026)
- **BOSS_LEVEL_ADDITIONAL_FIXES.md** - Ball spawning and felt effects on boss levels (Jan 22, 2026)
- **BOSS_LEVEL_EXPLOSION_FIX.md** - Explosions work on boss levels with visual effects (Jan 22, 2026)
- **TITLE_ANIMATION_FADE_OUT_FIX.md** - Title logo fades out gracefully before level loads (Jan 22, 2026)
- **BOSS_LEVEL_SPAWN_FIX.md** - Grid alignment fix for spawn validation (Jan 22, 2026)
- **BOSS_LEVEL_COMPLETE_FIX_SUMMARY.md** - Complete summary of all boss level fixes (Jan 22, 2026)
- **BOSS_LEVEL_ENEMY_SYSTEM.md** - Enemy-based boss level progression (Jan 22, 2026)
- **8BALL_OUTLINE_AND_CACHE_RESET.md** - 8-ball outline enhancement + cache reset button (Jan 22, 2026) ⭐ NEW
- **AI_CODEBASE_MAP.md** - This file

---

## 🎯 Quick Reference: File Purposes

| File | Purpose | Size | Importance |
|------|---------|------|------------|
| StarfieldScene.swift | Main game scene | 2840 | ⭐⭐⭐ Critical |
| BlockBall.swift | Ball gameplay object | 2109 | ⭐⭐⭐ Critical |
| BallAccessory.swift | Ball abilities | 3016 | ⭐⭐ Major |
| BallDamageSystem.swift | Health/damage | 1600 | ⭐⭐ Major |
| BlockTableBuilder.swift | Table construction | 1174 | ⭐⭐ Major |
| StarManager.swift | Background effects | 628 | ⭐ Important |
| PhysicsAdjusterUI.swift | Settings overlay UI | NEW | ⭐ Important |
| BallSpriteGenerator.swift | Ball textures | 309 | ⭐ Important |
| CueBallController.swift | Cue ball (alt) | 225 | Minor |
| LogoRenderer.swift | Logo rendering | 181 | Minor |
| SeededRandom.swift | Random numbers | 163 | ⭐ Important |
| GameStateManager.swift | Level/score | 151 | ⭐⭐ Major |
| StarfieldScene+TableDrawing.swift | Table drawing | 104 | Minor |
| GameViewController.swift | Main view controller | 43 | Standard |
| TableConfiguration.swift | Table config | 33 | Minor |
| AppDelegate.swift | App entry | 22 | Standard |

---

## 💡 Tips for Future AI Context

### **Finding Functionality:**
- **Ball behavior?** → BlockBall.swift, BallAccessory.swift
- **Damage/HP?** → BallDamageSystem.swift
- **Table rendering?** → BlockTableBuilder.swift, FeltManager
- **Spawn logic?** → StarfieldScene.swift (`isValidSpawnPoint`, `randomSpawnPoint`)
- **Game state?** → GameStateManager.swift
- **Visual effects?** → StarManager.swift, LogoRenderer.swift
- **Physics tuning?** → BlockBall.swift (physics properties)
- **Ball textures?** → BallSpriteGenerator.swift

### **Common Tasks:**
- **Add new ball type:** Extend `BlockBall.Kind` enum, add visual properties, implement special behavior
- **Add new accessory:** Create class implementing `BallAccessoryProtocol`, add to ball
- **Change difficulty:** Modify `GameStateManager` difficulty logic, adjust spawn rates
- **Fix spawn issues:** Check `isValidSpawnPoint()` and `randomSpawnPoint()` in StarfieldScene
- **Adjust physics:** Tune properties in BlockBall or PhysicsConfiguration
- **Modify boss levels:** Edit `setupBossLevel()` and `createBossLevelFeltManager()` in StarfieldScene

### **Performance Notes:**
- Grid-based validation is O(1) - always prefer over node traversal
- Accessories must not add physics bodies (visual only)
- Starfield limited to 300 stars for performance
- Felt texture rebaked only when needed (explosions)

---

**End of AI Codebase Map**
