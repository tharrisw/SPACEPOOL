// BlockBall.swift
// A blocky 5x5 visual ball that behaves with circular physics. Supports cue and 8-ball appearance.

import SpriteKit
import UIKit

public final class BlockBall: SKNode {
    // Different visual/physics shapes supported by BlockBall
    enum Shape {
        case circle
        case square
        case diamond
        case triangle
        case hexagon
    }

    // Pocket/sinking configuration
    private let supportSampleRays: Int = 12 // number of radial samples
    private let supportSampleDepth: CGFloat = 1.5 // how far below the ball center to sample (in points)
    private let minUnsupportedAtZeroSpeed: CGFloat = 0.45 // require slightly less unsupported area at rest
    private let maxUnsupportedAtHighSpeed: CGFloat = 0.95 // allow sinking even at higher speeds
    private let highSpeedThreshold: CGFloat = 500.0 // raise threshold so mid-high speeds can still sink
    private let lowSpeedThreshold: CGFloat = 40.0 // baseline applies at a lower speed
    private let sinkFadeDuration: TimeInterval = 0.25
    private let sinkScaleDuration: TimeInterval = 0.25
    private let sinkVelocityGuard: CGFloat = 15.0 // permit sinking at higher velocities when unsupported



    // Cached references for sampling
    private weak var samplingScene: SKScene?

    public enum Kind {
        case cue
        case one     // Gravity ball - attracts other balls when stationary (yellow solid)
        case two     // Spawns duplicate cue ball when hit (blue solid)
        case three   // Heavy ball - 10x mass via accessory (red solid)
        case four    // Pulse ball - charges for 1s then releases damaging pulse when hit (purple solid)
        case five    // Flying ball - levitates over pockets (orange solid)
        case six     // Healing ball - heals nearby cue balls when stationary (dark green solid)
        case seven   // Burning ball - catches fire on first movement, immune to burn damage (dark red solid)
        case eight   // Classic 8-ball (black solid)
        case nine    // Standard 9-ball (yellow striped)
        case ten     // Speedy ball - moves at 2x speed with 2x collision power (blue striped)
        case eleven  // Explode on contact ball - instantly explodes when hit by any ball (red striped)
        case twelve  // Standard 12-ball (purple striped)
        case thirteen // Standard 13-ball (orange striped)
        case fourteen // Standard 14-ball (green striped)
        case fifteen  // Standard 15-ball (dark red/maroon striped)
    }
    
    var ballKind: Kind { kind }

    // Visual construction
    private let gridSize: Int = 5
    private let blockSize: CGFloat = 5.0 // each visual block is 5x5
    private var ballRadius: CGFloat { (CGFloat(gridSize) * blockSize) / 2 } // ~12.5 by default
    internal var visualContainer = SKNode()
    private var stickContainer = SKNode()
    private var aimHelperContainer = SKNode()

    // Physics tuning (pool-like)
    var maxShotDistance: CGFloat = 156  // 25% further than previous 125
    var maxImpulse: CGFloat = 300  // Reduced for more controlled shots (changeable via UI)
    var powerCurveExponent: CGFloat = 1.5
    var restLinearSpeedThreshold: CGFloat = 5
    var restAngularSpeedThreshold: CGFloat = 0.5
    var restCheckDuration: TimeInterval = 0.5
    
    var stopSpeedThreshold: CGFloat = 12.0
    var stopAngularThreshold: CGFloat = 0.8
    var stopHoldDuration: TimeInterval = 0.25
    private var lowSpeedTimerForStop: TimeInterval = 0
    private var hasSnappedToStop: Bool = false  // Prevents repeated snap messages

    var baseAngularDamping: CGFloat = 1.8
    var highAngularDamping: CGFloat = 8.0
    var slowSpeedThreshold: CGFloat = 100.0
    
    // State
    internal weak var sceneRef: SKScene?
    private var kind: Kind
    internal var shape: Shape = .circle
    var isAiming = false
    var canShoot = true
    private var restTimer: TimeInterval = 0
    private var touchStart: CGPoint = .zero
    private var lastTouchPos: CGPoint = .zero
    private var isSinking = false  // Track if ball is currently sinking
    private var pocketInfoPrinted = false  // Debug flag for pocket info
    
    // Burning ball (7-ball) state
    private var hasCaughtFire = false  // Track if 7-ball has caught fire yet
    private var isBurning = false  // Track if fire is currently active
    private var burnoutTimer: TimeInterval = 0.0  // Time spent at rest
    private let burnoutDelay: TimeInterval = 6.0  // Seconds at rest before fire goes out
    private let burningRestThreshold: CGFloat = 3.0  // Speed threshold to consider ball at rest
    
    // Healing ball (6-ball) state
    private var hasHealerMovedOnce = false  // Track if healer ball has moved yet
    private var isHealingActive = false  // Track if healing is currently active
    private let healingRadius: CGFloat = 150.0  // Same as gravity radius
    private let healingAmount: CGFloat = 10.0  // HP healed per tick
    private let healingInterval: TimeInterval = 1.0  // Heal once per second
    private let maxHealingTotal: CGFloat = 30.0  // Break after healing 30 HP
    private var totalHPHealed: CGFloat = 0.0  // Track total HP healed
    private var timeSinceLastHeal: TimeInterval = 0.0  // Timer for healing interval
    private var healingFieldNode: SKShapeNode?  // Visual indicator of healing field
    
    // Debug frame counter for periodic physics verification
    #if DEBUG
    private var frameCounter: Int = 0
    #endif
    
    // Rolling animation state - simulate 3D ball rotation
    private var ballRotationX: CGFloat = 0  // Rotation around X axis (vertical rolls)
    private var ballRotationY: CGFloat = 0  // Rotation around Y axis (horizontal rolls)
    private var lastPosition: CGPoint = .zero  // Track position for calculating roll direction
    private var ballSpriteGenerator: BallSpriteGenerator?  // For generating textures on-demand (all ball types)

    // Cue stick visuals
    private let cueLength: CGFloat = 280
    private let tipGap: CGFloat = 1.0
    private var lastAimUnit: CGVector = .zero
    private var lastAimUnitWorld: CGVector = .zero
    private var lastPullback: CGFloat = 0

    // Felt/pocket metadata (for spawn logic or future pocket behavior)
    private let feltRect: CGRect
    private let pocketCenters: [CGPoint]
    private let pocketRadius: CGFloat

    #if DEBUG
        private let debugEnabled: Bool = false
    #else
        private let debugEnabled: Bool = false
    #endif

    // MARK: - Damage Hook
    /// Called by the damage system after damage is applied but before death handling.
    /// Override behavior per kind here.
    func onDamage(amount: CGFloat, source: BlockBall?, system: BallDamageSystem?) {
        // The 2-ball's spawning ability is now handled by the SpawnerAccessory
        // No special handling needed here
    }

    init(kind: Kind,
         shape: Shape = .circle,
         position: CGPoint,
         in scene: SKScene,
         feltRect: CGRect,
         pocketCenters: [CGPoint],
         pocketRadius: CGFloat) {
        self.kind = kind
        self.shape = shape
        self.sceneRef = scene
        self.feltRect = feltRect
        self.pocketCenters = pocketCenters
        self.pocketRadius = pocketRadius
        super.init()
        self.isUserInteractionEnabled = false
        self.samplingScene = scene
        self.position = position
        self.zPosition = 1000
        self.lastPosition = position  // Initialize lastPosition

        buildVisual()
        buildPhysics()
        
        // Initialize texture generator and set initial texture for numbered balls
        if kind != .cue {
            cacheSpotTextures()
        }

        stickContainer.name = "blockCueStick"
        stickContainer.zPosition = 1
        stickContainer.physicsBody = nil
        stickContainer.isUserInteractionEnabled = false
        addChild(stickContainer)
        // Aim helper container (dotted line)
        aimHelperContainer.name = "aimHelper"
        aimHelperContainer.zPosition = -1
        aimHelperContainer.isUserInteractionEnabled = false
        addChild(aimHelperContainer)
#if DEBUG
        print("🎱 BlockBall created kind: \(kind) shape: \(shape) at: \(position) z: \(zPosition) alpha: \(alpha)")
#endif

        scene.addChild(self)
        
        // Attach spawner accessory to 2-balls AFTER ball is added to scene
        // (accessory needs ball.scene to be non-nil)
        if kind == .two {
            _ = attachAccessory("spawner")
        }
        
        // Attach flying accessory to 5-balls AFTER ball is added to scene
        // (accessory needs ball.scene to be non-nil to create wing sprites)
        if kind == .five {
            _ = attachAccessory("flying")
        }
        
        // Attach zapper accessory to 9-balls
        // (unleashes lightning at nearby balls when hit)
        if kind == .nine {
            _ = attachAccessory("zapper")
        }
        
        // Attach gravity accessory to 1-balls
        // (attracts nearby balls when at rest)
        if kind == .one {
            _ = attachAccessory("gravity")
        }
        
        // Attach heavy accessory to 3-balls
        // (10x heavier mass - very hard to move)
        if kind == .three {
            _ = attachAccessory("heavy")
        }
        
        // Attach explode on destroy accessory to 11-balls
        // (explodes when HP reaches 0, creating a crater)
        if kind == .eleven {
            _ = attachAccessory("explodeOnDestroy")
        }
        
        // Attach pulse accessory to 4-balls
        // (charges for 1s then releases damaging pulse when hit)
        if kind == .four {
            _ = attachAccessory("pulse")
        }
        
        // Attach healing accessory to 6-balls
        // (heals nearby cue balls when at rest)
        if kind == .six {
            _ = attachAccessory("healing")
        }
        
        // Attach speedy accessory to 10-balls
        // (2x speed and power from collisions)
        if kind == .ten {
            _ = attachAccessory("speedy")
        }
        
        // 7-balls will get burning accessory after first movement (see update method)
        
        // Attach random hat to cue balls for cosmetic decoration (if hats are enabled)
        if kind == .cue && BallAccessoryManager.shared.areHatsEnabled() {
            _ = BallAccessoryManager.shared.attachRandomHat(to: self)
        }
    }

    override init() {
        self.kind = .cue
        self.shape = .circle
        self.sceneRef = nil
        self.feltRect = .zero
        self.pocketCenters = []
        self.pocketRadius = 0
        super.init()
        self.isUserInteractionEnabled = false
        self.samplingScene = nil
        self.zPosition = 1000
        self.lastPosition = .zero  // Initialize lastPosition

        buildVisual()
        buildPhysics()
        
        // Initialize texture generator and set initial texture for numbered balls
        if kind != .cue {
            cacheSpotTextures()
        }

        stickContainer.name = "blockCueStick"
        stickContainer.zPosition = 1
        stickContainer.physicsBody = nil
        stickContainer.isUserInteractionEnabled = false
        addChild(stickContainer)
        // Aim helper container (dotted line)
        aimHelperContainer.name = "aimHelper"
        aimHelperContainer.zPosition = -1
        aimHelperContainer.isUserInteractionEnabled = false
        addChild(aimHelperContainer)
        #if DEBUG
        print("⚠️ BlockBall default init used. Not attached to a scene. pos: \(position)")
        #endif
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Visuals
    
    /// Initialize texture generator and create initial texture for numbered balls
    /// All balls (solid and striped) use on-demand texture generation based on real-time 3D rotation
    private func cacheSpotTextures() {
        let generator = BallSpriteGenerator()
        
        // Store the generator for all numbered balls
        ballSpriteGenerator = generator
        
        // Generate initial texture based on ball type (shown before any movement)
        guard let ballSprite = visualContainer.children.first(where: { $0.name == "ballSprite" }) as? SKSpriteNode else {
            #if DEBUG
            if debugEnabled {
                print("⚠️ Could not find ballSprite to set initial texture")
            }
            #endif
            return
        }
        
        let initialTexture: SKTexture
        switch kind {
        case .cue:
            return  // Cue ball has no spots/stripes
        case .eight:
            // Solid black ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: .black,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .one:
            // Solid golden yellow ball with white spot (gravity ball)
            initialTexture = generator.generateTexture(
                fillColor: SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0),
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .two:
            // Solid blue ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: .blue,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .three:
            // Solid red ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: .red,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .four:
            // Solid purple ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: SKColor.purple,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .five:
            // Solid orange ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: SKColor.orange,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .six:
            // Solid dark green ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .seven:
            // Solid red ball with white spot
            initialTexture = generator.generateTexture(
                fillColor: .red,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: 0,
                rotationY: 0
            )
        case .eleven:
            // Striped ball with maroon/burgundy stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0),
                rotationX: 0,
                rotationY: 0
            )
        case .nine:
            // Striped ball with vibrant golden yellow stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0),
                rotationX: 0,
                rotationY: 0
            )
        case .ten:
            // Striped ball with blue stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: .blue,
                rotationX: 0,
                rotationY: 0
            )
        case .twelve:
            // Striped ball with purple stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: .purple,
                rotationX: 0,
                rotationY: 0
            )
        case .thirteen:
            // Striped ball with orange stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: .orange,
                rotationX: 0,
                rotationY: 0
            )
        case .fourteen:
            // Striped ball with dark green stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
                rotationX: 0,
                rotationY: 0
            )
        case .fifteen:
            // Striped ball with maroon stripe
            initialTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: .centerRight,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0),
                rotationX: 0,
                rotationY: 0
            )
        }
        
        // Set initial texture directly on sprite
        ballSprite.texture = initialTexture
        
        #if DEBUG
        if debugEnabled {
            print("🎨 Initialized generator for \(kind) ball - textures will be generated on-demand during rolling animation")
        }
        #endif
    }
    
    private func buildVisual() {
        visualContainer.removeAllChildren()
        visualContainer.name = "ballVisual"
        visualContainer.zPosition = 0
        visualContainer.physicsBody = nil  // CRITICAL: Visual container has no physics
        visualContainer.isUserInteractionEnabled = false
        addChild(visualContainer)

        let fillColor: SKColor
        switch kind {
        case .cue:
            fillColor = SKColor(white: 1.0, alpha: 1.0)
        case .one:
            fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)  // Vibrant golden yellow
        case .two:
            fillColor = SKColor.blue
        case .three:
            fillColor = SKColor.red
        case .four:
            fillColor = SKColor.purple
        case .five:
            fillColor = SKColor.orange
        case .six:
            fillColor = SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0) // Dark green
        case .seven:
            fillColor = .red
        case .eight:
            fillColor = .black
        case .nine, .ten, .eleven, .twelve, .thirteen, .fourteen, .fifteen:
            fillColor = SKColor(white: 1.0, alpha: 1.0) // White base for striped balls
        }

        // Create a single texture for the ball for performance
        let textureSize = CGSize(width: CGFloat(gridSize) * blockSize, height: CGFloat(gridSize) * blockSize)
        let ballTexture = createBallTexture(size: textureSize, fillColor: fillColor)
        
        // Create a single sprite with the generated texture
        let ballSprite = SKSpriteNode(texture: ballTexture, size: textureSize)
        ballSprite.name = "ballSprite"
        ballSprite.position = .zero
        ballSprite.zPosition = 1
        visualContainer.addChild(ballSprite)

        // All numbered balls now have their markings baked into rotating textures
        // Solid balls (8, 2, 3) have white spots that rotate
        // Striped balls (11, etc.) have white stripes that rotate
        // No overlay sprites needed - everything is in the sprite texture animation
    }
    
    /// Convert the single sprite ball into individual blocks for crumble animation
    func convertToBlocks() {
        #if DEBUG
        if debugEnabled {
            print("🔄 Converting \(kind) ball from sprite to individual blocks")
        }
        #endif
        
        // Find and remove the existing ball sprite
        visualContainer.children.forEach { node in
            if node.name == "ballSprite" {
                node.removeFromParent()
            }
        }
        
        let fillColor: SKColor
        switch kind {
        case .cue:
            fillColor = SKColor(white: 1.0, alpha: 1.0)
        case .one:
            fillColor = SKColor.yellow
        case .two:
            fillColor = SKColor.blue
        case .three:
            fillColor = SKColor.red
        case .four:
            fillColor = SKColor.purple
        case .five:
            fillColor = SKColor.orange
        case .six:
            fillColor = SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0) // Dark green
        case .seven:
            fillColor = .red
        case .eight:
            fillColor = .black
        case .nine, .ten, .eleven, .twelve, .thirteen, .fourteen, .fifteen:
            fillColor = SKColor(white: 1.0, alpha: 1.0) // White base for striped balls
        }
        
        // Create individual block sprites
        let half = CGFloat(gridSize - 1) / 2
        var blockCount = 0
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let cx = CGFloat(col) - half
                let cy = CGFloat(row) - half
                
                // Check if block should be included based on shape
                var shouldInclude = false
                switch shape {
                case .circle:
                    let centerDist = hypot(cx * blockSize, cy * blockSize)
                    shouldInclude = centerDist <= (ballRadius - blockSize / 2)
                case .square:
                    shouldInclude = true
                case .diamond:
                    shouldInclude = abs(cx) + abs(cy) <= half
                case .triangle:
                    shouldInclude = cy >= -abs(cx)
                case .hexagon:
                    let a = abs(Int(cx))
                    let b = abs(Int(cy))
                    shouldInclude = (a + b) <= Int(half)
                }
                
                if shouldInclude {
                    let block = SKSpriteNode(color: fillColor, size: CGSize(width: blockSize, height: blockSize))
                    block.position = CGPoint(x: cx * blockSize, y: cy * blockSize)
                    block.zPosition = 1
                    block.texture?.filteringMode = .nearest
                    visualContainer.addChild(block)
                    blockCount += 1
                }
            }
        }
        
        #if DEBUG
        if debugEnabled {
            print("🎱 Converted to \(blockCount) individual blocks for crumble animation")
        }
        #endif
    }
    
    // Helper to create a single texture for the ball shape
    private func createBallTexture(size: CGSize, fillColor: SKColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Helper to check if a block should be included based on shape
            func shouldIncludeBlock(cx: CGFloat, cy: CGFloat) -> Bool {
                let half = CGFloat(gridSize - 1) / 2
                switch shape {
                case .circle:
                    let centerDist = hypot(cx * blockSize, cy * blockSize)
                    return centerDist <= (ballRadius - blockSize / 2)
                case .square:
                    return true
                case .diamond:
                    return abs(cx) + abs(cy) <= half
                case .triangle:
                    return cy >= -abs(cx)
                case .hexagon:
                    let a = abs(Int(cx))
                    let b = abs(Int(cy))
                    return (a + b) <= Int(half)
                }
            }
            
            // Draw all blocks
            let half = CGFloat(gridSize - 1) / 2
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let cx = CGFloat(col) - half
                    let cy = CGFloat(row) - half
                    if shouldIncludeBlock(cx: cx, cy: cy) {
                        // For 8-ball, 1-ball, 2-ball, 3-ball, 4-ball, 6-ball, and 7-ball: make one off-center block white
                        // Use block at position (1, 0) which is one block right of center
                        let isSpotBlock = ((kind == .eight || kind == .one || kind == .two || kind == .three || kind == .four || kind == .six || kind == .seven) && cx == 1 && cy == 0)
                        let blockColor = isSpotBlock ? SKColor.white : fillColor
                        
                        // Convert to UIKit coordinates (top-left origin)
                        let px = CGFloat(col) * blockSize
                        let py = size.height - CGFloat(row + 1) * blockSize
                        let rect = CGRect(x: px, y: py, width: blockSize, height: blockSize)
                        
                        ctx.setFillColor(blockColor.cgColor)
                        ctx.fill(rect)
                    }
                }
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
    
    // Helper to create a single texture for the cue stick
    private func createCueStickTexture(totalBlocks: Int, tipLength: CGFloat, woodColor: SKColor, tipColor: SKColor) -> SKTexture {
        let size = CGSize(width: CGFloat(totalBlocks + 1) * blockSize, height: blockSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            for i in 0...totalBlocks {
                let t = CGFloat(i) * blockSize
                let color: SKColor = (t <= tipLength) ? tipColor : woodColor
                ctx.setFillColor(color.cgColor)
                let rect = CGRect(x: t, y: 0, width: blockSize, height: blockSize)
                ctx.fill(rect)
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private func buildPhysics() {
        let body: SKPhysicsBody
        let r = ballRadius * 0.95
        switch shape {
        case .circle:
            body = SKPhysicsBody(circleOfRadius: r)
        case .square:
            let size = CGSize(width: r * 2, height: r * 2)
            body = SKPhysicsBody(rectangleOf: size)
        case .diamond:
            let points = [CGPoint(x: 0, y: r), CGPoint(x: r, y: 0), CGPoint(x: 0, y: -r), CGPoint(x: -r, y: 0)]
            body = SKPhysicsBody(polygonFrom: CGMutablePath.makePolygon(points: points))
        case .triangle:
            let points = [CGPoint(x: 0, y: r), CGPoint(x: -r, y: -r), CGPoint(x: r, y: -r)]
            body = SKPhysicsBody(polygonFrom: CGMutablePath.makePolygon(points: points))
        case .hexagon:
            var pts: [CGPoint] = []
            for i in 0..<6 {
                let angle = CGFloat(i) * (.pi / 3)
                pts.append(CGPoint(x: cos(angle) * r, y: sin(angle) * r))
            }
            body = SKPhysicsBody(polygonFrom: CGMutablePath.makePolygon(points: pts))
        }

        body.affectedByGravity = false
        
        // All balls have normal mass now (4-ball no longer immovable)
        body.mass = 0.17
        
        body.friction = 0.12
        body.linearDamping = 0.65
        body.angularDamping = 1.8  // Increased for even shorter rotation tail off
        body.restitution = 0.85
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true  // Prevent tunneling through other balls

        let ballCategory: UInt32 = 0x1 << 0
        let railCategory: UInt32 = 0x1 << 1
        body.categoryBitMask = ballCategory
        body.collisionBitMask = railCategory | ballCategory
        body.contactTestBitMask = railCategory | ballCategory

        self.physicsBody = body
    }
    
    // MARK: - Physics property setters (called by scene)
    func updatePhysicsProperties(mass: CGFloat, friction: CGFloat, linearDamping: CGFloat, angularDamping: CGFloat, restitution: CGFloat) {
        guard let body = physicsBody else { return }
        body.mass = mass
        body.friction = friction
        body.linearDamping = linearDamping
        body.angularDamping = angularDamping
        body.restitution = restitution
    }
    
    func applyPhysicsCoefficients(friction: CGFloat?, linearDamping: CGFloat?, angularDamping: CGFloat?, restitution: CGFloat?) {
        guard let body = physicsBody else { return }
        if let f = friction { body.friction = f }
        if let ld = linearDamping { body.linearDamping = ld }
        if let ad = angularDamping { body.angularDamping = ad }
        if let r = restitution { body.restitution = r }
    }
    
    func setShootingTuning(maxDistance: CGFloat?, maxPower: CGFloat?, powerExponent: CGFloat?) {
        if let d = maxDistance { self.maxShotDistance = d }
        if let p = maxPower { self.maxImpulse = p }
        if let e = powerExponent { self.powerCurveExponent = e }
    }
    
    func updateShootingProperties(maxDistance: CGFloat, maxPower: CGFloat) {
        // These would normally be stored as properties in BlockBall
        // Since they're currently constants, we'll need to add them as stored properties
        // For now, we'll just note this needs to be implemented in BlockBall
    }
    
    func updateRestProperties(restLinear: CGFloat, restAngular: CGFloat, stopSpeed: CGFloat, stopAngular: CGFloat) {
        // These would be stored properties in BlockBall
        // For now, noting this needs implementation
    }
    
    func updatePocketProperties(sampleRays: Int, sampleDepth: CGFloat, minUnsupported: CGFloat, maxUnsupported: CGFloat, lowSpeed: CGFloat, highSpeed: CGFloat, minTime: TimeInterval, maxTime: TimeInterval) {
        // These would be stored properties in BlockBall
        // For now, noting this needs implementation
    }

    // MARK: - Global aiming control API
    func beginGlobalAim(from startPointInScene: CGPoint) {
        // Allow aiming at any time - no canShoot check
        isAiming = true
        // Reset cached aim values; visuals will be shown on first drag update
        lastAimUnit = .zero
        lastAimUnitWorld = .zero
        lastPullback = 0
        touchStart = .zero
        lastTouchPos = .zero
    }
    
    func beginGlobalAim() {
        // Allow aiming at any time - no canShoot check
        isAiming = true
        lastAimUnit = .zero
        lastAimUnitWorld = .zero
        lastPullback = 0
        touchStart = .zero
        lastTouchPos = .zero
    }
    
    func updateGlobalAim(direction drag: CGVector, magnitude: CGFloat) {
        guard isAiming else { return }
        // Compute a unit vector from the drag; if zero, do nothing
        let len = max(sqrt(drag.dx * drag.dx + drag.dy * drag.dy), 0.0001)
        let ux = drag.dx / len
        let uy = drag.dy / len
        // Aim in the same direction as the drag for cue placement (shot will be opposite)
        let aimX = ux * magnitude
        let aimY = uy * magnitude
        // Build a target point in parent space at ball.position + aim vector
        let space = self.parent ?? self
        let targetInParent = CGPoint(x: position.x + aimX, y: position.y + aimY)
        // Reuse existing cue rendering
        showCueStick(to: targetInParent, from: lastTouchPos)
        lastTouchPos = targetInParent
    }

    func updateGlobalAim(to currentPointInScene: CGPoint) {
        guard isAiming else { return }
        let space = self.parent ?? self
        let loc = space.convert(currentPointInScene, from: self.scene ?? space)
        showCueStick(to: loc, from: lastTouchPos)
        lastTouchPos = loc
    }

    func endGlobalAimApplyShot() {
        guard let body = physicsBody else { isAiming = false; clearAimHelper(); clearCueStick(animated: false); return }
        // If there was no meaningful pullback, just clear visuals
        let distance = lastPullback
        isAiming = false
        clearAimHelper()
        stickContainer.removeAllActions()
        if distance < 5 {
            clearCueStick(animated: false)
            return
        }
        // Use cached aim units: local for visuals, world for physics impulse
        let uxLocal = lastAimUnit.dx
        let uyLocal = lastAimUnit.dy
        let uxWorld = lastAimUnitWorld.dx
        let uyWorld = lastAimUnitWorld.dy
        let clamped = min(distance, maxShotDistance)
        let normalizedDistance = clamped / maxShotDistance
        // Gentler power curve (x^1.5) for easier fine shots
        let curvedPower = pow(normalizedDistance, powerCurveExponent)
        let power = curvedPower * maxImpulse
        let shootImpulse = CGVector(dx: -uxWorld * power, dy: -uyWorld * power)
        // No longer set canShoot = false - allow rapid fire
        restTimer = 0
        let tipStop: CGFloat = ballRadius + tipGap
        let finalTipPos = CGPoint(x: uxLocal * tipStop, y: uyLocal * tipStop)
        let moveDuration: TimeInterval = 0.1
        let move = SKAction.move(to: finalTipPos, duration: moveDuration)
        move.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: moveDuration)
        let group = SKAction.group([move, fade])
        stickContainer.run(group) { [weak self] in
            guard let self = self else { return }
            self.stickContainer.removeAllChildren()
            self.stickContainer.alpha = 1.0
            body.isDynamic = true
            body.applyImpulse(shootImpulse)
            self.lastAimUnit = .zero
            self.lastAimUnitWorld = .zero
            self.lastPullback = 0
            self.touchStart = .zero
            self.lastTouchPos = .zero
        }
    }
    
    func endGlobalAim(at endPointInScene: CGPoint) {
        guard isAiming else { return }
        guard let body = physicsBody else { isAiming = false; clearAimHelper(); clearCueStick(animated: false); return }
        isAiming = false
        clearAimHelper()
        // Clear previous cue stick animations to avoid conflict
        stickContainer.removeAllActions()

        let space = self.parent ?? self
        let endPoint = space.convert(endPointInScene, from: self.scene ?? space)

        // Compute shot vector opposite of drag
        let shot = CGVector(dx: position.x - endPoint.x, dy: position.y - endPoint.y)
        let distance = hypot(shot.dx, shot.dy)
        if distance < 5 {
            clearCueStick(animated: false)
            return
        }

        // Use cached aim units: local for visuals, world for physics impulse
        let uxLocal = lastAimUnit.dx
        let uyLocal = lastAimUnit.dy
        let uxWorld = lastAimUnitWorld.dx
        let uyWorld = lastAimUnitWorld.dy

        // Gentler power curve (x^1.5) for easier fine shots
        let clamped = min(distance, maxShotDistance)
        let normalizedDistance = clamped / maxShotDistance
        let curvedPower = pow(normalizedDistance, powerCurveExponent)
        let power = curvedPower * maxImpulse

        // Prepare impulse (applied after snap animation completes)
        let shootImpulse = CGVector(dx: -uxWorld * power, dy: -uyWorld * power)

        // No longer prevent new aim during the snap animation - allow rapid fire
        restTimer = 0

        // Compute final tip position just off the ball surface in ball's local space
        let tipStop: CGFloat = ballRadius + tipGap
        let finalTipPos = CGPoint(x: uxLocal * tipStop, y: uyLocal * tipStop)

        let moveDuration: TimeInterval = 0.1
        let move = SKAction.move(to: finalTipPos, duration: moveDuration)
        move.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: moveDuration)
        let group = SKAction.group([move, fade])

        stickContainer.run(group) { [weak self] in
            guard let self = self else { return }
            self.stickContainer.removeAllChildren()
            self.stickContainer.alpha = 1.0
            body.isDynamic = true
            body.applyImpulse(shootImpulse)
            self.lastAimUnit = .zero
            self.lastAimUnitWorld = .zero
            self.lastPullback = 0
            self.touchStart = .zero
            self.lastTouchPos = .zero
        }
    }

    func cancelGlobalAim() {
        if isAiming {
            isAiming = false
            clearAimHelper()
            clearCueStick(animated: true)
            lastAimUnit = .zero
            lastAimUnitWorld = .zero
            lastPullback = 0
            touchStart = .zero
            lastTouchPos = .zero
        }
    }

    // MARK: - Input handling
    func touchesBegan(_ touches: Set<UITouch>) {
        #if DEBUG
        print("👉 touchesBegan received. sceneRefNil=\(sceneRef == nil) touchesCount=\(touches.count)")
        #endif
        guard let touch = touches.first else { return }
        let space = self.parent ?? self
        let loc = touch.location(in: space)
        // Allow aiming at any time - no canShoot check
        // Consider a small halo around the ball for easier pickup (compute in parent space)
        let dx = loc.x - position.x
        let dy = loc.y - position.y
        let dist = hypot(dx, dy)
        #if DEBUG
        print("📏 touchesBegan distance from ball: \(String(format: "%.1f", dist)) pickup<=\(String(format: "%.1f", ballRadius + 10))")
        #endif
        if dist <= ballRadius + 10 {
            isAiming = true
            touchStart = loc
            lastTouchPos = loc
            // Show cue as soon as aiming begins
            showCueStick(to: loc, from: lastTouchPos)
            #if DEBUG
            print("🎯 Aiming started at: \(loc)")
            print("🎯 BlockBall current pos: (\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))")
            #endif
        } else {
            #if DEBUG
            print("🚫 Touch outside pickup radius; not starting aim.")
            #endif
        }
    }

    func touchesMoved(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let space = self.parent ?? self
        let loc = touch.location(in: space)
        // Allow starting aim on move - no canShoot check
        if !isAiming {
            let dx = loc.x - position.x
            let dy = loc.y - position.y
            let dist = hypot(dx, dy)
            if dist <= ballRadius + 10 {
                isAiming = true
                touchStart = loc
                lastTouchPos = loc
                #if DEBUG
                print("🎯 Aiming started on move at: \(loc)")
                #endif
            }
        }
        if isAiming {
            // Show cue with tip at finger location, aligned with drag direction
            showCueStick(to: loc, from: lastTouchPos)
            lastTouchPos = loc
        }
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        if !isAiming {
            #if DEBUG
            print("🛑 touchesEnded ignored (not aiming).")
            #endif
            return
        }
        guard let body = physicsBody else { return }
        isAiming = false
        clearAimHelper()
        
        // Clear previous cue stick animations to avoid conflict
        stickContainer.removeAllActions()

        let space = self.parent ?? self
        let endPoint = touch.location(in: space)

        // Compute shot vector opposite of drag
        let shot = CGVector(dx: position.x - endPoint.x, dy: position.y - endPoint.y)
        let distance = hypot(shot.dx, shot.dy)

        if distance < 5 {
            clearCueStick(animated: false)
            return
        }

        // Use cached aim units: local for visuals, world for physics impulse
        let uxLocal = lastAimUnit.dx
        let uyLocal = lastAimUnit.dy
        let uxWorld = lastAimUnitWorld.dx
        let uyWorld = lastAimUnitWorld.dy

        // Gentler power curve (x^1.5) for easier fine shots
        let clamped = min(distance, maxShotDistance)
        let normalizedDistance = clamped / maxShotDistance
        let curvedPower = pow(normalizedDistance, powerCurveExponent)
        let power = curvedPower * maxImpulse

        // Prepare impulse (applied after snap animation completes)
        let shootImpulse = CGVector(dx: -uxWorld * power, dy: -uyWorld * power)

        // No longer prevent new aim during the snap animation - allow rapid fire
        restTimer = 0
        isAiming = false

        // Compute final tip position just off the ball surface in ball's local space
        let tipStop: CGFloat = ballRadius + tipGap
        let finalTipPos = CGPoint(x: uxLocal * tipStop, y: uyLocal * tipStop)

        // Animate the cue tip snapping toward the ball over a maximum of 0.1 seconds
        let moveDuration: TimeInterval = 0.1
        let move = SKAction.move(to: finalTipPos, duration: moveDuration)
        move.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: moveDuration)
        let group = SKAction.group([move, fade])

        stickContainer.run(group) { [weak self] in
            guard let self = self else { return }
            // Clear cue visuals and reset alpha
            self.stickContainer.removeAllChildren()
            self.stickContainer.alpha = 1.0

            // Apply the impulse now that the tip has snapped to the ball
            body.isDynamic = true
            body.applyImpulse(shootImpulse)

            // Reset aim-related cached values
            self.lastAimUnit = .zero
            self.lastAimUnitWorld = .zero
            self.lastPullback = 0
            self.touchStart = .zero
            self.lastTouchPos = .zero
        }
    }

    // MARK: - Cue stick visuals
    private func showCueStick(to target: CGPoint, from previousPos: CGPoint) {
        stickContainer.physicsBody = nil
        stickContainer.removeAllChildren()

        // Convert finger target from parent space to this node's local space
        let targetLocal = self.convert(target, from: self.parent ?? self)

        let dx = targetLocal.x
        let dy = targetLocal.y
        var dist = hypot(dx, dy)
        let minVisibleDistance: CGFloat = 5
        
        // Compute a safe unit direction; default to +X if finger is exactly at center
        let ux: CGFloat
        let uy: CGFloat
        if dist < 0.0001 {
            ux = 1.0
            uy = 0.0
            dist = minVisibleDistance
        } else {
            ux = dx / dist
            uy = dy / dist
            if dist < minVisibleDistance {
                dist = minVisibleDistance
            }
        }
        
        // CLAMP: Limit drag distance to maxShotDistance
        // If user drags beyond max, visually clamp the stick position
        let clampedDist = min(dist, maxShotDistance)
        let clampedTargetLocal = CGPoint(x: ux * clampedDist, y: uy * clampedDist)
        
        lastAimUnit = CGVector(dx: ux, dy: uy)
        lastPullback = clampedDist  // Use clamped distance for power calculation

        // Also cache world-space aim unit (parent/scene space)
        let worldDx = target.x - position.x
        let worldDy = target.y - position.y
        var worldLen = hypot(worldDx, worldDy)
        if worldLen < 0.0001 { worldLen = 1.0 }
        lastAimUnitWorld = CGVector(dx: worldDx / worldLen, dy: worldDy / worldLen)

        // Place tip at CLAMPED finger position in local space
        stickContainer.position = clampedTargetLocal

        // Orient so +X points from ball toward finger
        let angle = atan2(uy, ux)  // Use unit direction for consistent angle
        stickContainer.zRotation = angle

        // Build cue along +X axis from tip (0,0) to butt as a single texture
        let totalBlocks = Int(cueLength / blockSize)
        if totalBlocks <= 0 { return }
        let woodColor = SKColor(red: 0.55, green: 0.35, blue: 0.20, alpha: 1.0)
        let tipColor = SKColor.black
        let tipLength: CGFloat = 8
        
        // Create a single texture for the cue stick
        let cueTexture = createCueStickTexture(totalBlocks: totalBlocks, tipLength: tipLength, woodColor: woodColor, tipColor: tipColor)
        let cueSize = CGSize(width: CGFloat(totalBlocks + 1) * blockSize, height: blockSize)
        let cueSprite = SKSpriteNode(texture: cueTexture, size: cueSize)
        cueSprite.anchorPoint = CGPoint(x: 0, y: 0.5)
        cueSprite.position = .zero
        cueSprite.zPosition = 0
        stickContainer.addChild(cueSprite)

        // Alpha based on pullback distance (use clamped distance)
        let maxVisibleDistance: CGFloat = 150
        let normalizedDistance = min(clampedDist / maxVisibleDistance, 1.0)
        stickContainer.alpha = 0.5 + 0.5 * normalizedDistance

        // Update dotted aim helper based on current aim vector and pullback
        updateAimHelper()
    }

    private func snapCueStickForward(direction: CGVector) {
        // Animate all stick blocks moving quickly toward the ball direction and fading out
        let snapDistance = ballRadius + maxShotDistance * 0.4
        let move = SKAction.moveBy(x: direction.dx * snapDistance, y: direction.dy * snapDistance, duration: 0.08)
        move.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.12)
        let group = SKAction.group([move, fade])
        stickContainer.run(group) { [weak self] in
            self?.stickContainer.removeAllChildren()
        }
    }

    private func clearCueStick(animated: Bool) {
        if animated {
            let fade = SKAction.fadeOut(withDuration: 0.1)
            stickContainer.run(fade) { [weak self] in
                self?.stickContainer.removeAllChildren()
                self?.stickContainer.alpha = 1.0
            }
        } else {
            stickContainer.removeAllChildren()
            stickContainer.alpha = 1.0
        }
    }

    // MARK: - Aim helper (dotted line)
    private func updateAimHelper() {
        // Build a dotted line in the shot direction with length proportional to pullback
        aimHelperContainer.removeAllChildren()
        // Determine shot direction: opposite of the aim vector (ball -> finger)
        let dir = CGVector(dx: -lastAimUnit.dx, dy: -lastAimUnit.dy)
        // Length scales with pullback, clamped to maxShotDistance
        let length = min(max(lastPullback, 0), maxShotDistance)
        guard length > 0.5 else { return }
        let spacing: CGFloat = 8.0
        let dotSize: CGFloat = 2.5
        let count = Int(floor(length / spacing))
        if count <= 0 { return }
        for i in 1...count {
            let t = CGFloat(i) * spacing
            let x = dir.dx * t
            let y = dir.dy * t
            let dot = SKSpriteNode(color: .white, size: CGSize(width: dotSize, height: dotSize))
            dot.position = CGPoint(x: x, y: y)
            dot.zPosition = -1
            dot.alpha = 0.9
            dot.texture?.filteringMode = .nearest
            aimHelperContainer.addChild(dot)
        }
    }

    private func clearAimHelper() {
        aimHelperContainer.removeAllChildren()
    }

    // MARK: - Pocket support sampling
    
    private func unsupportedFractionUnderBall() -> CGFloat {
        guard let scene = samplingScene ?? sceneRef ?? self.scene else { return 0 }
        
        // Sample points around the lower semicircle footprint of the ball
        let samples = max(3, supportSampleRays)
        var unsupportedCount: Int = 0
        var total: Int = 0
        let r = ballRadius
        
        // We consider directions spanning 180 degrees (left to right) under the ball
        for i in 0..<samples {
            // Angle from -90 to +90 degrees relative to downwards normal
            let t = CGFloat(i) / CGFloat(samples - 1)
            let angle = (-.pi/2) + t * (.pi) // -90° to +90°
            // Point on circle perimeter projected downward slightly
            let localPoint = CGPoint(x: cos(angle) * r, y: -sin(angle) * r)
            let worldPoint = self.convert(localPoint, to: scene)
            // Sample a point just beneath this perimeter point
            let samplePoint = CGPoint(x: worldPoint.x, y: worldPoint.y - supportSampleDepth)
            total += 1
            let hasFelt = isFeltBlock(at: samplePoint, in: scene)
            if !hasFelt {
                unsupportedCount += 1
            }
            
            // DEBUG: Log first unsupported sample to help diagnose holes
            #if DEBUG
            if debugEnabled && !hasFelt && unsupportedCount == 1 {
                // Log first unsupported sample per check
                print("🕳️ \(ballKind) ball detecting hole: sample \(i)/\(samples) at \(samplePoint)")
                print("   Ball position: \(position)")
                print("   Unsupported: \(unsupportedCount)/\(total) so far")
            }
            #endif
        }
        if total == 0 { return 0 }
        
        let fraction = CGFloat(unsupportedCount) / CGFloat(total)
        
        // DEBUG: Log when ball should sink (throttled to avoid spam)
        #if DEBUG
        if debugEnabled && fraction > minUnsupportedAtZeroSpeed {
            // Log occasionally when over threshold
            if Int.random(in: 0..<30) == 0 {
                print("⚠️ \(ballKind) ball SHOULD sink: unsupported=\(String(format: "%.2f", fraction)), threshold=\(String(format: "%.2f", minUnsupportedAtZeroSpeed))")
                print("   Position: \(position)")
            }
        }
        #endif
        
        return fraction
    }

    private func isFeltBlock(at point: CGPoint, in scene: SKScene) -> Bool {
        // OPTIMIZATION: Use TableGrid for O(1) lookup instead of expensive geometric checks
        if let starfieldScene = scene as? StarfieldScene,
           let feltManager = starfieldScene.feltManager {
            // Grid-based O(1) check - much faster than geometric calculations!
            return feltManager.isFelt(at: point)
        }
        
        // Grid not available - this should never happen in production
        assertionFailure("Grid-based detection unavailable in isFeltBlock - feltManager is nil")
        return false
    }
    
    /// Public method to check if the ball is currently over a pocket
    /// Used by accessories to determine when to show special effects
    func isOverPocket() -> Bool {
        guard let scene = samplingScene ?? sceneRef ?? self.scene else { return false }
        
        // OPTIMIZATION: Use grid-based check if available
        if let starfieldScene = scene as? StarfieldScene,
           let feltManager = starfieldScene.feltManager {
            return feltManager.isHole(at: position)
        }
        
        // Grid not available - this should never happen in production
        assertionFailure("Grid-based detection unavailable in isOverPocket - feltManager is nil")
        return false
    }

    private func maybeTriggerSink(linearSpeed: CGFloat, deltaTime: TimeInterval) {
        guard !isSinking else { return }
        
        // Check if any accessory prevents sinking
        if BallAccessoryManager.shared.preventsSinking(ball: self) {
            #if DEBUG
            if debugEnabled {
                // Log occasionally to avoid spam
                if Int.random(in: 0..<60) == 0 {
                    print("🪽 \(ballKind) ball sink PREVENTED by accessory (flying wings)")
                }
            }
            #endif
            return
        }
        
        // Compute speed-adjusted unsupported threshold
        let s = max(0, min(1, (linearSpeed - lowSpeedThreshold) / max(highSpeedThreshold - lowSpeedThreshold, 1)))
        let requiredUnsupported = minUnsupportedAtZeroSpeed + s * (maxUnsupportedAtHighSpeed - minUnsupportedAtZeroSpeed)
        let unsupported = unsupportedFractionUnderBall()
        
        // DEBUG: Log when we're checking for sinking (throttled)
        #if DEBUG
        if debugEnabled && unsupported > 0.1 {
            // Log occasionally to avoid spam
            if Int.random(in: 0..<60) == 0 {
                print("🔍 \(ballKind) ball sink check:")
                print("   speed=\(String(format: "%.1f", linearSpeed))")
                print("   unsupported=\(String(format: "%.2f", unsupported))")
                print("   required=\(String(format: "%.2f", requiredUnsupported))")
                print("   will sink: \(unsupported >= requiredUnsupported)")
            }
        }
        #endif
        
        // Sink immediately when unsupported area meets threshold
        if unsupported >= requiredUnsupported {
            #if DEBUG
            if debugEnabled {
                print("💧 TRIGGERING SINK for \(ballKind) ball!")
            }
            #endif
            triggerSink()
        }
    }

    private func triggerSink() {
        guard !isSinking else { return }
        isSinking = true
        isUserInteractionEnabled = false
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        physicsBody?.isDynamic = false
        
        // Note: Cue balls are only frozen when the LAST ball sinks (level complete)
        // Regular ball sinks should not freeze cue balls
        
        // Simple disappear animation
        let fade = SKAction.fadeOut(withDuration: sinkFadeDuration)
        let scale = SKAction.scale(to: 0.2, duration: sinkScaleDuration)
        let group = SKAction.group([fade, scale])
        let notify = SKAction.run { [weak self] in
            guard let self = self else { return }
            // Notify the scene that this ball finished sinking
            if let scene = self.scene as? StarfieldScene {
                scene.blockBallDidSink(self)
            } else if let scene = self.sceneRef as? StarfieldScene {
                scene.blockBallDidSink(self)
            }
        }
        let remove = SKAction.removeFromParent()
        let seq = SKAction.sequence([group, notify, remove])
        self.run(seq)
    }

    // MARK: - Rolling Animation
    
    /// Update the ball sprite to show realistic rolling based on physics movement
    /// This simulates a 3D ball where the white spot/stripe rotates based on actual 3D rotation angles
    /// and generates the exact texture needed for that rotation state in real-time
    private func updateRollingAnimation(linearSpeed: CGFloat, deltaTime: TimeInterval) {
        guard let ballSprite = visualContainer.children.first(where: { $0.name == "ballSprite" }) as? SKSpriteNode else { return }
        guard let body = physicsBody else { return }
        guard let generator = ballSpriteGenerator else { return }
        
        // Don't animate if ball is essentially stopped
        if linearSpeed < 2.0 {
            return
        }
        
        // Use VELOCITY instead of position delta to get true instantaneous direction
        // This way, bounces and spin changes are handled by the physics engine
        let vx = body.velocity.dx
        let vy = body.velocity.dy
        let speed = hypot(vx, vy)
        
        guard speed > 2.0 else { return }
        
        // Normalize velocity direction
        let dirX = vx / speed
        let dirY = vy / speed
        
        // Calculate rotation based on actual distance traveled this frame
        let distance = speed * CGFloat(deltaTime)
        let rotationAmount = distance / ballRadius
        
        // PHYSICS OF ROLLING:
        // When a ball rolls right (+X velocity), it rotates around the Y-axis
        // The rotation rate = velocity / radius (no-slip rolling condition)
        //
        // When the ball bounces:
        // - SpriteKit's physics handles the velocity change (considers restitution, friction, angle)
        // - Our rotation automatically responds to the NEW velocity direction
        // - This naturally handles:
        //   * Elastic bounces (velocity reverses, so does rotation)
        //   * Friction during bounce (velocity changes magnitude and direction)
        //   * Glancing blows (velocity changes angle, rotation follows)
        //   * Spin effects (angular velocity can affect the bounce)
        
        ballRotationY -= dirX * rotationAmount  // Horizontal velocity -> Y-axis rotation
        ballRotationX += dirY * rotationAmount  // Vertical velocity -> X-axis rotation (screen Y inverted)
        
        // Keep rotations in reasonable range
        ballRotationX = fmod(ballRotationX, .pi * 2)
        ballRotationY = fmod(ballRotationY, .pi * 2)
        
        // Map the 3D rotation to which face of the ball is visible (for debugging/approximation)
        let spotPosition = getSpotPositionFor3DRotation(rotX: ballRotationX, rotY: ballRotationY)
        
        // Generate texture on-demand using actual 3D rotation angles
        // This works for both solid balls (spots) and striped balls (stripes)
        let newTexture: SKTexture
        switch kind {
        case .cue:
            return  // Cue ball has no spots/stripes
        case .one:
            // Solid golden yellow ball with white spot (gravity ball)
            newTexture = generator.generateTexture(
                fillColor: SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0),
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .two:
            // Solid blue ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .blue,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .three:
            // Solid red ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .red,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .four:
            // Solid purple ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .purple,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .five:
            // Solid orange ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .orange,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .six:
            // Solid dark green ball with white spot
            newTexture = generator.generateTexture(
                fillColor: SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .seven:
            // Solid red ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .red,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .eight:
            // Solid black ball with white spot
            newTexture = generator.generateTexture(
                fillColor: .black,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: false,
                stripeColor: .white,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .nine:
            // Striped ball with vibrant golden yellow stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0),
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .ten:
            // Striped ball with blue stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: .blue,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .eleven:
            // Striped ball with light red stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0),
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .twelve:
            // Striped ball with purple stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: .purple,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .thirteen:
            // Striped ball with orange stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: .orange,
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .fourteen:
            // Striped ball with dark green stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        case .fifteen:
            // Striped ball with maroon stripe
            newTexture = generator.generateTexture(
                fillColor: .white,
                spotPosition: spotPosition,
                shape: shape,
                isStriped: true,
                stripeColor: SKColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0),
                rotationX: ballRotationX,
                rotationY: ballRotationY
            )
        }
        
        // Update the sprite texture (always update since we're using real-time rotation)
        ballSprite.texture = newTexture
        
        #if DEBUG
        if debugEnabled && linearSpeed > 50 {
            // Only log when moving at decent speed to reduce spam
            // print("🎱 \(kind) 3D Rotation - vel:(\(String(format: "%.1f", vx)),\(String(format: "%.1f", vy))) rot:(\(String(format: "%.2f", ballRotationX)),\(String(format: "%.2f", ballRotationY))) -> \(spotPosition)")
        }
        #endif
    }
    
    /// Map 3D rotation angles to which spot position is visible
    /// We simulate the ball as a 3D sphere with the white spot initially at coordinates (1, 0, 0)
    /// After rotation, we determine which face is most visible to the camera
    private func getSpotPositionFor3DRotation(rotX: CGFloat, rotY: CGFloat) -> BallSpriteGenerator.SpotPosition {
        // Initial spot position in 3D space (right side of ball, facing camera)
        // Starting position: spot at (radius, 0, 0) in 3D coordinates
        // X = right/left, Y = up/down, Z = toward/away from camera
        
        // Apply rotations to determine the spot's current 3D position
        // We'll use simplified 3D rotation matrices
        
        // Initial spot position (normalized)
        var x: CGFloat = 1.0  // Right side
        var y: CGFloat = 0.0  // Centered vertically
        var z: CGFloat = 0.0  // On the surface facing camera
        
        // Rotate around X axis (vertical rolls - ball rolling up/down)
        let cosX = cos(rotX)
        let sinX = sin(rotX)
        let y1 = y * cosX - z * sinX
        let z1 = y * sinX + z * cosX
        y = y1
        z = z1
        
        // Rotate around Y axis (horizontal rolls - ball rolling left/right)
        let cosY = cos(rotY)
        let sinY = sin(rotY)
        let x1 = x * cosY + z * sinY
        let z2 = -x * sinY + z * cosY
        x = x1
        z = z2
        
        // Now (x, y, z) represents where the spot is in 3D space
        // Z > 0 means facing away (hidden or edge)
        // Z < 0 means facing toward camera (visible)
        
        // Determine visibility based on Z depth
        // Z ranges from -1 (directly facing camera) to +1 (directly away)
        
        // For STRIPED balls, we rarely want "hidden" because the stripe wraps around
        // Only show hidden when looking directly at the poles (edge-on view)
        // For SOLID balls, hidden is more common (spot on back)
        
        // If spot is far on the back (z > 0.7), it's completely hidden
        // This is more restrictive than before, so stripes stay visible longer
        if z > 0.7 {
            return .hidden
        }
        
        // If spot is at the far horizon (z between 0.4 and 0.7), show edge positions
        // This is the transition zone where the spot is "rolling away"
        let isAtEdge = (z > 0.4 && z <= 0.7)
        
        // Map the x,y coordinates to one of the positions
        // Use atan2 to get the angle of the spot relative to the center
        let angle = atan2(y, x)
        
        // Normalize angle to 0...2π
        var normalizedAngle = angle
        if normalizedAngle < 0 {
            normalizedAngle += .pi * 2
        }
        
        // Divide into 8 segments (45° each)
        let segmentAngle: CGFloat = .pi / 4  // 45 degrees
        let segment = Int((normalizedAngle + segmentAngle / 2) / segmentAngle) % 8
        
        // Map segments to spot positions - choosing edge or center based on Z depth
        // 0° = right, 45° = top-right, 90° = top, etc.
        if isAtEdge {
            // Show edge positions when spot is at the horizon
            switch segment {
            case 0: return .edgeRight        // 0°
            case 1: return .edgeTopRight     // 45°
            case 2: return .edgeTop          // 90°
            case 3: return .edgeTopLeft      // 135°
            case 4: return .edgeLeft         // 180°
            case 5: return .edgeBottomLeft   // 225°
            case 6: return .edgeBottom       // 270°
            case 7: return .edgeBottomRight  // 315°
            default: return .hidden
            }
        } else {
            // Show center positions when spot is clearly visible on front
            switch segment {
            case 0: return .centerRight        // 0°
            case 1: return .centerTopRight     // 45°
            case 2: return .centerTop          // 90°
            case 3: return .centerTopLeft      // 135°
            case 4: return .centerLeft         // 180°
            case 5: return .centerBottomLeft   // 225°
            case 6: return .centerBottom       // 270°
            case 7: return .centerBottomRight  // 315°
            default: return .centerRight
            }
        }
    }

    // MARK: - Update
    func update(deltaTime: TimeInterval) {
        guard let body = physicsBody else { return }
        
        // Don't update if ball is sinking
        guard !isSinking else { return }
        
        // Update accessories
        BallAccessoryManager.shared.updateAccessories(for: self, deltaTime: deltaTime)
        
        let ls = hypot(body.velocity.dx, body.velocity.dy)
        let angSpeed = abs(body.angularVelocity)
        
        // Ignite 7-ball on first movement
        if kind == .seven && !hasCaughtFire && ls > 1.0 {
            hasCaughtFire = true
            isBurning = true
            _ = attachAccessory("burning")
            #if DEBUG
            print("🔥 7-ball caught fire on first movement!")
            #endif
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
                    burnoutTimer = 0.0  // Reset timer
                    #if DEBUG
                    print("🔥 7-ball fire burned out after sitting still for \(burnoutDelay) seconds")
                    #endif
                }
            } else {
                // Ball is moving
                burnoutTimer = 0.0  // Reset burnout timer
                
                // Reignite if not burning
                if !isBurning {
                    isBurning = true
                    _ = attachAccessory("burning")
                    #if DEBUG
                    print("🔥 7-ball reignited after moving!")
                    #endif
                }
            }
        }
        
        // Track if 6-ball has moved for the first time
        if kind == .six && !hasHealerMovedOnce && ls > 1.0 {
            hasHealerMovedOnce = true
            #if DEBUG
            print("💚 6-ball has moved for the first time - healing will activate when it comes to rest")
            #endif
        }
        
        // Update healing state for 6-ball
        if kind == .six && hasHealerMovedOnce {
            // Check if ball is at rest
            if ls < restLinearSpeedThreshold && angSpeed < restAngularSpeedThreshold {
                if !isHealingActive {
                    isHealingActive = true
                    showHealingField()
                    #if DEBUG
                    print("💚 6-ball healing ACTIVATED (ball at rest)")
                    #endif
                }
            } else {
                if isHealingActive {
                    isHealingActive = false
                    hideHealingField()
                    timeSinceLastHeal = 0.0  // Reset timer when deactivated
                    #if DEBUG
                    print("💚 6-ball healing DEACTIVATED (ball moving)")
                    #endif
                }
            }
        }
        
        // Apply healing effect if active
        if kind == .six && isHealingActive {
            applyHealingEffect(deltaTime: deltaTime)
        }
        
        // Update rolling animation for numbered balls (solid spots and striped)
        if kind != .cue {
            updateRollingAnimation(linearSpeed: ls, deltaTime: deltaTime)
        }
        
        // Dynamic angular damping: increase damping dramatically when moving slowly
        // This makes balls stop spinning much faster when they're not moving quickly
        
        if ls < slowSpeedThreshold {
            // Interpolate between high damping (at rest) and base damping (at threshold)
            let speedRatio = ls / slowSpeedThreshold  // 0.0 at rest, 1.0 at threshold
            let damping = highAngularDamping + (baseAngularDamping - highAngularDamping) * speedRatio
            body.angularDamping = damping
            
            // Optional debug logging (commented out to reduce spam)
            // #if DEBUG
            // if debugEnabled && angSpeed > 0.1 {
            //     print("🌀 \(kind) ball slow spin: speed=\(String(format: "%.1f", ls)), angVel=\(String(format: "%.2f", angSpeed)), damping=\(String(format: "%.1f", damping))")
            // }
            // #endif
        } else {
            // Moving fast - use base damping
            body.angularDamping = baseAngularDamping
        }
        
        // Evaluate sinking based on felt support and speed
        maybeTriggerSink(linearSpeed: ls, deltaTime: deltaTime)
        
        // Spot animation removed - balls now have static spots
        
        // Snap-to-stop: if speed stays below thresholds briefly, zero velocity
        // This helps balls come to a clean stop without drifting endlessly
        if ls < stopSpeedThreshold && angSpeed < stopAngularThreshold {
            lowSpeedTimerForStop += deltaTime
            if lowSpeedTimerForStop >= stopHoldDuration && !hasSnappedToStop {
                body.velocity = .zero
                body.angularVelocity = 0
                lowSpeedTimerForStop = 0
                restTimer = 0
                hasSnappedToStop = true  // Prevent repeated snaps
            }
        } else {
            // Ball is moving above threshold - reset timers and snap flag
            lowSpeedTimerForStop = 0
            restTimer = 0
            if ls > stopSpeedThreshold * 2 {  // Only reset snap flag if moving significantly
                hasSnappedToStop = false
            }
        }
    }
    

    private func createGleamEffect(at position: CGPoint) {
        guard let scene = sceneRef else { return }
        
        // Create a small white diamond for the gleam
        let gleamSize: CGFloat = 15
        let gleam = SKSpriteNode(color: .white, size: CGSize(width: gleamSize, height: gleamSize))
        gleam.position = position
        gleam.zRotation = .pi / 4  // Rotate 45 degrees to make diamond
        gleam.zPosition = self.zPosition + 1
        gleam.alpha = 0
        gleam.texture?.filteringMode = .nearest
        
        scene.addChild(gleam)
        
        // Gleam animation: fade in, scale up, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.1)
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.1)
        let wait = SKAction.wait(forDuration: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        
        let appear = SKAction.group([fadeIn, scaleUp])
        let sequence = SKAction.sequence([appear, wait, fadeOut, remove])
        
        gleam.run(sequence)
        
        #if DEBUG
        print("✨ Gleam effect created at \(position)")
        #endif
    }
    
    // MARK: - Gravity Effect (6-Ball)
    
    // MARK: - Healing Effect (6-Ball)
    
    /// Show the healing field visual indicator
    private func showHealingField() {
        // Remove existing field if any
        healingFieldNode?.removeFromParent()
        
        // Create a pulsing circle to indicate healing field (green for healing)
        let field = SKShapeNode(circleOfRadius: healingRadius)
        field.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.3, alpha: 0.3)
        field.lineWidth = 2.0
        field.fillColor = SKColor(red: 0.0, green: 0.7, blue: 0.3, alpha: 0.05)
        field.zPosition = -1  // Behind the ball
        field.name = "healingField"
        
        // Add pulsing animation (faster than gravity to indicate active healing)
        let scaleUp = SKAction.scale(to: 1.1, duration: 1.0)
        let scaleDown = SKAction.scale(to: 0.9, duration: 1.0)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SKAction.repeatForever(pulse)
        field.run(repeatPulse)
        
        // Fade in
        field.alpha = 0
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        field.run(fadeIn)
        
        addChild(field)
        healingFieldNode = field
    }
    
    /// Hide the healing field visual indicator
    private func hideHealingField() {
        guard let field = healingFieldNode else { return }
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        field.run(SKAction.sequence([fadeOut, remove]))
        healingFieldNode = nil
    }
    
    /// Apply healing effect from this 6-ball to nearby cue balls
    /// Heals cue balls within the healing radius once per second
    /// Breaks the 6-ball after healing 30 HP total
    private func applyHealingEffect(deltaTime: TimeInterval) {
        guard let scene = self.scene ?? self.sceneRef else { return }
        
        // Increment timer
        timeSinceLastHeal += deltaTime
        
        // Only heal once per interval
        guard timeSinceLastHeal >= healingInterval else { return }
        
        // Reset timer
        timeSinceLastHeal = 0.0
        
        // Find all cue balls in the scene
        let allBalls = scene.children.compactMap { $0 as? BlockBall }
        let cueBalls = allBalls.filter { $0.ballKind == .cue }
        
        // Track if we healed anyone this tick
        var healedThisTick = false
        
        for cueBall in cueBalls {
            // Calculate distance to cue ball
            let dx = self.position.x - cueBall.position.x
            let dy = self.position.y - cueBall.position.y
            let distance = hypot(dx, dy)
            
            // Check if within healing radius
            if distance < healingRadius {
                // Get damage system from scene
                if let starScene = scene as? StarfieldScene,
                   let damageSystem = starScene.damageSystem {
                    // Heal the cue ball
                    damageSystem.heal(cueBall, amount: healingAmount)
                    
                    // Create healing visual effect
                    createHealingEffect(at: cueBall.position)
                    
                    // Track total healing
                    totalHPHealed += healingAmount
                    healedThisTick = true
                    
                    #if DEBUG
                    print("💚 6-ball healed cue ball for \(Int(healingAmount)) HP (total: \(Int(totalHPHealed))/\(Int(maxHealingTotal)))")
                    #endif
                }
            }
        }
        
        // Check if we've reached the healing limit
        if totalHPHealed >= maxHealingTotal {
            #if DEBUG
            print("💥 6-ball has healed \(Int(totalHPHealed)) HP total - breaking!")
            #endif
            
            // Break this 6-ball using the damage system
            if let starScene = scene as? StarfieldScene,
               let damageSystem = starScene.damageSystem {
                // Deal enough damage to destroy the ball
                damageSystem.applyDirectDamage(to: self, amount: 9999)
            }
        }
    }
    
    /// Create a visual healing effect at the specified position
    private func createHealingEffect(at position: CGPoint) {
        guard let scene = sceneRef ?? self.scene else { return }
        
        // Create a small green plus sign for the healing effect
        let plusSize: CGFloat = 20
        
        // Create vertical bar of the plus
        let vertical = SKSpriteNode(color: SKColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0),
                                   size: CGSize(width: 4, height: plusSize))
        vertical.position = position
        vertical.zPosition = self.zPosition + 1
        vertical.alpha = 0
        
        // Create horizontal bar of the plus
        let horizontal = SKSpriteNode(color: SKColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0),
                                     size: CGSize(width: plusSize, height: 4))
        horizontal.position = position
        horizontal.zPosition = self.zPosition + 1
        horizontal.alpha = 0
        
        scene.addChild(vertical)
        scene.addChild(horizontal)
        
        // Healing animation: fade in, float up, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        let floatAndFade = SKAction.group([moveUp, SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            fadeOut
        ])])
        let sequence = SKAction.sequence([fadeIn, floatAndFade, remove])
        
        vertical.run(sequence)
        horizontal.run(sequence)
        
        #if DEBUG
        if debugEnabled {
            print("💚 Healing effect created at \(position)")
        }
        #endif
    }
    
    // MARK: - Accessory Management
    
    /// Attach an accessory to this ball
    /// - Parameter accessoryID: The ID of the accessory to attach (e.g., "flying")
    /// - Returns: True if the accessory was successfully attached
    func attachAccessory(_ accessoryID: String) -> Bool {
        return BallAccessoryManager.shared.attachAccessory(id: accessoryID, to: self)
    }
    
    /// Remove an accessory from this ball
    /// - Parameter accessoryID: The ID of the accessory to remove
    /// - Returns: True if the accessory was successfully removed
    func removeAccessory(_ accessoryID: String) -> Bool {
        return BallAccessoryManager.shared.removeAccessory(id: accessoryID, from: self)
    }
    
    /// Check if this ball has a specific accessory attached
    /// - Parameter accessoryID: The ID of the accessory to check
    /// - Returns: True if the accessory is attached
    func hasAccessory(_ accessoryID: String) -> Bool {
        return BallAccessoryManager.shared.hasAccessory(ball: self, id: accessoryID)
    }
    
    deinit {
        // Clean up healing field
        healingFieldNode?.removeFromParent()
        
        // Clean up accessories when ball is removed
        BallAccessoryManager.shared.cleanupAccessories(for: self)
    }
    
    private func respawnCueBall() {
        #if DEBUG
        print("🔄 Respawning cue ball at table center")
        #endif
        
        // Reset state
        isSinking = false
        isUserInteractionEnabled = true
        canShoot = true
        
        // Reset visual
        visualContainer.setScale(1.0)
        visualContainer.alpha = 1.0
        
        // Move to center of felt
        let feltCenter = CGPoint(x: feltRect.midX, y: feltRect.midY)
        position = feltCenter
        
        // Re-enable physics
        physicsBody?.isDynamic = true
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        
        #if DEBUG
        print("✅ Cue ball respawned at \(position)")
        #endif
    }
}

// Helper to create polygon physics bodies from point arrays
private extension CGMutablePath {
    static func makePolygon(points: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

