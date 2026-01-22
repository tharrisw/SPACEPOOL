//
//  StarfieldScene.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/16/26.
//

import Foundation
import SpriteKit
import UIKit

class StarfieldScene: SKScene, SKPhysicsContactDelegate, BallDamageSystemDelegate {
    // MARK: - Configuration
    var physicsConfig = PhysicsConfiguration.default
    var tableConfig: TableConfiguration!
    
    // MARK: - Managers
    private var physicsAdjusterUI: PhysicsAdjusterUI?
    var gameStateManager: GameStateManager!
    
    // UI: Cue ball speed display
    private var cueBallSpeedLabel: SKLabelNode?
    
    var titleAnimationManager: TitleAnimationManager?
    
    // MARK: - Screen Properties
    var centerPoint: CGPoint = .zero
    private var maxDistanceFromCenter: Double = 0
    
    // MARK: - Time Tracking
    private var lastUpdateTime: TimeInterval = 0
    private var totalElapsedTime: TimeInterval = 0
    
    // MARK: - Star Properties
    private var stars: [Star] = []
    private var timeSinceLastSpawn: TimeInterval = 0
    
    // MARK: - Star Configuration
    private let initialStarCount = 150
    private let maxStars = 300
    private let spawnInterval: TimeInterval = 0.1
    private let minSize: CGFloat = 1.0
    private let maxSize: CGFloat = 6.0
    private var minSpeed: Double = 80.0
    private var maxSpeed: Double = 250.0
    private var growthRate: Double = 3.0
    private let initialGrowthRate: Double = 0.8
    private let minGrowthMultiplier: Double = 0.8
    private let maxGrowthMultiplier: Double = 1.2
    private let visibilityThreshold: Double = 0.1
    private let fadeInRange: Double = 0.15
    private let removalBuffer: CGFloat = 100
    private let twinklePercentage: Double = 0.2
    private let specialEventOdds: Double = 0.0008
    
    // Star texture for performance optimization
    private var starTexture: SKTexture?
    
    // MARK: - Comet Properties
    private let cometMinSize: CGFloat = 3.0
    private let cometMaxSize: CGFloat = 8.0
    private let cometMinSpeed: Double = 300.0
    private let cometMaxSpeed: Double = 600.0
    private let cometColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
    
    // MARK: - Physics Properties
    var ballMass: CGFloat = 0.12
    var ballFriction: CGFloat = 0.08
    var ballLinearDamping: CGFloat = 0.55
    var ballAngularDamping: CGFloat = 0.297
    var ballRestitution: CGFloat = 0.95
    var maxShotDistance: CGFloat = 200
    var maxImpulse: CGFloat = 800
    var restLinearSpeedThreshold: CGFloat = 5.0
    var restAngularSpeedThreshold: CGFloat = 0.5
    var stopSpeedThreshold: CGFloat = 10.0
    var stopAngularThreshold: CGFloat = 1.0
    var supportSampleDepth: CGFloat = 2.5
    var minUnsupportedAtZeroSpeed: CGFloat = 0.4
    var maxUnsupportedAtHighSpeed: CGFloat = 0.75
    var lowSpeedThreshold: CGFloat = 30.0
    var highSpeedThreshold: CGFloat = 400.0
    var minTimeOverPocket: TimeInterval = 0.05
    var maxTimeOverPocket: TimeInterval = 2.0
    
    // MARK: - Random Seed
    var randomSeed: UInt64 = 0
    private var random: SeededRandom!
    
    // MARK: - Logo
    var logoBlocks: [SKSpriteNode] = []
    
    // MARK: - Theme Colors
    static var ThemeColor1: SKColor = .white  // Global color for felt, title, level, score, logo
    static var ThemeColor2: SKColor = .gray   // Global color for rails
    var selectedColorSchemeIndex: Int = 0
    
    // MARK: - Color Schemes
    let colorSchemes: [(name: String, color1: SKColor, color2: SKColor)] = [
        ("Classic Green", SKColor(red: 0.0, green: 0.5, blue: 0.3, alpha: 1.0), SKColor(red: 0.55, green: 0.15, blue: 0.30, alpha: 1.0)),
        ("Ocean Blue", SKColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0), SKColor(red: 1.0, green: 0.55, blue: 0.45, alpha: 1.0)),
        ("Royal Purple", SKColor(red: 0.5, green: 0.2, blue: 0.7, alpha: 1.0), SKColor(red: 0.55, green: 0.30, blue: 0.10, alpha: 1.0)),
        ("Sunset Orange", SKColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0), SKColor(red: 0.10, green: 0.25, blue: 0.50, alpha: 1.0)),
        ("Rose Pink", SKColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1.0), SKColor(red: 0.50, green: 0.45, blue: 0.10, alpha: 1.0)),
        ("Crimson Red", SKColor(red: 0.7, green: 0.1, blue: 0.2, alpha: 1.0), SKColor(red: 0.30, green: 0.10, blue: 0.50, alpha: 1.0)),
        ("Teal", SKColor(red: 0.2, green: 0.7, blue: 0.6, alpha: 1.0), SKColor(red: 0.10, green: 0.50, blue: 0.35, alpha: 1.0)),
        ("Navy", SKColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1.0), SKColor(red: 0.50, green: 0.10, blue: 0.30, alpha: 1.0)),
        ("Forest Green", SKColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 1.0), SKColor(red: 0.50, green: 0.20, blue: 0.20, alpha: 1.0)),
        ("Gold", SKColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1.0), SKColor(red: 0.20, green: 0.40, blue: 0.50, alpha: 1.0)),
        ("Violet", SKColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0), SKColor(red: 0.35, green: 0.25, blue: 0.50, alpha: 1.0)),
        ("Magenta", SKColor(red: 0.8, green: 0.2, blue: 0.6, alpha: 1.0), SKColor(red: 0.45, green: 0.35, blue: 0.15, alpha: 1.0))
    ]
    
    // MARK: - UI Labels
    var levelHeadingLabel: SKLabelNode?
    var levelValueLabel: SKLabelNode?
    var scoreHeadingLabel: SKLabelNode?
    var scoreValueLabel: SKLabelNode?
    
    // MARK: - Table State
    var poolTableNodes: [SKNode] = []
    var blockTablePhysicsNodes: [SKNode] = []
    var blockFeltRect: CGRect?
    var blockPocketCenters: [CGPoint]?
    var blockPocketRadius: CGFloat?
    var blockCueBalls: [BlockBall] = []  // Changed: now supports multiple cue balls
    var feltManager: FeltManager?  // Strong reference to FeltManager for explosion holes
    
    // Level progression
    private var obstacleNodes: [SKNode] = []
    private var isTransitioningLevel: Bool = false
    
    // MARK: - Feature Flags
    let useBlockTablePrototype: Bool = true
    
    // MARK: - Cue Ball Controller
    private var cueBallController: CueBallController?
    
    // MARK: - Damage System
    var damageSystem: BallDamageSystem?  // Changed to internal for extension access

    // Global aiming (controls all cue balls at once)
    var isGlobalAiming: Bool = false
    var globalAimStartPoint: CGPoint = .zero
    var globalDragStart: CGPoint = .zero
    var globalCurrentLocation: CGPoint = .zero  // Track current touch location during drag
    let globalAimStartThreshold: CGFloat = 6.0


    // MARK: - Block ball sink handling (delegate method - implementation in extension)
    func blockBallDidSink(_ ball: BlockBall) {
        // Unregister from damage system
        damageSystem?.unregisterBall(ball)
        
        // Ignore ball sinks during level transitions
        guard !isTransitioningLevel else {
            print("⏭️ Ignoring ball sink during level transition")
            ball.removeFromParent()
            return
        }
        
        let kindString: String
        switch ball.ballKind {
        case .cue: kindString = "CUE"
        case .one: kindString = "ONE"
        case .two: kindString = "TWO"
        case .three: kindString = "THREE"
        case .four: kindString = "FOUR"
        case .five: kindString = "FIVE"
        case .six: kindString = "SIX"
        case .eight: kindString = "EIGHT"
        case .eleven: kindString = "ELEVEN"
        }
        print("🎱 blockBallDidSink called for \(kindString) ball")
        print("📊 Score before: \(gameStateManager.currentScore)")
        
        // Adjust score based on ball kind
        switch ball.ballKind {
        case .one, .two, .three, .four, .five, .six, .eight, .eleven:
            gameStateManager.addScore(1)
            
            let ballName: String
            switch ball.ballKind {
            case .one: ballName = "One"
            case .two: ballName = "Two"
            case .three: ballName = "Three"
            case .four: ballName = "Four"
            case .five: ballName = "Five"
            case .six: ballName = "Six"
            case .eight: ballName = "Eight"
            case .eleven: ballName = "Eleven"
            case .cue: ballName = "Cue" // Won't be reached but needed for exhaustiveness
            }
            
            print("✅ \(ballName) ball sank! Score +1")
            print("📊 Score after: \(gameStateManager.currentScore)")
            
            // Remove the ball immediately so it won't be counted
            ball.removeFromParent()
            
            // Check if any target balls (8-balls or 11-balls or two-balls or three-balls or four-balls) remain on the table (after removal)
            let remaining = remainingEnemyBallCount()
            print("🎱 Remaining target balls: \(remaining)")
            
            if remaining == 0 {
                print("🎉 Level Complete! All target balls sunk!")
                // Small delay to let sink animation finish
                let delay = SKAction.wait(forDuration: 0.3)
                let complete = SKAction.run { [weak self] in
                    self?.handleLevelComplete()
                }
                self.run(SKAction.sequence([delay, complete]))
            }
            
        case .cue:
            gameStateManager.addScore(-1)
            print("❌ Cue ball sank! Score -1")
            print("📊 Score after: \(gameStateManager.currentScore)")
            
            // Remove the cue ball from tracking array using centralized method
            removeCueBall(ball)
            
            // Only respawn if this was the LAST cue ball
            guard blockCueBalls.isEmpty else {
                print("⏭️ Skipping cue ball respawn - other cue balls still active (count: \(blockCueBalls.count))")
                return
            }
            
            // Cancel any existing respawn action
            removeAction(forKey: "respawnCueBall")
            
            // Respawn cue ball after delay if all balls are at rest
            let delay = SKAction.wait(forDuration: 1.0)
            let respawn = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // Double-check we're not transitioning levels
                guard !self.isTransitioningLevel else {
                    print("⏭️ Skipping cue ball respawn - level transitioning")
                    return
                }
                
                // Double-check there are still no cue balls (in case one spawned while waiting)
                guard self.blockCueBalls.isEmpty else {
                    print("⏭️ Skipping cue ball respawn - other cue balls spawned during wait")
                    return
                }
                
                // Wait for all balls to stop moving before respawning
                self.waitForAllBallsToRest {
                    print("🔄 All balls at rest, respawning cue ball...")
                    self.respawnBlockCueBallAtCenter()
                }
            }
            self.run(SKAction.sequence([delay, respawn]), withKey: "respawnCueBall")
        }
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        // Configure physics world for accurate collision detection
        physicsWorld.gravity = .zero
        physicsWorld.speed = 1.0
        
        // Initialize game state manager
        gameStateManager = GameStateManager()
        
        // Choose theme from color schemes and set global colors
        selectedColorSchemeIndex = Int.random(in: 0..<colorSchemes.count)
        let chosenScheme = colorSchemes[selectedColorSchemeIndex]
        
        // Set global theme colors
        StarfieldScene.ThemeColor1 = chosenScheme.color1  // Felt, title, level, score, logo
        StarfieldScene.ThemeColor2 = chosenScheme.color2  // Rails
        
        print("🎨 Using theme: \(chosenScheme.name)")
        print("   ThemeColor1 (felt/UI): \(StarfieldScene.ThemeColor1)")
        print("   ThemeColor2 (rails): \(StarfieldScene.ThemeColor2)")
        
        // Initialize table configuration from current theme
        tableConfig = TableConfiguration(randomSchemeIndex: selectedColorSchemeIndex)
        
        // Load or generate random seed
        loadOrGenerateRandomSeed()
        
        // Initialize seeded random generator
        random = SeededRandom(seed: randomSeed)
        
        // Calculate center and max distance
        centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        maxDistanceFromCenter = sqrt(pow(size.width / 2, 2) + pow(size.height / 2, 2))
        
        // Create optimized star texture
        createStarTexture()
        
        // Create SpacePool logo (invisible initially)
        setupSpacePoolLogo()
        
        // Hide logo initially
        for block in logoBlocks {
            block.alpha = 0
        }
        
        // Start title animation sequence
        startTitleAnimation()
        
        // Pre-populate with initial stars
        populateInitialStars()
        
        // Setup physics adjuster UI
        setupPhysicsAdjusterUI()
        
        // Initialize damage system
        setupDamageSystem()
    }
    
    // MARK: - Physics Adjuster Setup
    private func setupPhysicsAdjusterUI() {
        physicsAdjusterUI = PhysicsAdjusterUI(scene: self)
        
        physicsAdjusterUI?.onReset { [weak self] in
            guard let self = self else { return }
            // Reset stored game progress and other defaults
            self.resetAllProgressAndDefaults()
        }
        
        physicsAdjusterUI?.onRestart { [weak self] in
            guard let self = self else { return }
            // Restart the game: reset level and score, return to title
            self.restartGame()
        }
        
        physicsAdjusterUI?.createToggleButton()
        
        // Apply saved settings after initialization
        // Note: This will be called again after balls are spawned to ensure they get the settings
        physicsAdjusterUI?.applyLoadedSettings()
    }
    
    // MARK: - Star Texture Creation
    private func createStarTexture() {
        // Create a simple 8x8 pixel texture for stars
        // This texture will be reused for all stars with color tinting
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Draw a simple white square (will be tinted with color later)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        
        starTexture = SKTexture(image: image)
        starTexture?.filteringMode = .nearest  // Pixel-perfect rendering
        
        print("⭐ Created optimized star texture atlas")
    }
    
    // MARK: - Damage System Setup
    private func setupDamageSystem() {
        var config = BallDamageSystem.DamageConfig()
        config.startingHP = 100
        config.cueBallCollisionDamage = 20
        config.sameTypeDamage = 4  // Cue-cue: 4 base → 1 after armor (100 hits)
        config.cueBallArmor = 0.75
        config.minDamageImpulse = 10  // Lower for easier triggering
        config.showHealthBars = false  // Hidden by default - can be toggled
        config.destructionEffect = .crumble  // Use crumble animation for defeated balls
        
        damageSystem = BallDamageSystem(scene: self, config: config)
        damageSystem?.delegate = self  // Set delegate to receive notifications
        
        // Set physics contact delegate
        physicsWorld.contactDelegate = self
        
        print("⚔️ Damage system initialized and ready!")
    }
    
    private func resetAllProgressAndDefaults() {
        // Reset game state
        gameStateManager.resetProgress()
        
        // Clear other stored variables to defaults
        let defaults = UserDefaults.standard
        // Known keys used in this project
        defaults.removeObject(forKey: "StarfieldRandomSeed")
        defaults.removeObject(forKey: "CurrentLevel")
        defaults.removeObject(forKey: "CurrentScore")
        
        // Synchronize
        defaults.synchronize()
        
        // Teardown current level and return to title screen
        teardownCurrentLevel()
        
        // Clear UI labels if present
        levelHeadingLabel?.removeFromParent(); levelHeadingLabel = nil
        levelValueLabel?.removeFromParent(); levelValueLabel = nil
        scoreHeadingLabel?.removeFromParent(); scoreHeadingLabel = nil
        scoreValueLabel?.removeFromParent(); scoreValueLabel = nil
        
        // Remove existing logo blocks and rebuild title/logo
        for block in logoBlocks { block.removeFromParent() }
        logoBlocks.removeAll()
        
        // Re-pick a theme
        selectedColorSchemeIndex = Int.random(in: 0..<colorSchemes.count)
        let chosenScheme = colorSchemes[selectedColorSchemeIndex]
        
        // Update global theme colors
        StarfieldScene.ThemeColor1 = chosenScheme.color1
        StarfieldScene.ThemeColor2 = chosenScheme.color2
        
        print("🎨 New theme: \(chosenScheme.name)")
        
        // Rebuild and start title animation
        setupSpacePoolLogo()
        for block in logoBlocks { block.alpha = 0 }
        startTitleAnimation()
        
        print("🔁 Reset complete: returned to title screen")
    }
    
    private func restartGame() {
        // Reset game state to level 1 and score 0
        gameStateManager.resetProgress()
        
        // Don't clear physics settings - only reset game progress
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "StarfieldRandomSeed")
        defaults.removeObject(forKey: "CurrentLevel")
        defaults.removeObject(forKey: "CurrentScore")
        defaults.synchronize()
        
        // Teardown current level and return to title screen
        teardownCurrentLevel()
        
        // Clear UI labels if present
        levelHeadingLabel?.removeFromParent(); levelHeadingLabel = nil
        levelValueLabel?.removeFromParent(); levelValueLabel = nil
        scoreHeadingLabel?.removeFromParent(); scoreHeadingLabel = nil
        scoreValueLabel?.removeFromParent(); scoreValueLabel = nil
        
        // Remove existing logo blocks and rebuild title/logo
        for block in logoBlocks { block.removeFromParent() }
        logoBlocks.removeAll()
        
        // Keep the current theme (don't re-pick)
        // This maintains visual consistency during restart
        
        // Rebuild and start title animation
        setupSpacePoolLogo()
        for block in logoBlocks { block.alpha = 0 }
        startTitleAnimation()
        
        print("🔄 Game restarted: returned to title screen (level 1, score 0)")
    }
    
    // Helper function to apply physics changes to all active balls
    func applyPhysicsToAllBalls() {
        for node in children {
            if let ball = node as? BlockBall, let body = ball.physicsBody {
                // Don't override mass for 3balls or 4balls - they have custom mass
                // 3ball: 5.1 (30× heavier), 4ball: 17.0 (100× heavier, immovable)
                if ball.ballKind != .three && ball.ballKind != .four {
                    body.mass = ballMass
                }
                body.friction = ballFriction
                body.linearDamping = ballLinearDamping
                body.angularDamping = ballAngularDamping
                body.restitution = ballRestitution
            }
        }
        
        // Apply persisted settings from overlay UI
        physicsAdjusterUI?.applySettingsToAllBalls()
    }
    
    // Update max impulse for all balls (called from UI)
    func updateMaxImpulseForAllBalls(_ newMaxImpulse: CGFloat) {
        for node in children {
            if let ball = node as? BlockBall {
                ball.maxImpulse = newMaxImpulse
            }
        }
    }
    
    // Update 3ball mass (called from UI)
    func update3BallMass(multiplier: CGFloat) {
        let baseMass: CGFloat = 0.17
        let newMass = baseMass * multiplier
        
        for node in children {
            if let ball = node as? BlockBall, ball.ballKind == .three, let body = ball.physicsBody {
                body.mass = newMass
            }
        }
    }
    
    // Display current cue ball speed on screen
    private func displayCueBallSpeed(_ speed: CGFloat) {
        if cueBallSpeedLabel == nil {
            let label = SKLabelNode(fontNamed: "Courier-Bold")
            label.fontSize = 14
            label.fontColor = StarfieldScene.ThemeColor1
            label.zPosition = 2000
            // Position near top-center; adjust as needed
            label.position = CGPoint(x: centerPoint.x, y: size.height - 24)
            addChild(label)
            cueBallSpeedLabel = label
        }
        cueBallSpeedLabel?.text = "CUE SPEED: \(Int(speed))"
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Try physics adjuster UI first
        if physicsAdjusterUI?.handleTouchBegan(touch) == true {
            return
        }
        
        // Start global aiming for all cue balls regardless of where the touch begins
        if let touch = touches.first {
            let loc = touch.location(in: self)
            isGlobalAiming = true
            globalDragStart = loc
            // Do not show any visuals yet; wait until drag exceeds threshold
            for ball in blockCueBalls {
                ball.beginGlobalAim()
            }
        }
        
        // Only used to skip the title animation
        skipTitleAnimation()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Try physics adjuster UI first
        if physicsAdjusterUI?.handleTouchMoved(touch) == true {
            return
        }
        
        if isGlobalAiming, let touch = touches.first {
            let loc = touch.location(in: self)
            globalCurrentLocation = loc  // Track current touch location
            let dx = loc.x - globalDragStart.x
            let dy = loc.y - globalDragStart.y
            let distance = hypot(dx, dy)
            if distance >= globalAimStartThreshold {
                let dir = CGVector(dx: dx, dy: dy)
                for ball in blockCueBalls {
                    ball.updateGlobalAim(direction: dir, magnitude: distance)
                }
            } else {
                // Below threshold: keep visuals hidden
                for ball in blockCueBalls {
                    // ensure any stray visuals are cleared
                    ball.cancelGlobalAim()
                    ball.beginGlobalAim()
                }
            }
            return
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Try physics adjuster UI first
        if physicsAdjusterUI?.handleTouchEnded(touch) == true {
            return
        }
        
        if isGlobalAiming, let touch = touches.first {
            let loc = touch.location(in: self)
            let dx = loc.x - globalDragStart.x
            let dy = loc.y - globalDragStart.y
            let distance = hypot(dx, dy)
            if distance >= globalAimStartThreshold {
                for ball in blockCueBalls {
                    ball.endGlobalAimApplyShot()
                }
            } else {
                for ball in blockCueBalls {
                    ball.cancelGlobalAim()
                }
            }
            isGlobalAiming = false
            return
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGlobalAiming {
            for ball in blockCueBalls { ball.cancelGlobalAim() }
            isGlobalAiming = false
            return
        }
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        physicsAdjusterUI?.updateForSizeChange()
    }
    
    func tableHeight(from sceneSize: CGSize) -> CGFloat {
        let screenSizeToUse = min(sceneSize.width, sceneSize.height) * 0.7
        return screenSizeToUse
    }

    func displayLevelAndScore() {
        // Remove any existing labels first to prevent duplicates
        levelHeadingLabel?.removeFromParent()
        levelValueLabel?.removeFromParent()
        scoreHeadingLabel?.removeFromParent()
        scoreValueLabel?.removeFromParent()
        
        // Calculate block table bounds
        let limitingSide = min(size.height, size.width / 1.7)
        let screenSizeToUse = limitingSide * 0.95
        let tableWidth: CGFloat = screenSizeToUse * 1.7
        let tableHeight: CGFloat = screenSizeToUse
        
        // Calculate left and right edges of the table
        let tableLeftEdge = centerPoint.x - tableWidth / 2
        let tableRightEdge = centerPoint.x + tableWidth / 2
        let tableTopEdge = centerPoint.y + tableHeight / 2
        
        // Spacing from table edge
        let horizontalSpacing: CGFloat = 40
        let verticalOffset: CGFloat = 60  // Lower from top of table
        let verticalSpacing: CGFloat = 25  // Space between heading and value
        
        // LEVEL - positioned to the left of the table
        let levelX = tableLeftEdge - horizontalSpacing
        let levelY = tableTopEdge - verticalOffset
        
        // Create level heading label
        levelHeadingLabel = SKLabelNode(fontNamed: "Courier-Bold")
        if let heading = levelHeadingLabel {
            heading.text = "LEVEL"
            heading.fontSize = 16
            heading.fontColor = StarfieldScene.ThemeColor1
            heading.position = CGPoint(x: levelX, y: levelY)
            heading.horizontalAlignmentMode = .center
            heading.verticalAlignmentMode = .top
            heading.zPosition = 100
            addChild(heading)
        }
        
        // Create level value label (centered below heading)
        levelValueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        if let value = levelValueLabel {
            value.text = "\(gameStateManager.currentLevel)"
            value.fontSize = 28
            value.fontColor = StarfieldScene.ThemeColor1
            value.position = CGPoint(x: levelX, y: levelY - verticalSpacing)
            value.horizontalAlignmentMode = .center
            value.verticalAlignmentMode = .top
            value.zPosition = 100
            addChild(value)
        }
        
        // SCORE - positioned to the right of the table
        let scoreX = tableRightEdge + horizontalSpacing
        let scoreY = tableTopEdge - verticalOffset
        
        // Create score heading label
        scoreHeadingLabel = SKLabelNode(fontNamed: "Courier-Bold")
        if let heading = scoreHeadingLabel {
            heading.text = "SCORE"
            heading.fontSize = 16
            heading.fontColor = StarfieldScene.ThemeColor1
            heading.position = CGPoint(x: scoreX, y: scoreY)
            heading.horizontalAlignmentMode = .center
            heading.verticalAlignmentMode = .top
            heading.zPosition = 100
            addChild(heading)
        }
        
        // Create score value label (centered below heading)
        scoreValueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        if let value = scoreValueLabel {
            value.text = "\(gameStateManager.currentScore)"
            value.fontSize = 28
            value.fontColor = StarfieldScene.ThemeColor1
            value.position = CGPoint(x: scoreX, y: scoreY - verticalSpacing)
            value.horizontalAlignmentMode = .center
            value.verticalAlignmentMode = .top
            value.zPosition = 100
            addChild(value)
        }
        
        // Fade in labels then load level content
        let labels: [SKNode] = [levelHeadingLabel, levelValueLabel, scoreHeadingLabel, scoreValueLabel].compactMap { $0 }
        for node in labels { node.alpha = 0 }
        let fadeIn = SKAction.fadeIn(withDuration: 0.35)
        let group = SKAction.group(labels.map { _ in fadeIn })
        // Run the fade on a dummy node to get a single completion, or run on one label
        levelHeadingLabel?.run(fadeIn)
        levelValueLabel?.run(fadeIn)
        scoreHeadingLabel?.run(fadeIn)
        scoreValueLabel?.run(fadeIn, completion: { [weak self] in
            self?.loadCurrentLevel()
        })
    }
    
    private func loadCurrentLevel() {
        // Determine current level number
        let levelNumber = gameStateManager.currentLevel
        print("🎮 Loading current level: \(levelNumber)")
        
        // Build the table
        self.drawBlockTable()
        
        // Initialize cue ball controller if needed
        if cueBallController == nil, let feltRect = blockFeltRect {
            cueBallController = CueBallController(scene: self, tableFrameRect: feltRect)
            print("🎮 CueBallController initialized")
        }
        
        // Perform entrance transition (fade in the new table)
        performEntranceTransition { [weak self] in
            guard let self = self else { return }
            print("✨ Level \(levelNumber) entrance transition complete!")
            
            // Place balls AFTER the entrance transition completes
            self.placeItemsForCurrentLevel()
        }
    }
    
    private func performEntranceTransition(completion: @escaping () -> Void) {
        print("🎬 Starting entrance transition (fade in)")
        
        // Set all table nodes to alpha 0 initially
        for node in poolTableNodes {
            node.alpha = 0
        }
        
        // Fade in all table-related nodes
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        
        // Keep track of how many nodes need to complete
        var completionCount = 0
        let totalNodes = poolTableNodes.count
        
        guard totalNodes > 0 else {
            completion()
            return
        }
        
        for node in poolTableNodes {
            node.run(fadeIn) {
                completionCount += 1
                if completionCount == totalNodes {
                    completion()
                }
            }
        }
    }
    
    private func placeItemsForCurrentLevel() {
        let levelNumber = gameStateManager.currentLevel
        let difficulty = gameStateManager.currentDifficulty
        
        // Progressive ball introduction based on difficulty:
        // Difficulty 0-9: Only 8-balls
        // Difficulty 10-19: 8-balls + 3-balls
        // Difficulty 20-29: 8-balls + 3-balls + 2-balls
        // Difficulty 30-39: 8-balls + 3-balls + 2-balls + 11-balls
        // Difficulty 40+: All ball types including 4-balls
        
        // Calculate total ball count (scales with level)
        let baseCount = 1 + (levelNumber - 1) / 3
        let totalBallCount = max(1, baseCount)
        
        // Determine which ball types are available at this difficulty
        let has8Ball = true  // Always available
        let has3Ball = difficulty >= 10
        let has2Ball = difficulty >= 20
        let has11Ball = difficulty >= 30
        let has4Ball = difficulty >= 40
        
        // Calculate composition percentages based on difficulty tier
        var eightBallCount = 0
        var threeBallCount = 0
        var twoBallCount = 0
        var elevenBallCount = 0
        var fourBallCount = 0
        
        if difficulty < 10 {
            // Difficulty 0-9: Only 8-balls
            eightBallCount = totalBallCount
        } else if difficulty < 20 {
            // Difficulty 10-19: Mostly 8-balls, some 3-balls
            threeBallCount = max(1, totalBallCount / 4)
            eightBallCount = totalBallCount - threeBallCount
        } else if difficulty < 30 {
            // Difficulty 20-29: 8-balls, 3-balls, and 2-balls
            threeBallCount = max(1, totalBallCount / 4)
            twoBallCount = max(1, totalBallCount / 5)
            eightBallCount = totalBallCount - threeBallCount - twoBallCount
        } else if difficulty < 40 {
            // Difficulty 30-39: Mix of 8, 3, 2, and 11 balls
            threeBallCount = max(1, totalBallCount / 4)
            twoBallCount = max(1, totalBallCount / 5)
            elevenBallCount = max(1, totalBallCount / 4)
            eightBallCount = totalBallCount - threeBallCount - twoBallCount - elevenBallCount
        } else {
            // Difficulty 40+: All ball types including 4-balls
            threeBallCount = max(1, totalBallCount / 5)
            twoBallCount = max(1, totalBallCount / 6)
            elevenBallCount = max(1, totalBallCount / 5)
            fourBallCount = max(1, totalBallCount / 8)  // 4-balls are rare and powerful
            eightBallCount = totalBallCount - threeBallCount - twoBallCount - elevenBallCount - fourBallCount
        }
        
        // Ensure at least 1 ball
        if eightBallCount + threeBallCount + twoBallCount + elevenBallCount + fourBallCount == 0 {
            eightBallCount = 1
        }
        
        print("🎱 Level \(levelNumber) (Difficulty \(difficulty)): Spawning \(eightBallCount) 8-ball(s), \(threeBallCount) 3-ball(s), \(twoBallCount) 2-ball(s), \(elevenBallCount) 11-ball(s), \(fourBallCount) 4-ball(s)")
        
        // Spawn cue ball at center
        self.spawnBlockCueBallAtCenter()
        
        // Spawn 8-balls
        for i in 0..<eightBallCount {
            if let pos = randomSpawnPoint(minClearance: 30) {
                let ball = BlockBall(
                    kind: .eight,
                    position: pos,
                    in: self,
                    feltRect: self.blockFeltRect ?? .zero,
                    pocketCenters: self.blockPocketCenters ?? [],
                    pocketRadius: self.blockPocketRadius ?? 0
                )
                if ball.parent == nil { addChild(ball) }
                damageSystem?.registerBall(ball)
                print("🎱 Level \(levelNumber): 8-ball #\(i+1) spawned at \(pos)")
            }
        }
        
        // Spawn 3-balls (200 HP, heavy)
        for i in 0..<threeBallCount {
            if let pos = randomSpawnPoint(minClearance: 30) {
                let ball = BlockBall(
                    kind: .three,
                    position: pos,
                    in: self,
                    feltRect: self.blockFeltRect ?? .zero,
                    pocketCenters: self.blockPocketCenters ?? [],
                    pocketRadius: self.blockPocketRadius ?? 0
                )
                if ball.parent == nil { addChild(ball) }
                damageSystem?.registerBall(ball, customHP: 200)
                print("🔴 Level \(levelNumber): 3-ball #\(i+1) spawned at \(pos) with 200 HP")
            }
        }
        
        // Spawn 2-balls (20 HP, splits into 2 cue balls on death)
        for i in 0..<twoBallCount {
            if let pos = randomSpawnPoint(minClearance: 30) {
                let ball = BlockBall(
                    kind: .two,
                    position: pos,
                    in: self,
                    feltRect: self.blockFeltRect ?? .zero,
                    pocketCenters: self.blockPocketCenters ?? [],
                    pocketRadius: self.blockPocketRadius ?? 0
                )
                if ball.parent == nil { addChild(ball) }
                damageSystem?.registerBall(ball, customHP: 20)
                print("🔵 Level \(levelNumber): 2-ball #\(i+1) spawned at \(pos) with 20 HP")
            }
        }
        
        // Spawn 11-balls (striped, takes 3x damage)
        for i in 0..<elevenBallCount {
            if let pos = randomSpawnPoint(minClearance: 30) {
                let ball = BlockBall(
                    kind: .eleven,
                    position: pos,
                    in: self,
                    feltRect: self.blockFeltRect ?? .zero,
                    pocketCenters: self.blockPocketCenters ?? [],
                    pocketRadius: self.blockPocketRadius ?? 0
                )
                if ball.parent == nil { addChild(ball) }
                damageSystem?.registerBall(ball)
                print("⚪ Level \(levelNumber): 11-ball #\(i+1) spawned at \(pos)")
            }
        }
        
        // Spawn 4-balls (20 HP, immovable, pulse damage)
        for i in 0..<fourBallCount {
            if let pos = randomSpawnPoint(minClearance: 30) {
                let ball = BlockBall(
                    kind: .four,
                    position: pos,
                    in: self,
                    feltRect: self.blockFeltRect ?? .zero,
                    pocketCenters: self.blockPocketCenters ?? [],
                    pocketRadius: self.blockPocketRadius ?? 0
                )
                if ball.parent == nil { addChild(ball) }
                damageSystem?.registerBall(ball, customHP: 20)
                print("🟣 Level \(levelNumber): 4-ball #\(i+1) spawned at \(pos) with 20 HP")
            }
        }
        
        // Apply physics settings to all balls
        applyPhysicsToAllBalls()
        
        print("✅ Level \(levelNumber) setup complete!")
    }
    
    private func loadOrGenerateRandomSeed() {
        let defaults = UserDefaults.standard
        let seedKey = "StarfieldRandomSeed"
        
        if let savedSeed = defaults.object(forKey: seedKey) as? UInt64 {
            // Use existing seed
            randomSeed = savedSeed
            print("🎲 Using saved random seed: \(randomSeed)")
        } else {
            // Generate new seed
            randomSeed = UInt64.random(in: UInt64.min...UInt64.max)
            defaults.set(randomSeed, forKey: seedKey)
            print("🎲 Generated new random seed: \(randomSeed)")
        }
    }
    
    private func startTitleAnimation() {
        titleAnimationManager = TitleAnimationManager(logoBlocks: logoBlocks)
        titleAnimationManager?.startAnimation { [weak self] in
            self?.showGameUI()
        }
    }
    
    private func skipTitleAnimation() {
        // Don't skip if game UI is already displayed
        guard levelHeadingLabel == nil || scoreHeadingLabel == nil else { return }
        
        titleAnimationManager?.skipAnimation()
    }
    
    private func showGameUI() {
        // Show level and score UI
        displayLevelAndScore()
        // Wire labels to game state for live updates
        gameStateManager.levelValueLabel = levelValueLabel
        gameStateManager.scoreValueLabel = scoreValueLabel
    }
    
    private func setupSpacePoolLogo() {
        // Fancy italicized sci-fi pixel art for "SpacePool"
        // Each letter is designed in a 5x7 grid with italic slant, using 10x10 pixel blocks
        let blockSize: CGFloat = 10
        let letterSpacing: CGFloat = blockSize * 0.5 // Tighter spacing
        
        // Log theme name
        let schemeName = colorSchemes[selectedColorSchemeIndex].name
        print("🎨 Setting up logo with theme: \(schemeName)")
        // Use global ThemeColor1 for logo
        
        // Letter patterns (1 = block, 0 = empty) - Fancy Italic style with slant!
        // S - Italic with decorative curves
        let letterS: [[Int]] = [
            [0,0,1,1,1],
            [0,1,0,0,1],
            [0,1,0,0,0],
            [0,0,1,1,0],
            [0,0,0,1,0],
            [1,0,0,1,0],
            [0,1,1,0,0]
        ]
        
        // P - Italic with flourish
        let letterP: [[Int]] = [
            [0,1,1,1,0],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,1,1,0],
            [0,1,0,0,0],
            [1,0,0,0,0],
            [1,0,0,0,0]
        ]
        
        // A - Italic angular
        let letterA: [[Int]] = [
            [0,0,1,0,0],
            [0,1,0,1,0],
            [0,1,0,1,0],
            [0,1,1,1,0],
            [0,1,0,1,0],
            [1,0,0,0,1],
            [1,0,0,0,1]
        ]
        
        // C - Italic curve
        let letterC: [[Int]] = [
            [0,0,1,1,0],
            [0,1,0,0,1],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [1,0,0,0,1],
            [0,1,1,1,0]
        ]
        
        // E - Italic with serifs
        let letterE: [[Int]] = [
            [0,1,1,1,1],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [0,1,1,1,0],
            [0,1,0,0,0],
            [1,0,0,0,0],
            [1,1,1,1,1]
        ]
        
        // P (second one)
        let letterP2: [[Int]] = [
            [0,1,1,1,0],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,1,1,0],
            [0,1,0,0,0],
            [1,0,0,0,0],
            [1,0,0,0,0]
        ]
        
        // O - Italic oval
        let letterO: [[Int]] = [
            [0,0,1,1,0],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [1,0,0,0,1],
            [0,1,1,1,0]
        ]
        
        // O (second one)
        let letterO2: [[Int]] = [
            [0,0,1,1,0],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [0,1,0,0,1],
            [1,0,0,0,1],
            [0,1,1,1,0]
        ]
        
        // L - Italic with extended base
        let letterL: [[Int]] = [
            [0,1,0,0,0],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [0,1,0,0,0],
            [1,0,0,0,0],
            [1,1,1,1,1]
        ]
        
        // Array of letters for "SPACEPOOL"
        let letters = [letterS, letterP, letterA, letterC, letterE, letterP2, letterO, letterO2, letterL]
        
        // Calculate total width
        let letterWidth = 5 * blockSize
        let totalLetters = letters.count
        let totalSpacing = letterSpacing * CGFloat(totalLetters - 1)
        let totalWidth = CGFloat(totalLetters) * letterWidth + totalSpacing
        
        // Start position (centered horizontally, positioned in upper portion of screen)
        let startX = centerPoint.x - (totalWidth / 2)
        let startY = centerPoint.y + 100 // Position above center
        
        var currentX = startX
        
        // Draw each letter with italic offset
        for letter in letters {
            for (row, rowData) in letter.enumerated() {
                // Create italic slant by offsetting each row
                let italicOffset = CGFloat(7 - row) * 1.5 // Creates the slant effect
                
                for (col, value) in rowData.enumerated() {
                    if value == 1 {
                        let block = SKSpriteNode(color: StarfieldScene.ThemeColor1, size: CGSize(width: blockSize, height: blockSize))
                        
                        // Calculate position with italic offset
                        let x = currentX + CGFloat(col) * blockSize + italicOffset
                        let y = startY - CGFloat(row) * blockSize
                        
                        block.position = CGPoint(x: x, y: y)
                        block.zPosition = 60 // Above stars but below seed label
                        block.texture?.filteringMode = SKTextureFilteringMode.nearest
                        
                        addChild(block)
                        logoBlocks.append(block)
                    }
                }
            }
            
            // Move to next letter position
            currentX += letterWidth + letterSpacing
        }
    }
    
    private func populateInitialStars() {
        for _ in 0..<initialStarCount {
            // Distribute stars more evenly across the entire screen
            // 30% close to center (0-40% distance)
            // 40% mid-range (40-70% distance)
            // 30% far out (70-100% distance)
            let randomValue = random.nextDouble()
            let distanceRatio: Double
            
            if randomValue < 0.3 {
                distanceRatio = random.nextDouble(in: 0...0.4)
            } else if randomValue < 0.7 {
                distanceRatio = random.nextDouble(in: 0.4...0.7)
            } else {
                distanceRatio = random.nextDouble(in: 0.7...1.0)
            }
            
            let angle = random.nextDouble(in: 0...(2 * .pi))
            let distance = distanceRatio * maxDistanceFromCenter
            
            let x = centerPoint.x + CGFloat(cos(angle) * distance)
            let y = centerPoint.y + CGFloat(sin(angle) * distance)
            
            spawnStar(at: CGPoint(x: x, y: y), isInitial: true, angle: angle)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        
        // Clamp delta time to prevent large physics steps that can cause tunneling
        let rawDeltaTime = currentTime - lastUpdateTime
        let deltaTime = min(rawDeltaTime, 1.0 / 30.0)  // Cap at ~33ms (30 FPS minimum)
        lastUpdateTime = currentTime
        totalElapsedTime += deltaTime
        
        // Always update stars (background animation)
        timeSinceLastSpawn += deltaTime
        if timeSinceLastSpawn >= spawnInterval && stars.count < maxStars {
            timeSinceLastSpawn = 0
            spawnStar(at: centerPoint, isInitial: false)
        }
        updateStars(deltaTime: deltaTime)
        
        // Skip expensive gameplay updates during level transitions
        if isTransitioningLevel {
            return
        }

        cueBallController?.update(deltaTime: deltaTime)
        
        // Update damage system
        damageSystem?.update(deltaTime: deltaTime)
        
        // Update all BlockBall instances (cue and eight balls) so they can sink and animate properly
        for case let ball as BlockBall in children {
            ball.update(deltaTime: deltaTime)
        }
    }
    
    // MARK: - Physics Contact Delegate
    
    func didBegin(_ contact: SKPhysicsContact) {
        // Find BlockBall nodes
        var ball1: BlockBall?
        var ball2: BlockBall?
        var isRailContact = false
        
        if let node = contact.bodyA.node as? BlockBall {
            ball1 = node
            // Check if bodyB is a rail (category 0x1 << 1)
            if contact.bodyB.categoryBitMask == (0x1 << 1) {
                isRailContact = true
            }
        }
        
        if let node = contact.bodyB.node as? BlockBall {
            ball2 = node
            // Check if bodyA is a rail
            if contact.bodyA.categoryBitMask == (0x1 << 1) {
                isRailContact = true
            }
        }
        

        // Process collision if both are BlockBalls
        if let ball1 = ball1, let ball2 = ball2 {
            // Let the damage system handle all collision damage logic
            damageSystem?.handleCollision(
                between: ball1,
                and: ball2,
                impulse: contact.collisionImpulse
            )
        }
    }
    
    // MARK: - Ball Damage System Delegate
    
    func ballDamageSystem(_ system: BallDamageSystem, didDestroyBall ball: BlockBall) {
        print("🎯 Damage system notified: \(ball.ballKind) ball was destroyed")
        
        // If this is a cue ball, remove it from tracking
        if ball.ballKind == .cue {
            removeCueBall(ball)
            print("🗑 Removed destroyed cue ball from tracking (total: \(blockCueBalls.count))")
        }
        
        // Award points for destroying a ball (skip cue balls)
        if ball.ballKind != .cue {
            let points = 1
            gameStateManager.addScore(points)
            print("⭐ Awarded \(points) point(s) for destroying \(ball.ballKind) ball! Score: \(gameStateManager.currentScore)")
        }
    }
    
    func ballDamageSystemDidClearAllTargets(_ system: BallDamageSystem) {
        print("🎉 Damage system notified: All target balls cleared!")
        
        // Trust the damage system - it has the authoritative count
        // The scene's children might still have balls that are fading out
        print("🎊 Level complete! Triggering transition...")
        
        // Small delay to let animations finish
        let delay = SKAction.wait(forDuration: 0.5)
        let complete = SKAction.run { [weak self] in
            self?.handleLevelComplete()
        }
        self.run(SKAction.sequence([delay, complete]))
    }
    
    func ballDamageSystemShouldRespawnCueBall(_ system: BallDamageSystem) {
        print("🔄 Damage system requested cue ball respawn")
        
        // Only respawn if there are NO cue balls left
        guard blockCueBalls.isEmpty else {
            print("⏭️ Skipping cue ball respawn - other cue balls still active (count: \(blockCueBalls.count))")
            return
        }
        
        // Cancel any existing respawn action to prevent duplicates
        removeAction(forKey: "respawnCueBall")
        
        // Wait for all balls to rest before respawning
        let delay = SKAction.wait(forDuration: 1.0)
        let respawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            
            // Double-check we're not transitioning levels
            guard !self.isTransitioningLevel else {
                print("⏭️ Skipping cue ball respawn - level transitioning")
                return
            }
            
            // Double-check there are still no cue balls (in case one spawned while waiting)
            guard self.blockCueBalls.isEmpty else {
                print("⏭️ Skipping cue ball respawn - other cue balls spawned during wait")
                return
            }
            
            self.waitForAllBallsToRest {
                print("🔄 All balls at rest, respawning cue ball after damage destruction...")
                self.respawnBlockCueBallAtCenter()
            }
        }
        self.run(SKAction.sequence([delay, respawn]), withKey: "respawnCueBall")
    }
    
    private func spawnStar(at position: CGPoint, isInitial: Bool, angle: Double? = nil) {
        // Check for special event trigger (only for non-initial stars)
        var triggeredEvent: SpecialEvent? = nil
        if !isInitial && random.nextDouble() < specialEventOdds {
            triggeredEvent = triggerRandomSpecialEvent()
        }
        
        // Determine if this is a supernova (only if supernova event was triggered)
        let isSupernova = (triggeredEvent == .supernova)
        
        // Skip spawning this star if any special event was triggered
        // (supernova is spawned manually, comet doesn't need a star)
        if triggeredEvent != nil {
            return
        }
        
        // Create sprite with optimized texture
        let sprite: SKSpriteNode
        if let texture = starTexture {
            sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: minSize, height: minSize)
        } else {
            // Fallback to color-based sprite if texture isn't ready
            sprite = SKSpriteNode(color: .white, size: CGSize(width: minSize, height: minSize))
        }
        
        sprite.position = position
        sprite.zPosition = 1
        
        // Make diamond shape for supernovas
        if false {  // Never true now - removed supernova logic from regular spawning
            sprite.zRotation = .pi / 4  // Rotate 45 degrees to make diamond
        }
        
        // Disable antialiasing for pixel-perfect rendering
        sprite.texture?.filteringMode = .nearest
        
        // Set initial alpha (no supernovas in regular spawning)
        if isInitial {
            let distanceFromCenter = sqrt(pow(position.x - centerPoint.x, 2) +
                                        pow(position.y - centerPoint.y, 2))
            let normalizedDistance = distanceFromCenter / maxDistanceFromCenter
            
            if normalizedDistance < visibilityThreshold {
                sprite.alpha = 0
            } else if normalizedDistance < visibilityThreshold + fadeInRange {
                let fadeProgress = (normalizedDistance - visibilityThreshold) / fadeInRange
                sprite.alpha = fadeProgress
            } else {
                sprite.alpha = 1.0
            }
        } else {
            sprite.alpha = 0
        }
        
        // Determine color and apply tinting
        let color = selectStarColor(isSupernova: false)
        sprite.color = color
        sprite.colorBlendFactor = 1.0  // Full color tinting
        
        // Calculate velocity
        let starAngle = angle ?? random.nextDouble(in: 0...(2 * .pi))
        let speed = random.nextDouble(in: minSpeed...maxSpeed)
        let vx = cos(starAngle) * speed
        let vy = sin(starAngle) * speed
        let velocity = CGVector(dx: vx, dy: vy)
        
        // Twinkle properties (no supernovas in regular spawning)
        let shouldTwinkle = random.nextDouble() < twinklePercentage
        let twinkleDuration = random.nextDouble(in: 0.3...0.8)
        let minTwinkleWait = random.nextDouble(in: 0.5...1.5)
        let maxTwinkleWait = random.nextDouble(in: 2.0...4.0)
        let minAlpha = random.nextDouble(in: 0.15...0.35)
        
        // Growth multiplier
        let growthMultiplier = random.nextDouble(in: minGrowthMultiplier...maxGrowthMultiplier)
        
        // Create star object (no supernovas in regular spawning)
        let star = Star(
            sprite: sprite,
            velocity: velocity,
            growthMultiplier: growthMultiplier,
            baseSpeed: speed,
            angle: starAngle,
            shouldTwinkle: shouldTwinkle,
            twinkleDuration: twinkleDuration,
            minTwinkleWait: minTwinkleWait,
            maxTwinkleWait: maxTwinkleWait,
            minAlpha: minAlpha,
            isSupernova: false,
            supernovaExplosionDistance: 0,
            isInitialStar: isInitial
        )
        
        stars.append(star)
        addChild(sprite)
        
        // Start twinkling if applicable
        if shouldTwinkle {
            scheduleTwinkle(for: star)
        }
    }
    
    @discardableResult
    private func triggerRandomSpecialEvent() -> SpecialEvent {
        // Choose a random special event
        let allEvents = SpecialEvent.allCases
        let eventIndex = random.nextInt(in: 0...(allEvents.count - 1))
        let event = allEvents[eventIndex]
        
        print("⭐ SPECIAL EVENT triggered! Type: \(event.name)")
        
        // Trigger the appropriate event
        switch event {
        case .supernova:
            // Spawn a supernova at a random position on screen
            spawnManualSupernova()
            return .supernova
            
        case .comet:
            // Spawn comet immediately
            spawnComet()
            return .comet
        }
    }
    
    private func spawnManualSupernova() {
        // Spawn a supernova closer to center for longer visibility
        let randomAngle = random.nextDouble(in: 0...(2 * .pi))
        let randomDistance = random.nextDouble(in: 0.05...0.25) * maxDistanceFromCenter  // Much closer to center
        
        let x = centerPoint.x + CGFloat(cos(randomAngle) * randomDistance)
        let y = centerPoint.y + CGFloat(sin(randomAngle) * randomDistance)
        
        // Create sprite with optimized texture
        let sprite: SKSpriteNode
        if let texture = starTexture {
            sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: minSize, height: minSize)
        } else {
            sprite = SKSpriteNode(color: .white, size: CGSize(width: minSize, height: minSize))
        }
        sprite.position = CGPoint(x: x, y: y)
        sprite.zPosition = 1
        sprite.zRotation = .pi / 4  // Diamond shape
        sprite.texture?.filteringMode = .nearest
        sprite.alpha = 0
        
        // Set supernova color
        sprite.color = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        sprite.colorBlendFactor = 1.0
        
        // Create velocity (outward from center) - much slower speed!
        let speed = random.nextDouble(in: minSpeed * 0.3...minSpeed * 0.6)  // 30-60% of min star speed
        let vx = cos(randomAngle) * speed
        let vy = sin(randomAngle) * speed
        let velocity = CGVector(dx: vx, dy: vy)
        
        // Explosion distance - will travel farther before exploding
        let explosionDistance = random.nextDouble(in: 0.5...0.8)  // 50-80% to edge
        
        // Create star object
        let star = Star(
            sprite: sprite,
            velocity: velocity,
            growthMultiplier: random.nextDouble(in: minGrowthMultiplier...maxGrowthMultiplier),
            baseSpeed: speed,
            angle: randomAngle,
            shouldTwinkle: false,
            twinkleDuration: 0,
            minTwinkleWait: 0,
            maxTwinkleWait: 0,
            minAlpha: 0,
            isSupernova: true,
            supernovaExplosionDistance: explosionDistance,
            isInitialStar: false
        )
        
        stars.append(star)
        addChild(sprite)
        
        print("💥 MANUAL SUPERNOVA spawned! Speed: \(String(format: "%.1f", speed)) Will explode at \(Int(explosionDistance * 100))% distance")
    }
    
    private func selectStarColor(isSupernova: Bool) -> SKColor {
        if isSupernova {
            return SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        }
        
        let randomValue = random.nextDouble()
        
        if randomValue < 0.85 {
            return .white
        } else if randomValue < 0.93 {
            return SKColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1.0)
        } else if randomValue < 0.98 {
            return SKColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0)
        } else if randomValue < 0.995 {
            return SKColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        } else {
            return SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
        }
    }
    
    private func scheduleTwinkle(for star: Star) {
        let waitTime = random.nextDouble(in: star.minTwinkleWait...star.maxTwinkleWait)
        
        let waitAction = SKAction.wait(forDuration: waitTime)
        let fadeOut = SKAction.fadeAlpha(to: star.minAlpha, duration: star.twinkleDuration / 2)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: star.twinkleDuration / 2)
        let twinkleSequence = SKAction.sequence([fadeOut, fadeIn])
        
        let fullSequence = SKAction.sequence([waitAction, twinkleSequence])
        
        star.sprite.run(fullSequence) { [weak self] in
            // Recursively schedule next twinkle with new random wait time
            if let self = self, self.stars.contains(where: { $0.sprite == star.sprite }) {
                self.scheduleTwinkle(for: star)
            }
        }
    }
    
    private func triggerSupernova(for star: Star) {
        guard !star.supernovaTriggered else { return }
        star.supernovaTriggered = true
        
        // Remove any existing actions
        star.sprite.removeAllActions()
        
        // Phase 1: Fade In (0.5 seconds)
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        
        // Phase 2: Wait (0.3 seconds)
        let wait = SKAction.wait(forDuration: 0.3)
        
        // Phase 3: Flash to white (0.05 seconds)
        let flash = SKAction.colorize(with: SKColor.white, colorBlendFactor: 1.0, duration: 0.05)
        
        // Phase 4: Initial Expansion (0.12 seconds) - happens simultaneously with flash
        let initialExpansion = SKAction.scale(to: 22.5, duration: 0.12)
        
        // Group flash and expansion together
        let flashAndExpand = SKAction.group([flash, initialExpansion])
        
        // Phase 5: Recoil Shrink (0.15 seconds)
        let recoilShrink = SKAction.scale(to: 18.0, duration: 0.15)
        
        // Phase 6: Re-expansion (0.25 seconds)
        let reExpansion = SKAction.scale(to: 24.0, duration: 0.25)
        
        // Phase 7: Color Shift Sequence (1.5 seconds total, 0.3 each)
        let colorShift = SKAction.sequence([
            SKAction.colorize(with: SKColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 1.0),
                            colorBlendFactor: 1.0, duration: 0.3),
            SKAction.colorize(with: SKColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0),
                            colorBlendFactor: 1.0, duration: 0.3),
            SKAction.colorize(with: SKColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0),
                            colorBlendFactor: 1.0, duration: 0.3),
            SKAction.colorize(with: SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),
                            colorBlendFactor: 1.0, duration: 0.3),
            SKAction.colorize(with: SKColor(red: 0.8, green: 0.2, blue: 0.5, alpha: 1.0),
                            colorBlendFactor: 1.0, duration: 0.3)
        ])
        
        // Phase 8: Fade Out (3.0 seconds)
        let fadeOut = SKAction.fadeOut(withDuration: 3.0)
        
        // Removal action
        let removeAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            star.sprite.removeFromParent()
            self.stars.removeAll { $0.sprite == star.sprite }
        }
        
        // Complete sequence
        let fullSequence = SKAction.sequence([
            fadeIn,
            wait,
            flashAndExpand,
            recoilShrink,
            reExpansion,
            colorShift,
            fadeOut,
            removeAction
        ])
        
        star.sprite.run(fullSequence, withKey: "supernovaSequence")
        
        // Start twinkling effect after initial flash (runs in parallel with main sequence)
        let twinkleStart = SKAction.wait(forDuration: 0.8)
        let startTwinkleAction = SKAction.run { [weak self, weak star] in
            self?.startSupernovaTwinkle(for: star)
        }
        let twinkleSequence = SKAction.sequence([twinkleStart, startTwinkleAction])
        
        star.sprite.run(twinkleSequence, withKey: "startTwinkle")
    }
    
    private func startSupernovaTwinkle(for star: Star?) {
        guard let star = star else { return }
        
        // Check if main sequence is still running
        guard star.sprite.action(forKey: "supernovaSequence") != nil else { return }
        
        // Generate random twinkle parameters for uneven effect
        let twinkleDuration = random.nextDouble(in: 0.05...0.15)  // Rapid but varied
        let minAlpha = random.nextDouble(in: 0.6...0.85)  // Dim to fairly bright
        let waitBetween = random.nextDouble(in: 0.02...0.08)  // Quick intervals
        
        // Create twinkle sequence
        let fadeToMin = SKAction.fadeAlpha(to: minAlpha, duration: twinkleDuration / 2)
        let fadeToMax = SKAction.fadeAlpha(to: 1.0, duration: twinkleDuration / 2)
        let waitAction = SKAction.wait(forDuration: waitBetween)
        
        // Recursive call to continue twinkling
        let recursiveCall = SKAction.run { [weak self, weak star] in
            self?.startSupernovaTwinkle(for: star)
        }
        
        let twinkleSequence = SKAction.sequence([fadeToMin, fadeToMax, waitAction, recursiveCall])
        
        star.sprite.run(twinkleSequence, withKey: "supernovaTwinkle")
    }
    
    private func spawnComet() {
        // Random comet size
        let cometSize = random.nextDouble(in: cometMinSize...cometMaxSize)
        
        // Random speed
        let speed = random.nextDouble(in: cometMinSpeed...cometMaxSpeed)
        
        // Choose random side (0: top, 1: right, 2: bottom, 3: left)
        let startSide = random.nextInt(in: 0...3)
        let endSide = (startSide + 2) % 4  // Opposite side
        
        // Get random start position on chosen side
        let startPosition: CGPoint
        switch startSide {
        case 0: // Top
            startPosition = CGPoint(x: random.nextDouble(in: 0...Double(size.width)), y: Double(size.height))
        case 1: // Right
            startPosition = CGPoint(x: Double(size.width), y: random.nextDouble(in: 0...Double(size.height)))
        case 2: // Bottom
            startPosition = CGPoint(x: random.nextDouble(in: 0...Double(size.width)), y: 0)
        default: // Left
            startPosition = CGPoint(x: 0, y: random.nextDouble(in: 0...Double(size.height)))
        }
        
        // Get random end position on opposite side
        let endPosition: CGPoint
        switch endSide {
        case 0: // Top
            endPosition = CGPoint(x: random.nextDouble(in: 0...Double(size.width)), y: Double(size.height))
        case 1: // Right
            endPosition = CGPoint(x: Double(size.width), y: random.nextDouble(in: 0...Double(size.height)))
        case 2: // Bottom
            endPosition = CGPoint(x: random.nextDouble(in: 0...Double(size.width)), y: 0)
        default: // Left
            endPosition = CGPoint(x: 0, y: random.nextDouble(in: 0...Double(size.height)))
        }
        
        // Create comet sprite with optimized texture
        let comet: SKSpriteNode
        if let texture = starTexture {
            comet = SKSpriteNode(texture: texture)
            comet.size = CGSize(width: cometSize, height: cometSize)
        } else {
            comet = SKSpriteNode(color: cometColor, size: CGSize(width: cometSize, height: cometSize))
        }
        comet.position = startPosition
        comet.zPosition = 2
        comet.color = cometColor
        comet.colorBlendFactor = 1.0
        comet.texture?.filteringMode = .nearest
        addChild(comet)
        
        // Calculate travel distance and duration
        let distance = hypot(endPosition.x - startPosition.x, endPosition.y - startPosition.y)
        let duration = TimeInterval(distance / CGFloat(speed))
        
        // Move comet
        let moveAction = SKAction.move(to: endPosition, duration: duration)
        
        // Spawn space dust trail at intervals
        let dustSpawnInterval = 0.05  // Spawn dust every 0.05 seconds
        let dustAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: dustSpawnInterval),
            SKAction.run { [weak self, weak comet] in
                guard let self = self, let comet = comet else { return }
                
                // Random amount of dust particles (1-3 per spawn)
                let dustCount = self.random.nextInt(in: 1...3)
                for _ in 0..<dustCount {
                    self.spawnSpaceDust(at: comet.position)
                }
            }
        ]))
        
        comet.run(dustAction, withKey: "dustTrail")
        
        comet.run(moveAction) { [weak comet] in
            comet?.removeAllActions()
            comet?.removeFromParent()
        }
        
        print("☄️ COMET! Speed: \(Int(speed)) Size: \(String(format: "%.1f", cometSize))")
    }
    
    private func spawnSpaceDust(at position: CGPoint) {
        // Very small dust particle
        let dustSize = random.nextDouble(in: 0.5...1.5)
        let dust: SKSpriteNode
        if let texture = starTexture {
            dust = SKSpriteNode(texture: texture)
            dust.size = CGSize(width: dustSize, height: dustSize)
        } else {
            dust = SKSpriteNode(color: cometColor, size: CGSize(width: dustSize, height: dustSize))
        }
        
        // Add slight random offset from comet position
        let offsetX = random.nextDouble(in: -3...3)
        let offsetY = random.nextDouble(in: -3...3)
        dust.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
        dust.zPosition = 1.5
        dust.color = cometColor
        dust.colorBlendFactor = 1.0
        dust.texture?.filteringMode = .nearest
        dust.alpha = 1.0
        
        addChild(dust)
        
        // Rapid sparkle effect (random frequency)
        let sparkleInterval = random.nextDouble(in: 0.05...0.15)
        let sparkleDuration = random.nextDouble(in: 0.02...0.08)
        let minSparkleAlpha = random.nextDouble(in: 0.3...0.6)
        
        let sparkleOut = SKAction.fadeAlpha(to: minSparkleAlpha, duration: sparkleDuration)
        let sparkleIn = SKAction.fadeAlpha(to: 1.0, duration: sparkleDuration)
        let sparkleWait = SKAction.wait(forDuration: sparkleInterval)
        let sparkleSequence = SKAction.sequence([sparkleOut, sparkleIn, sparkleWait])
        let sparkleForever = SKAction.repeatForever(sparkleSequence)
        
        dust.run(sparkleForever, withKey: "sparkle")
        
        // Slow fade out (random duration - slower than before)
        let fadeOutDuration = random.nextDouble(in: 3.0...8.0)
        let fadeOut = SKAction.fadeOut(withDuration: fadeOutDuration)
        
        dust.run(fadeOut) { [weak dust] in
            dust?.removeAllActions()
            dust?.removeFromParent()
        }
    }
    
    private func updateStars(deltaTime: TimeInterval) {
        var starsToRemove: [Star] = []
        
        // Frame counter for optimization #3 - skip updates for some initial stars
        let frameCount = Int(totalElapsedTime * 60)
        
        for star in stars {
            // OPTIMIZATION #3: Update initial stars less frequently (every other frame)
            // This reduces update calls for background stars that move slower
            if star.isInitialStar && frameCount % 2 == 0 {
                continue  // Skip this update for initial stars on even frames
            }
            
            // Update position
            let newX = star.sprite.position.x + CGFloat(star.velocity.dx * deltaTime)
            let newY = star.sprite.position.y + CGFloat(star.velocity.dy * deltaTime)
            star.sprite.position = CGPoint(x: newX, y: newY)
            
            // Calculate distance from center
            let distanceFromCenter = sqrt(pow(newX - centerPoint.x, 2) +
                                        pow(newY - centerPoint.y, 2))
            let normalizedDistance = distanceFromCenter / maxDistanceFromCenter
            
            // Check if supernova should explode
            if star.isSupernova && !star.supernovaTriggered && normalizedDistance >= star.supernovaExplosionDistance {
                triggerSupernova(for: star)
                continue  // Skip normal updates once supernova is triggered
            }
            
            // Skip normal updates for stars in supernova sequence
            if star.isSupernova && star.supernovaTriggered {
                continue
            }
            
            // Update visibility based on distance
            if normalizedDistance < visibilityThreshold {
                star.sprite.alpha = 0
            } else if normalizedDistance < visibilityThreshold + fadeInRange {
                let fadeProgress = (normalizedDistance - visibilityThreshold) / fadeInRange
                
                // Only update alpha if not currently twinkling
                if !star.shouldTwinkle || star.sprite.hasActions() == false {
                    star.sprite.alpha = fadeProgress
                }
            } else {
                // Fully visible - twinkling will handle alpha if applicable
                if !star.shouldTwinkle {
                    star.sprite.alpha = 1.0
                }
            }
            
            // Update size based on distance (skip for supernovas)
            if !star.isSupernova {
                let currentGrowthRate = star.isInitialStar ? initialGrowthRate : growthRate
                let sizeMultiplier = 1.0 + normalizedDistance * star.growthMultiplier * currentGrowthRate
                var newSize = minSize + (maxSize - minSize) * normalizedDistance * star.growthMultiplier * currentGrowthRate
                
                // Cap initial star sizes
                if star.isInitialStar {
                    newSize = min(newSize, maxSize * 0.2) // 15 pixels max for initial stars
                }
                
                star.sprite.size = CGSize(width: newSize, height: newSize)
            }
            
            // Check if star is off screen
            let bounds = CGRect(
                x: -removalBuffer,
                y: -removalBuffer,
                width: size.width + removalBuffer * 2,
                height: size.height + removalBuffer * 2
            )
            
            if !bounds.contains(star.sprite.position) {
                starsToRemove.append(star)
            }
        }
        
        // Remove off-screen stars
        for star in starsToRemove {
            star.sprite.removeAllActions()
            star.sprite.removeFromParent()
            stars.removeAll { $0.sprite == star.sprite }
        }
    }
    func spawnBlockCueBallAtCenter() {
        guard let feltRect = blockFeltRect else { return }
        let spawnPoint = CGPoint(x: feltRect.midX, y: feltRect.midY)
        
        let ball = BlockBall(kind: .cue,
                             position: spawnPoint,
                             in: self,
                             feltRect: feltRect,
                             pocketCenters: blockPocketCenters ?? [],
                             pocketRadius: blockPocketRadius ?? 0)
        
        if ball.parent == nil { addChild(ball) }
        addCueBall(ball)
        damageSystem?.registerBall(ball)
        applyPhysicsToAllBalls()
    }
    
    private func respawnBlockCueBallAtCenter() {
        guard let feltRect = self.blockFeltRect else { return }
        // Spawn a new cue ball at center
        let spawnPoint = CGPoint(x: feltRect.midX, y: feltRect.midY)
        let newBall = BlockBall(kind: .cue,
                                position: spawnPoint,
                                in: self,
                                feltRect: feltRect,
                                pocketCenters: self.blockPocketCenters ?? [],
                                pocketRadius: self.blockPocketRadius ?? 0)
        // BlockBall initializer already adds to scene; ensure single parent
        if newBall.parent == nil { addChild(newBall) }
        
        // Use centralized tracking method (handles aiming sync automatically)
        addCueBall(newBall)
        
        // Register with damage system
        damageSystem?.registerBall(newBall)
        
        // Smooth spawn animation
        newBall.alpha = 0
        newBall.setScale(0.1)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.4)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.4)
        scaleUp.timingMode = .linear  // Consistent growth without pauses
        
        let group = SKAction.group([fadeIn, scaleUp])
        newBall.run(group)
        
        // Apply current physics settings
        applyPhysicsToAllBalls()
        
        print("✅ Cue ball respawned with smooth animation (total cue balls: \(blockCueBalls.count))")
    }
    
    private func isValidSpawnPoint(_ p: CGPoint, minClearance: CGFloat) -> Bool {
        // Must be inside felt
        guard let felt = blockFeltRect else { return false }
        if !felt.insetBy(dx: minClearance, dy: minClearance).contains(p) { return false }
        // Require a felt block under this point (felt blocks have zPosition 21)
        let feltHere = nodes(at: p).contains { node in
            if let s = node as? SKSpriteNode { return s.zPosition == 21 }
            return false
        }
        if !feltHere { return false }
        // Not inside any pocket
        if let centers = blockPocketCenters, let r = blockPocketRadius {
            for c in centers { if hypot(p.x - c.x, p.y - c.y) <= (r + minClearance) { return false } }
        }
        // Not overlapping existing BlockBall nodes
        let existing = children.compactMap { $0 as? BlockBall }
        for b in existing {
            let d = hypot(p.x - b.position.x, p.y - b.position.y)
            if d < (b.frame.width/2 + minClearance) { return false }
        }
        return true
    }

    func randomSpawnPoint(minClearance: CGFloat) -> CGPoint? {
        guard let felt = blockFeltRect else { return nil }
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let x = CGFloat.random(in: felt.minX...felt.maxX)
            let y = CGFloat.random(in: felt.minY...felt.maxY)
            let p = CGPoint(x: x, y: y)
            if isValidSpawnPoint(p, minClearance: minClearance) { return p }
        }
        return nil
    }
    
    // MARK: - Level Completion & Transitions
    
    /// Immediately freeze all cue balls (called when level complete is detected)
    /// This provides instant visual feedback and prevents balls from escaping offscreen
    private func freezeAllCueBalls() {
        for cueBall in blockCueBalls {
            guard let body = cueBall.physicsBody else { continue }
            
            // Capture speed before freezing for logging
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            
            // Slam to a stop - no gradual slowdown
            body.velocity = .zero
            body.angularVelocity = 0
            
            // Make kinematic to prevent any further movement from collisions
            body.isDynamic = false
            
            print("🛑 Froze cue ball (speed was \(Int(speed))) at level complete")
        }
    }
    
    private func remainingEnemyBallCount() -> Int {
        return children.compactMap { $0 as? BlockBall }.filter { $0.ballKind == .one || $0.ballKind == .two || $0.ballKind == .three || $0.ballKind == .four || $0.ballKind == .five || $0.ballKind == .six || $0.ballKind == .eight || $0.ballKind == .eleven }.count
    }

    private func handleLevelComplete() {
        guard !isTransitioningLevel else { return }
        isTransitioningLevel = true
        
        // Cancel any pending cue ball respawn - the new level will spawn a fresh cue ball
        removeAction(forKey: "respawnCueBall")
        print("🎊 Level \(gameStateManager.currentLevel) Complete!")
        
        // Immediately freeze all cue balls when the last ball sinks
        freezeAllCueBalls()
        
        // DON'T advance to next level yet - wait until just before loading the new level
        // This keeps the level indicator showing the current level during the exit transition
        
        // Short delay before transition (no need to wait for cue ball since we froze it)
        let delay = SKAction.wait(forDuration: 0.3)
        let transition = SKAction.run { [weak self] in
            self?.startExitTransition()
        }
        run(SKAction.sequence([delay, transition]))
    }
    
    private func waitForCueBallToRest(completion: @escaping () -> Void) {
        // Check if any cue ball exists and is moving
        let cueBalls = blockCueBalls.filter { $0.parent != nil }  // Filter out removed balls
        
        guard !cueBalls.isEmpty else {
            // No cue balls, proceed immediately
            completion()
            return
        }
        
        // Check if all cue balls are at rest
        var anyMoving = false
        var maxSpeed: CGFloat = 0
        
        for cueBall in cueBalls {
            guard let body = cueBall.physicsBody else { continue }
            
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            let angularSpeed = abs(body.angularVelocity)
            
            if speed > maxSpeed {
                maxSpeed = speed
            }
            
            if speed >= 5.0 || angularSpeed >= 0.5 {
                anyMoving = true
            }
        }
        
        if !anyMoving {
            // All cue balls at rest, proceed immediately
            print("✅ All cue balls already at rest")
            completion()
            return
        }
        
        // Some cue balls still moving, wait for them to stop
        displayCueBallSpeed(maxSpeed)
        
        // Use a repeating action with a key instead of recursive scheduling
        let checkInterval: TimeInterval = 0.1
        let checkAction = SKAction.wait(forDuration: checkInterval)
        
        let checkRest = SKAction.run { [weak self] in
            guard let self = self else { return }
            
            // Re-check status
            let cueBalls = self.blockCueBalls.filter { $0.parent != nil }
            var stillMoving = false
            var currentMaxSpeed: CGFloat = 0
            
            for cueBall in cueBalls {
                guard let body = cueBall.physicsBody else { continue }
                let speed = hypot(body.velocity.dx, body.velocity.dy)
                let angularSpeed = abs(body.angularVelocity)
                
                if speed > currentMaxSpeed {
                    currentMaxSpeed = speed
                }
                
                if speed >= 5.0 || angularSpeed >= 0.5 {
                    stillMoving = true
                }
            }
            
            if !stillMoving {
                // Stop checking and call completion
                self.removeAction(forKey: "waitForCueBallRest")
                print("✅ All cue balls at rest")
                completion()
            } else {
                self.displayCueBallSpeed(currentMaxSpeed)
            }
        }
        
        let repeatCheck = SKAction.repeatForever(SKAction.sequence([checkAction, checkRest]))
        run(repeatCheck, withKey: "waitForCueBallRest")
    }
    
    private func waitForAllBallsToRest(completion: @escaping () -> Void) {
        // Get all balls in play
        let allBalls = children.compactMap { $0 as? BlockBall }
        
        guard !allBalls.isEmpty else {
            // No balls, proceed immediately
            completion()
            return
        }
        
        // Check if all balls are at rest
        var anyBallMoving = false
        var maxSpeed: CGFloat = 0
        
        for ball in allBalls {
            guard let body = ball.physicsBody else { continue }
            
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            let angularSpeed = abs(body.angularVelocity)
            
            if speed > maxSpeed {
                maxSpeed = speed
            }
            
            if speed >= 5.0 || angularSpeed >= 0.5 {
                anyBallMoving = true
            }
        }
        
        if !anyBallMoving {
            // All balls at rest, proceed immediately
            print("✅ All balls already at rest")
            completion()
            return
        }
        
        // Some balls still moving, wait and check again
        var maxCueSpeed: CGFloat = 0
        for cue in blockCueBalls {
            if let body = cue.physicsBody {
                let s = hypot(body.velocity.dx, body.velocity.dy)
                if s > maxCueSpeed { maxCueSpeed = s }
            }
        }
        displayCueBallSpeed(maxCueSpeed)
        
        let checkInterval: TimeInterval = 0.1
        let checkAction = SKAction.wait(forDuration: checkInterval)
        
        let checkRest = SKAction.run { [weak self] in
            guard let self = self else { return }
            
            // Re-check status
            let allBalls = self.children.compactMap { $0 as? BlockBall }
            var stillMoving = false
            var currentMaxSpeed: CGFloat = 0
            
            for ball in allBalls {
                guard let body = ball.physicsBody else { continue }
                let speed = hypot(body.velocity.dx, body.velocity.dy)
                let angularSpeed = abs(body.angularVelocity)
                
                if speed > currentMaxSpeed {
                    currentMaxSpeed = speed
                }
                
                if speed >= 5.0 || angularSpeed >= 0.5 {
                    stillMoving = true
                }
            }
            
            if !stillMoving {
                // Stop checking and call completion
                self.removeAction(forKey: "waitForAllBallsRest")
                print("✅ All balls at rest")
                completion()
            } else {
                var maxCueSpeed: CGFloat = 0
                for cue in self.blockCueBalls {
                    if let body = cue.physicsBody {
                        let s = hypot(body.velocity.dx, body.velocity.dy)
                        if s > maxCueSpeed { maxCueSpeed = s }
                    }
                }
                self.displayCueBallSpeed(maxCueSpeed)
            }
        }
        
        let repeatCheck = SKAction.repeatForever(SKAction.sequence([checkAction, checkRest]))
        run(repeatCheck, withKey: "waitForAllBallsRest")
    }
    
    private func startExitTransition() {
        // Randomly choose exit transition type
        let transitionType = Int.random(in: 0...1)
        
        switch transitionType {
        case 0:
            performFadeOutTransition {
                // Wait 1 second showing just the starfield before starting entrance
                let delay = SKAction.wait(forDuration: 1.0)
                let loadNext = SKAction.run {
                    // Advance to next level right before loading it
                    self.gameStateManager.advanceToNextLevel()
                    self.loadCurrentLevel()
                    self.isTransitioningLevel = false
                }
                self.run(SKAction.sequence([delay, loadNext]))
            }
        case 1:
            performCueBallExpansionTransition {
                // Wait 1 second showing just the starfield before starting entrance
                let delay = SKAction.wait(forDuration: 1.0)
                let loadNext = SKAction.run {
                    // Advance to next level right before loading it
                    self.gameStateManager.advanceToNextLevel()
                    self.loadCurrentLevel()
                    self.isTransitioningLevel = false
                }
                self.run(SKAction.sequence([delay, loadNext]))
            }
        default:
            performFadeOutTransition {
                // Wait 1 second showing just the starfield before starting entrance
                let delay = SKAction.wait(forDuration: 1.0)
                let loadNext = SKAction.run {
                    // Advance to next level right before loading it
                    self.gameStateManager.advanceToNextLevel()
                    self.loadCurrentLevel()
                    self.isTransitioningLevel = false
                }
                self.run(SKAction.sequence([delay, loadNext]))
            }
        }
    }
    
    private func performFadeOutTransition(completion: @escaping () -> Void) {
        print("🎬 Exit transition: Fade out to starfield")
        
        // Pause physics and damage system updates during transition
        physicsWorld.speed = 0
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        
        // Batch fade operations - use a single group action instead of individual runs
        var nodesToFade: [SKNode] = poolTableNodes
        nodesToFade.append(contentsOf: children.compactMap { $0 as? BlockBall })
        
        // Use a completion counter instead of waiting on each node
        var completedCount = 0
        let totalCount = nodesToFade.count
        
        for node in nodesToFade {
            node.run(fadeOut) {
                completedCount += 1
                if completedCount == totalCount {
                    // All fades complete, proceed with teardown
                    self.teardownCurrentLevel()
                    self.physicsWorld.speed = 1.0  // Resume physics
                    completion()
                }
            }
        }
        
        // Fallback in case there are no nodes to fade
        if totalCount == 0 {
            teardownCurrentLevel()
            physicsWorld.speed = 1.0
            completion()
        }
    }
    
    private func performCueBallExpansionTransition(completion: @escaping () -> Void) {
        print("🎬 Exit transition: Cue ball slow-to-fast expansion + shrink")
        
        // Use the first cue ball's position, or fall back to fade if none exist
        let cueBallPosition: CGPoint
        if let cueBall = blockCueBalls.first(where: { $0.parent != nil }) {
            cueBallPosition = cueBall.position
        } else {
            print("⚠️ No cue ball, falling back to fade")
            performFadeOutTransition(completion: completion)
            return
        }
        
        // Pause physics during transition for better performance
        physicsWorld.speed = 0
        
        // Create a perfect circle using SKShapeNode (not a square!)
        let expansionCircle = SKShapeNode(circleOfRadius: 12.5)  // Start at cue ball size
        expansionCircle.fillColor = .white
        expansionCircle.strokeColor = .clear
        expansionCircle.position = cueBallPosition
        expansionCircle.zPosition = 2000
        expansionCircle.alpha = 1.0
        addChild(expansionCircle)
        
        let screenDiagonal = sqrt(pow(size.width, 2) + pow(size.height, 2))
        let expansionScale = screenDiagonal / 25.0  // Divide by diameter (12.5 * 2)
        let expandDuration: TimeInterval = 0.8
        
        // Two-phase expansion: slow start (30% growth), then dramatic acceleration
        let halfwayScale = 1 + (expansionScale - 1) * 0.3
        
        let slowExpand = SKAction.scale(to: halfwayScale, duration: expandDuration / 2)
        slowExpand.timingMode = .easeOut
        
        let rapidExpand = SKAction.scale(to: expansionScale, duration: expandDuration / 2)
        rapidExpand.timingMode = .easeIn
        
        let fullExpansion = SKAction.sequence([slowExpand, rapidExpand])
        
        expansionCircle.run(fullExpansion) { [weak self] in
            guard let self = self else { return }
            
            print("💥 White screen - tearing down level")
            self.teardownCurrentLevel()
            
            let shrink = SKAction.scale(to: 0.0, duration: 0.4)
            shrink.timingMode = .easeOut
            
            expansionCircle.run(shrink) {
                print("✨ Shrink complete - starfield revealed")
                expansionCircle.removeFromParent()
                self.physicsWorld.speed = 1.0  // Resume physics
                completion()
            }
        }
    }
    
    private func teardownCurrentLevel() {
        print("🧹 Starting level teardown...")
        
        // Unregister all balls from damage system first
        for case let ball as BlockBall in children {
            damageSystem?.unregisterBall(ball)
        }
        
        // Remove all BlockBall instances in a single batch
        enumerateChildNodes(withName: "//*") { node, _ in
            if node is BlockBall {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
        blockCueBalls.removeAll()
        
        // Batch remove pool table nodes
        for node in poolTableNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        poolTableNodes.removeAll()
        
        // Batch remove obstacle nodes
        for node in obstacleNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        obstacleNodes.removeAll()
        
        // Batch remove physics nodes
        for node in blockTablePhysicsNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        blockTablePhysicsNodes.removeAll()
        
        // Clear cue ball controller
        cueBallController = nil
        
        print("🧹 Level teardown complete")
    }
}
  
// MARK: - Supporting Types

/// Special events that can occur in the starfield
enum SpecialEvent: CaseIterable {
    case supernova
    case comet
    
    var name: String {
        switch self {
        case .supernova: return "Supernova"
        case .comet: return "Comet"
        }
    }
}






