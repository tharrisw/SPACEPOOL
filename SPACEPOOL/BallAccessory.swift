//
//  BallAccessory.swift
//  SpacePool
//
//  Ball accessories system - decorative sprites that move with balls and add special abilities
//
//  CRITICAL DESIGN PRINCIPLE:
//  Accessories are PURELY VISUAL decorations that add NO PHYSICS to the ball.
//  - The ball's physics body on the BlockBall node MUST NEVER be modified by accessories
//  - Accessories are added to the ball's visualContainer, which has NO physics body
//  - Wing sprites and other visual elements MUST have physicsBody = nil
//  - The ball should behave identically with or without accessories in terms of collisions
//  - The ONLY difference is that some accessories (like flying) prevent sinking into pockets
//

import SpriteKit
import UIKit

/// Base protocol for all ball accessories
/// 
/// IMPORTANT: Accessories are purely visual - they must not add physics bodies or modify
/// the ball's physics in any way. The ball should collide with rails and other balls
/// normally whether or not it has accessories attached.
protocol BallAccessoryProtocol: AnyObject {
    /// The unique identifier for this accessory type
    var id: String { get }
    
    /// The visual node that gets added to the ball
    var visualNode: SKNode { get }
    
    /// Called when the accessory is attached to a ball
    func onAttach(to ball: BlockBall)
    
    /// Called when the accessory is removed from a ball
    func onDetach(from ball: BlockBall)
    
    /// Called every frame to update accessory state
    /// - Parameters:
    ///   - ball: The ball this accessory is attached to
    ///   - deltaTime: Time since last update
    func update(ball: BlockBall, deltaTime: TimeInterval)
    
    /// Check if this accessory prevents the ball from sinking
    var preventsSinking: Bool { get }
}

/// Flying accessory - displays wings when ball is over a pocket and prevents sinking
/// Wings are completely independent nodes added directly to the scene, not attached to the ball
final class FlyingAccessory: BallAccessoryProtocol {
    let id = "flying"
    let visualNode = SKNode()  // Empty placeholder - not used for this accessory
    var preventsSinking: Bool { return true }
    
    // Wing sprites (added directly to scene, not to ball)
    private(set) var leftWing: SKSpriteNode?  // Changed to internal for debugging
    private(set) var rightWing: SKSpriteNode?  // Changed to internal for debugging
    private var wingsVisible = false
    
    // Reference to the scene where wings are drawn
    private weak var scene: SKScene?
    
    // Wing configuration
    private let wingOffsetX: CGFloat = 15  // Distance from ball center
    private let wingOffsetY: CGFloat = 0   // Vertical offset
    private let blockSize: CGFloat = 5.0
    
    // Rescue flight state
    private var isRescueFlying = false
    private var timeAtRest: TimeInterval = 0
    private let rescueFlightDelay: TimeInterval = 1.0  // Wait 1 second before rescue
    private let rescueFlightDuration: TimeInterval = 1.5  // Flight takes 1.5 seconds
    
    init() {
        // Wings will be created when attached to a ball (so we have access to the scene)
    }
    
    private func setupWings(in scene: SKScene, ball: BlockBall) {
        self.scene = scene
        
        // Create left wing - add directly to scene, NOT to ball
        let leftWingTexture = generateWingTexture(facingRight: false)
        let leftWingSprite = SKSpriteNode(texture: leftWingTexture)
        leftWingSprite.name = "leftWing_\(ObjectIdentifier(ball))"  // Unique name per ball
        leftWingSprite.zPosition = 999  // Behind the ball but above most other things
        leftWingSprite.alpha = 0  // Start invisible
        leftWingSprite.isUserInteractionEnabled = false
        leftWingSprite.physicsBody = nil  // CRITICAL: No physics
        leftWing = leftWingSprite
        scene.addChild(leftWingSprite)  // Add directly to scene
        
        // Create right wing - add directly to scene, NOT to ball
        let rightWingTexture = generateWingTexture(facingRight: true)
        let rightWingSprite = SKSpriteNode(texture: rightWingTexture)
        rightWingSprite.name = "rightWing_\(ObjectIdentifier(ball))"  // Unique name per ball
        rightWingSprite.zPosition = 999  // Behind the ball but above most other things
        rightWingSprite.alpha = 0  // Start invisible
        rightWingSprite.isUserInteractionEnabled = false
        rightWingSprite.physicsBody = nil  // CRITICAL: No physics
        rightWing = rightWingSprite
        scene.addChild(rightWingSprite)  // Add directly to scene
        
        // Initial position update
        updateWingPositions(ball: ball)
        
        #if DEBUG
        print("🪽 Wings created as independent scene nodes (NOT attached to ball)")
        print("   Left wing physics: \(leftWingSprite.physicsBody != nil ? "EXISTS (BAD!)" : "nil (good)")")
        print("   Right wing physics: \(rightWingSprite.physicsBody != nil ? "EXISTS (BAD!)" : "nil (good)")")
        #endif
    }
    
    private func updateWingPositions(ball: BlockBall) {
        // Position wings relative to ball's world position
        let ballPosition = ball.position
        let yOffset = wingOffsetY + flappingOffset
        leftWing?.position = CGPoint(x: ballPosition.x - wingOffsetX, y: ballPosition.y + yOffset)
        rightWing?.position = CGPoint(x: ballPosition.x + wingOffsetX, y: ballPosition.y + yOffset)
    }
    
    /// Generate a wing texture made of blocks
    /// Wing is 4 blocks wide and 3 blocks tall with a bird-like shape
    private func generateWingTexture(facingRight: Bool) -> SKTexture {
        let wingWidth = 4
        let wingHeight = 3
        let size = CGSize(width: CGFloat(wingWidth) * blockSize, height: CGFloat(wingHeight) * blockSize)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Define wing pattern (1 = filled, 0 = empty)
            // Pattern for right wing (will be flipped for left)
            var pattern: [[Int]]
            if facingRight {
                pattern = [
                    [0, 0, 1, 1],  // Top row - wing tip
                    [0, 1, 1, 1],  // Middle row - main wing body
                    [1, 1, 1, 0]   // Bottom row - wing base
                ]
            } else {
                pattern = [
                    [1, 1, 0, 0],  // Top row - wing tip (mirrored)
                    [1, 1, 1, 0],  // Middle row - main wing body (mirrored)
                    [0, 1, 1, 1]   // Bottom row - wing base (mirrored)
                ]
            }
            
            // Draw blocks based on pattern
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setStrokeColor(UIColor(white: 0.9, alpha: 1.0).cgColor)
            ctx.setLineWidth(0.5)
            
            for row in 0..<wingHeight {
                for col in 0..<wingWidth {
                    if pattern[row][col] == 1 {
                        let x = CGFloat(col) * blockSize
                        let y = CGFloat(wingHeight - row - 1) * blockSize  // Flip Y
                        let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                        
                        // Fill block
                        ctx.fill(rect)
                        
                        // Stroke border
                        ctx.stroke(rect)
                    }
                }
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest  // Pixel-perfect rendering
        return texture
    }
    
    func onAttach(to ball: BlockBall) {
        guard let scene = ball.scene else {
            print("⚠️ Cannot attach flying accessory - ball has no scene")
            return
        }
        
        // Create wings as independent scene nodes
        setupWings(in: scene, ball: ball)
        
        print("🪽 Flying accessory attached to \(ball.ballKind) ball (wings are INDEPENDENT scene nodes)")
        
        // CRITICAL: Verify that the ball's physics body is never touched
        #if DEBUG
        if ball.physicsBody == nil {
            print("⚠️ WARNING: Ball physics body is nil! This will cause the ball to fly through walls!")
        }
        if ball.physicsBody?.isDynamic == false {
            print("⚠️ WARNING: Ball physics is not dynamic! This may cause collision issues!")
        }
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        hideWings()
        
        // Remove wings from scene
        leftWing?.removeFromParent()
        rightWing?.removeFromParent()
        leftWing = nil
        rightWing = nil
        scene = nil
        
        print("🪽 Flying accessory detached from \(ball.ballKind) ball (wings removed from scene)")
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // Don't update during rescue flight (animation handles everything)
        guard !isRescueFlying else { return }
        
        // Update wing positions to follow the ball
        updateWingPositions(ball: ball)
        
        // Check if ball is over a pocket
        let isOverPocket = ball.isOverPocket()
        
        if isOverPocket && !wingsVisible {
            showWings(ball: ball)
        } else if !isOverPocket && wingsVisible {
            hideWings()
            timeAtRest = 0  // Reset rest timer when not over pocket
        }
        
        // Add gentle flapping animation when wings are visible
        if wingsVisible {
            animateFlapping(deltaTime: deltaTime)
        }
        
        // RESCUE FLIGHT: If ball is at rest over a pocket, fly back to center
        if isOverPocket && wingsVisible {
            // Check if ball is essentially at rest
            guard let body = ball.physicsBody else { return }
            let speed = hypot(body.velocity.dx, body.velocity.dy)
            let angularSpeed = abs(body.angularVelocity)
            
            if speed < 10.0 && angularSpeed < 0.5 {
                // Ball is at rest
                timeAtRest += deltaTime
                
                if timeAtRest >= rescueFlightDelay {
                    // Trigger rescue flight!
                    print("🪽 Rescue flight triggered! Ball stuck in pocket, flying back to center...")
                    triggerRescueFlight(ball: ball)
                }
            } else {
                // Ball is still moving, reset timer
                timeAtRest = 0
            }
        }
    }
    
    private func showWings(ball: BlockBall) {
        guard !wingsVisible else { return }
        wingsVisible = true
        
        // CRITICAL DEBUG: Log physics state when wings appear
        #if DEBUG
        print("🪽 Wings deployed!")
        print("   Ball position: \(ball.position)")
        print("   Ball physics body exists: \(ball.physicsBody != nil)")
        print("   Ball isDynamic: \(ball.physicsBody?.isDynamic ?? false)")
        print("   Ball velocity: \(ball.physicsBody?.velocity ?? .zero)")
        print("   Ball collisionBitMask: \(ball.physicsBody?.collisionBitMask ?? 0) (should be 3)")
        print("   Ball categoryBitMask: \(ball.physicsBody?.categoryBitMask ?? 0) (should be 1)")
        print("   Left wing physics: \(leftWing?.physicsBody != nil) (should be false)")
        print("   Right wing physics: \(rightWing?.physicsBody != nil) (should be false)")
        print("   Wings are independent scene nodes: true")
        print("   Left wing parent: \(leftWing?.parent?.name ?? "none")")
        print("   Right wing parent: \(rightWing?.parent?.name ?? "none")")
        #else
        print("🪽 Wings deployed!")
        #endif
        
        // Fade in wings
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        leftWing?.run(fadeIn)
        rightWing?.run(fadeIn)
    }
    
    private func hideWings() {
        guard wingsVisible else { return }
        wingsVisible = false
        
        // Fade out wings
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        leftWing?.run(fadeOut)
        rightWing?.run(fadeOut)
    }
    
    // MARK: - Rescue Flight
    
    /// Trigger a rescue flight animation to return the ball to the center of the table
    /// This is called when a ball gets stuck at rest in a pocket
    private func triggerRescueFlight(ball: BlockBall) {
        guard !isRescueFlying else { return }
        guard let body = ball.physicsBody else { return }
        guard let scene = scene else { return }
        
        isRescueFlying = true
        timeAtRest = 0
        
        // Get the center of the felt (table playing area)
        let targetPosition: CGPoint
        if let starScene = scene as? StarfieldScene {
            if let feltRect = starScene.blockFeltRect {
                targetPosition = CGPoint(x: feltRect.midX, y: feltRect.midY)
            } else {
                targetPosition = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
            }
        } else {
            targetPosition = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        }
        
        let startPosition = ball.position
        
        // Store original physics state
        let originalVelocity = body.velocity
        let originalAngularVelocity = body.angularVelocity
        let originalIsDynamic = body.isDynamic
        
        // Disable physics during flight (pass through everything)
        body.velocity = .zero
        body.angularVelocity = 0
        body.isDynamic = false
        
        print("🚀 Starting rescue flight from \(startPosition) to \(targetPosition)")
        print("   Physics disabled for duration of flight")
        
        // Animate flight to center with arc trajectory
        let arcHeight: CGFloat = 100  // How high the ball rises during flight
        
        // Create a custom action that moves along an arc
        let flightAction = SKAction.customAction(withDuration: rescueFlightDuration) { [weak self] node, elapsedTime in
            guard let self = self else { return }
            
            let progress = elapsedTime / CGFloat(self.rescueFlightDuration)
            
            // Interpolate X position linearly
            let x = startPosition.x + (targetPosition.x - startPosition.x) * progress
            
            // Interpolate Y position with arc (parabola)
            // At progress 0.5, we're at max height
            let arcProgress = sin(progress * .pi)  // 0 → 1 → 0
            let y = startPosition.y + (targetPosition.y - startPosition.y) * progress + arcHeight * arcProgress
            
            node.position = CGPoint(x: x, y: y)
            
            // Update wing positions
            self.updateWingPositions(ball: ball)
            
            // FAST flapping during rescue flight (3x speed)
            self.animateFlapping(deltaTime: 0.016, speedMultiplier: 3.0)
        }
        
        // After flight completes
        let completion = SKAction.run { [weak self] in
            guard let self = self else { return }
            
            // Re-enable physics
            body.isDynamic = true
            body.velocity = .zero
            body.angularVelocity = 0
            
            print("✅ Rescue flight complete! Ball returned to center")
            print("   Physics re-enabled")
            
            // Reset state
            self.isRescueFlying = false
            self.timeAtRest = 0
            
            // Hide wings after a brief delay
            let delay = SKAction.wait(forDuration: 0.5)
            let hideAction = SKAction.run { [weak self] in
                self?.hideWings()
            }
            ball.run(SKAction.sequence([delay, hideAction]))
        }
        
        let sequence = SKAction.sequence([flightAction, completion])
        ball.run(sequence, withKey: "rescueFlight")
    }
    
    private var flappingTime: TimeInterval = 0
    private var flappingOffset: CGFloat = 0
    
    private func animateFlapping(deltaTime: TimeInterval, speedMultiplier: CGFloat = 1.0) {
        flappingTime += deltaTime
        
        // Gentle up-down motion (slow flapping normally, faster during rescue)
        let baseFlapSpeed: CGFloat = 3.0  // Radians per second
        let flapSpeed: CGFloat = baseFlapSpeed * speedMultiplier
        let flapAmplitude: CGFloat = 2.0  // Pixels
        
        flappingOffset = sin(CGFloat(flappingTime) * flapSpeed) * flapAmplitude
        
        // The offset will be applied in updateWingPositions
    }
}

/// Hat accessory - purely cosmetic decoration that sits on top of the ball
/// Hats have no physics impact and don't prevent sinking
final class HatAccessory: BallAccessoryProtocol {
    let id: String
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private let blockSize: CGFloat = 5.0
    private weak var ball: BlockBall?
    
    enum HatStyle {
        case topHat      // Classic tall top hat
        case bowler      // Round bowler hat
        case baseball    // Baseball cap with visor
        case wizard      // Tall pointed wizard hat
        case cowboy      // Western cowboy hat
    }
    
    private let style: HatStyle
    
    init(style: HatStyle) {
        self.style = style
        self.id = "hat_\(style)"
    }
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Create hat visual based on style
        let hatNode = createHatNode()
        // Position lower to overlap with ball - makes it look like the ball is wearing it
        // Ball radius is ~12.5, so positioning at y: 5 puts the brim inside the top of the ball
        hatNode.position = CGPoint(x: 0, y: 5)
        hatNode.zPosition = 10 // Above ball
        visualNode.addChild(hatNode)
        
        // Add visual node to ball's visual container (no physics!)
        ball.visualContainer.addChild(visualNode)
        
        #if DEBUG
        print("🎩 Hat accessory '\(style)' attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        visualNode.removeFromParent()
        self.ball = nil
        
        #if DEBUG
        print("🎩 Hat accessory '\(style)' detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // Hats are purely visual - they just follow the ball automatically
        // since they're children of the visualContainer
        
        // Optional: Add slight bobbing animation when ball is moving
        guard let body = ball.physicsBody else { return }
        let speed = hypot(body.velocity.dx, body.velocity.dy)
        
        if speed > 10 {
            // Gentle bobbing proportional to speed
            let bobAmount: CGFloat = 0.5
            let bobSpeed: CGFloat = 0.1
            let bob = sin(CGFloat(CACurrentMediaTime()) * bobSpeed * speed) * bobAmount
            visualNode.position = CGPoint(x: 0, y: bob)
        } else {
            visualNode.position = .zero
        }
    }
    
    private func createHatNode() -> SKNode {
        let container = SKNode()
        container.name = "hat_\(style)"
        
        switch style {
        case .topHat:
            createTopHat(in: container)
        case .bowler:
            createBowlerHat(in: container)
        case .baseball:
            createBaseballCap(in: container)
        case .wizard:
            createWizardHat(in: container)
        case .cowboy:
            createCowboyHat(in: container)
        }
        
        return container
    }
    
    private func createBlock(at position: CGPoint, color: UIColor) -> SKSpriteNode {
        let block = SKSpriteNode(color: color, size: CGSize(width: blockSize, height: blockSize))
        block.position = position
        
        // Add subtle border for definition
        let border = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize))
        border.strokeColor = UIColor(white: 0, alpha: 0.2)
        border.lineWidth = 0.5
        border.fillColor = .clear
        block.addChild(border)
        
        return block
    }
    
    private func createTopHat(in container: SKNode) {
        // Classic top hat - black with a band
        let black = UIColor.black
        let white = UIColor.white
        
        // Brim (wide, 5 blocks wide)
        for x in -2...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 0), color: black)
            container.addChild(block)
        }
        
        // Hat body (tall cylinder, 3 blocks wide, 4 blocks tall)
        for y in 1...4 {
            for x in -1...1 {
                let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: CGFloat(y) * blockSize), color: black)
                container.addChild(block)
            }
        }
        
        // White band (middle of hat)
        for x in -1...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 2 * blockSize), color: white)
            container.addChild(block)
        }
        
        // Top of hat
        for x in -1...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 5 * blockSize), color: black)
            container.addChild(block)
        }
    }
    
    private func createBowlerHat(in container: SKNode) {
        // Round bowler hat - brown/tan color
        let brown = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        
        // Brim (4 blocks wide)
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 0), color: brown)
            container.addChild(block)
        }
        
        // Rounded dome (getting narrower as it goes up)
        // Row 1: 4 blocks
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: blockSize), color: brown)
            container.addChild(block)
        }
        
        // Row 2: 3 blocks
        for x in 0...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 2 * blockSize), color: brown)
            container.addChild(block)
        }
        
        // Row 3: 2 blocks (top)
        for x in 0...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 3 * blockSize), color: brown)
            container.addChild(block)
        }
    }
    
    private func createBaseballCap(in container: SKNode) {
        // Baseball cap with visor - red cap with white logo
        let red = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        let white = UIColor.white
        
        // Visor (extends forward)
        for x in 0...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: blockSize), color: red)
            container.addChild(block)
        }
        
        // Cap body (rounded dome, 3 blocks wide, 2 blocks tall)
        for x in -1...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 2 * blockSize), color: red)
            container.addChild(block)
        }
        
        // Top row (narrower)
        for x in -1...0 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 3 * blockSize), color: red)
            container.addChild(block)
        }
        
        // White logo on front
        let logo = createBlock(at: CGPoint(x: 0, y: 2 * blockSize), color: white)
        container.addChild(logo)
    }
    
    private func createWizardHat(in container: SKNode) {
        // Tall pointed wizard hat - purple with stars
        let purple = UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        let yellow = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)
        
        // Brim (wide, 5 blocks)
        for x in -2...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 0), color: purple)
            container.addChild(block)
        }
        
        // Cone shape (getting narrower as it goes up)
        // Row 1: 4 blocks
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: blockSize), color: purple)
            container.addChild(block)
        }
        
        // Row 2: 3 blocks
        for x in -1...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 2 * blockSize), color: purple)
            container.addChild(block)
        }
        
        // Row 3: 3 blocks
        for x in -1...1 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 3 * blockSize), color: purple)
            container.addChild(block)
        }
        
        // Row 4: 2 blocks
        for x in -1...0 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 4 * blockSize), color: purple)
            container.addChild(block)
        }
        
        // Row 5: 1 block (tip)
        let tip = createBlock(at: CGPoint(x: 0, y: 5 * blockSize), color: purple)
        container.addChild(tip)
        
        // Add yellow star decorations
        let star1 = createBlock(at: CGPoint(x: 0, y: 2 * blockSize), color: yellow)
        container.addChild(star1)
    }
    
    private func createCowboyHat(in container: SKNode) {
        // Western cowboy hat - tan/beige with wide brim
        let tan = UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 1.0)
        let brown = UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        
        // Wide brim with curved edges (6 blocks wide, curved)
        for x in -2...3 {
            let y: CGFloat = (x == -2 || x == 3) ? -0.5 : 0 // Curve upward at edges
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: y * blockSize), color: tan)
            container.addChild(block)
        }
        
        // Crown base (4 blocks wide)
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: blockSize), color: tan)
            container.addChild(block)
        }
        
        // Crown middle (4 blocks wide, creased in center)
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 2 * blockSize), color: tan)
            container.addChild(block)
        }
        
        // Crown top (3 blocks, indented in middle for crease)
        let topLeft = createBlock(at: CGPoint(x: -blockSize, y: 3 * blockSize), color: tan)
        container.addChild(topLeft)
        
        let topRight = createBlock(at: CGPoint(x: blockSize, y: 3 * blockSize), color: tan)
        container.addChild(topRight)
        
        let topRight2 = createBlock(at: CGPoint(x: 2 * blockSize, y: 3 * blockSize), color: tan)
        container.addChild(topRight2)
        
        // Add brown band around base
        for x in -1...2 {
            let block = createBlock(at: CGPoint(x: CGFloat(x) * blockSize, y: 1.5 * blockSize), color: brown)
            container.addChild(block)
        }
    }
}

/// Burning accessory - creates flame animation that damages the ball over time
/// 7-balls are immune to burning damage
final class BurningAccessory: BallAccessoryProtocol {
    let id = "burning"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private var damageTimer: TimeInterval = 0
    private let damageInterval: TimeInterval = 0.5  // Deal damage every 0.5 seconds
    private let damageAmount: CGFloat = 1.0  // 1 HP per tick
    
    // Flame animation properties
    private var flames: [SKSpriteNode] = []
    private let blockSize: CGFloat = 5.0
    private var animationTime: TimeInterval = 0
    
    // Track if this is a temporary burning (for collision spreading)
    let isTemporary: Bool
    
    init(isTemporary: Bool = false) {
        self.isTemporary = isTemporary
    }
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Create flame animation
        createFlameAnimation()
        
        // Add visual node to ball's visual container (no physics!)
        ball.visualContainer.addChild(visualNode)
        
        #if DEBUG
        print("🔥 Burning accessory attached to \(ball.ballKind) ball")
        if ball.ballKind == .seven {
            print("   (7-ball is immune to burning damage)")
        }
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        visualNode.removeFromParent()
        flames.removeAll()
        self.ball = nil
        
        #if DEBUG
        print("🔥 Burning accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // Animate the flames
        animationTime += deltaTime
        animateFlames(deltaTime: deltaTime)
        
        // Apply damage over time (except to 7-ball which is immune)
        if ball.ballKind != .seven {
            damageTimer += deltaTime
            
            if damageTimer >= damageInterval {
                damageTimer = 0
                
                // Apply damage through the damage system
                if let scene = ball.scene as? StarfieldScene,
                   let damageSystem = scene.damageSystem {
                    damageSystem.applyDirectDamage(to: ball, amount: damageAmount)
                    
                    #if DEBUG
                    print("🔥 Burning damage: \(damageAmount) HP to \(ball.ballKind) ball")
                    #endif
                }
            }
        }
    }
    
    private func createFlameAnimation() {
        // Create multiple flame sprites at different positions
        // Flames completely engulf the ball in all directions
        
        let flamePositions: [CGPoint] = [
            // Top flames (tallest)
            CGPoint(x: -7, y: 10),   // Top-left
            CGPoint(x: 0, y: 12),    // Top-center (tallest)
            CGPoint(x: 7, y: 10),    // Top-right
            
            // Upper-middle flames
            CGPoint(x: -10, y: 7),   // Upper-left
            CGPoint(x: -4, y: 8),    // Upper-mid-left
            CGPoint(x: 4, y: 8),     // Upper-mid-right
            CGPoint(x: 10, y: 7),    // Upper-right
            
            // Middle flames (around the equator)
            CGPoint(x: -12, y: 0),   // Middle-left
            CGPoint(x: -8, y: 2),    // Mid-left-high
            CGPoint(x: -8, y: -2),   // Mid-left-low
            CGPoint(x: 8, y: 2),     // Mid-right-high
            CGPoint(x: 8, y: -2),    // Mid-right-low
            CGPoint(x: 12, y: 0),    // Middle-right
            
            // Lower flames
            CGPoint(x: -10, y: -7),  // Lower-left
            CGPoint(x: -4, y: -6),   // Lower-mid-left
            CGPoint(x: 0, y: -8),    // Bottom-center
            CGPoint(x: 4, y: -6),    // Lower-mid-right
            CGPoint(x: 10, y: -7),   // Lower-right
            
            // Additional back flames (smaller, dimmer)
            CGPoint(x: -6, y: 4),    // Fill-left
            CGPoint(x: 6, y: 4),     // Fill-right
            CGPoint(x: -6, y: -4),   // Fill-left-low
            CGPoint(x: 6, y: -4),    // Fill-right-low
        ]
        
        for (index, position) in flamePositions.enumerated() {
            // Center top flame (index 1) is tallest, others vary
            let isTall = index == 1
            let flame = createFlameSprite(tall: isTall)
            flame.position = position
            flame.zPosition = 5 // Above ball but below UI
            
            // Vary initial alpha for depth effect (flames further from camera are dimmer)
            if index >= 19 { // Back fill flames
                flame.alpha = 0.6
            }
            
            flames.append(flame)
            visualNode.addChild(flame)
        }
    }
    
    private func createFlameSprite(tall: Bool) -> SKSpriteNode {
        // Create a flame texture using blocks
        let flameWidth = 2
        let flameHeight = tall ? 4 : 3
        let size = CGSize(width: CGFloat(flameWidth) * blockSize, 
                         height: CGFloat(flameHeight) * blockSize)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Flame gradient: yellow at bottom, orange in middle, red at top
            let colors: [UIColor] = [
                UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.9),  // Yellow
                UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.85), // Orange
                UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.8),  // Red-orange
                UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.7)   // Dark red
            ]
            
            // Draw flame blocks from bottom to top
            for row in 0..<flameHeight {
                for col in 0..<flameWidth {
                    // Taper at the top (skip some blocks)
                    if row == flameHeight - 1 && col == 1 && !tall {
                        continue // Skip top-right for shorter flames
                    }
                    
                    let colorIndex = min(row, colors.count - 1)
                    let color = colors[colorIndex]
                    
                    let x = CGFloat(col) * blockSize
                    let y = CGFloat(row) * blockSize
                    let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                    
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                }
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture)
        sprite.alpha = 0.9
        
        return sprite
    }
    
    private func animateFlames(deltaTime: TimeInterval) {
        // Flickering animation: vary alpha and slight vertical movement
        let basePositions: [CGPoint] = [
            // Top flames (tallest)
            CGPoint(x: -7, y: 10),   // Top-left
            CGPoint(x: 0, y: 12),    // Top-center (tallest)
            CGPoint(x: 7, y: 10),    // Top-right
            
            // Upper-middle flames
            CGPoint(x: -10, y: 7),   // Upper-left
            CGPoint(x: -4, y: 8),    // Upper-mid-left
            CGPoint(x: 4, y: 8),     // Upper-mid-right
            CGPoint(x: 10, y: 7),    // Upper-right
            
            // Middle flames (around the equator)
            CGPoint(x: -12, y: 0),   // Middle-left
            CGPoint(x: -8, y: 2),    // Mid-left-high
            CGPoint(x: -8, y: -2),   // Mid-left-low
            CGPoint(x: 8, y: 2),     // Mid-right-high
            CGPoint(x: 8, y: -2),    // Mid-right-low
            CGPoint(x: 12, y: 0),    // Middle-right
            
            // Lower flames
            CGPoint(x: -10, y: -7),  // Lower-left
            CGPoint(x: -4, y: -6),   // Lower-mid-left
            CGPoint(x: 0, y: -8),    // Bottom-center
            CGPoint(x: 4, y: -6),    // Lower-mid-right
            CGPoint(x: 10, y: -7),   // Lower-right
            
            // Additional back flames (smaller, dimmer)
            CGPoint(x: -6, y: 4),    // Fill-left
            CGPoint(x: 6, y: 4),     // Fill-right
            CGPoint(x: -6, y: -4),   // Fill-left-low
            CGPoint(x: 6, y: -4),    // Fill-right-low
        ]
        
        for (index, flame) in flames.enumerated() {
            guard index < basePositions.count else { continue }
            
            // Each flame flickers at slightly different rates
            let phaseOffset = CGFloat(index) * 0.3
            let flickerSpeed: CGFloat = 8.0 + CGFloat(index % 5) * 0.5
            
            // Alpha flickering - back flames stay dimmer
            let baseAlpha: CGFloat = index >= 19 ? 0.6 : 0.85
            let alpha = baseAlpha + sin(CGFloat(animationTime) * flickerSpeed + phaseOffset) * 0.15
            flame.alpha = alpha
            
            // Vertical bobbing (small movement) - varies by position
            let bobAmount: CGFloat = index < 7 ? 2.0 : 1.5  // Top flames bob more
            let bobSpeed: CGFloat = 10.0 + CGFloat(index % 7)
            let yOffset = sin(CGFloat(animationTime) * bobSpeed + phaseOffset) * bobAmount
            
            // Horizontal sway for side flames
            let swayAmount: CGFloat = 0.5
            let swaySpeed: CGFloat = 6.0 + CGFloat(index % 4)
            let xOffset = cos(CGFloat(animationTime) * swaySpeed + phaseOffset) * swayAmount
            
            // Apply to position (using base position + offsets)
            let basePosition = basePositions[index]
            flame.position = CGPoint(x: basePosition.x + xOffset, y: basePosition.y + yOffset)
        }
    }
}

/// Explode On Contact accessory - causes the ball to explode instantly when hit
/// Used by 11-balls to trigger massive explosion on any collision
/// This accessory is completely invisible - no visual indicators
final class ExplodeOnContactAccessory: BallAccessoryProtocol {
    let id = "explodeOnContact"
    let visualNode = SKNode()  // Empty - no visuals for this accessory
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // No visuals - this is a pure ability accessory
        // The ball's striped appearance is enough to show it's dangerous
        
        #if DEBUG
        print("💣 Explode On Contact accessory attached to \(ball.ballKind) ball (invisible)")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        self.ball = nil
        
        #if DEBUG
        print("💣 Explode On Contact accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // No update needed - the damage system handles explosion on any damage
        // This accessory is purely a marker that changes behavior in BallDamageSystem
    }
}

/// Explode On Destroy accessory - causes the ball to explode when it's destroyed (HP reaches 0)
/// Creates a crater in the felt at the ball's final position
/// This accessory is completely invisible - no visual indicators
final class ExplodeOnDestroyAccessory: BallAccessoryProtocol {
    let id = "explodeOnDestroy"
    let visualNode = SKNode()  // Empty - no visuals for this accessory
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // No visuals - this is a pure ability accessory
        // Visual indicator could be added later (glowing outline, etc.)
        
        #if DEBUG
        print("💥 Explode On Destroy accessory attached to \(ball.ballKind) ball (invisible)")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        self.ball = nil
        
        #if DEBUG
        print("💥 Explode On Destroy accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // No update needed - the damage system handles explosion on death
        // This accessory is purely a marker that triggers behavior in BallDamageSystem
    }
}

/// Zapper accessory - unleashes lightning bolts at nearby balls when hit
/// Has a 1-second charging animation before firing
final class ZapperAccessory: BallAccessoryProtocol {
    let id = "zapper"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private var isCharging = false
    private var chargingNode: SKNode?
    
    // Configuration
    static var zapRadius: CGFloat = 150.0 // 30 blocks * 5 points per block (configurable via settings)
    private let zapDamage: CGFloat = 20.0
    private let chargeDuration: TimeInterval = 1.0
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Add visual node to ball's visual container
        ball.visualContainer.addChild(visualNode)
        
        #if DEBUG
        print("⚡ Zapper accessory attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        visualNode.removeFromParent()
        chargingNode?.removeFromParent()
        chargingNode = nil
        self.ball = nil
        
        #if DEBUG
        print("⚡ Zapper accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // This accessory is triggered by the damage system, not by update
    }
    
    /// Trigger the zapper effect (called by damage system when ball takes damage)
    func triggerZap(from ball: BlockBall, scene: SKScene) {
        guard !isCharging else {
            #if DEBUG
            print("⚡ Zapper already charging, ignoring trigger")
            #endif
            return
        }
        
        #if DEBUG
        print("⚡ Zapper triggered! Charging for \(chargeDuration)s...")
        #endif
        
        isCharging = true
        
        // Start charging animation
        startChargingAnimation(ball: ball, scene: scene)
        
        // After charge duration, unleash lightning
        DispatchQueue.main.asyncAfter(deadline: .now() + chargeDuration) { [weak self, weak ball, weak scene] in
            guard let self = self, let ball = ball, let scene = scene else { return }
            
            self.unleashLightning(from: ball, scene: scene)
            self.isCharging = false
        }
    }
    
    /// Create charging animation around the ball
    private func startChargingAnimation(ball: BlockBall, scene: SKScene) {
        // Create charging visual effect container - attach to ball so it moves with it
        let chargeContainer = SKNode()
        chargeContainer.position = .zero // Position relative to ball
        chargeContainer.zPosition = 100 // Above the ball
        ball.addChild(chargeContainer) // Attach to ball so it travels with it
        chargingNode = chargeContainer
        
        let blockSize: CGFloat = 5.0
        
        // Create rotating electric blocks around the ball
        // 3 rings of blocks at different radii
        for ringIndex in 0..<3 {
            let radius = CGFloat(20 + ringIndex * 15) // 20, 35, 50
            let blockCount = 8 + ringIndex * 4 // 8, 12, 16 blocks per ring
            
            for blockIndex in 0..<blockCount {
                let block = SKSpriteNode(color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.9), 
                                        size: CGSize(width: blockSize, height: blockSize))
                block.alpha = 0.0
                
                // Position blocks in a circle
                let angle = (CGFloat(blockIndex) / CGFloat(blockCount)) * 2 * .pi
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                block.position = CGPoint(x: x, y: y)
                
                chargeContainer.addChild(block)
                
                // Fade in
                let fadeIn = SKAction.fadeIn(withDuration: 0.3)
                
                // Rotate the entire ring
                let rotationSpeed = ringIndex % 2 == 0 ? 1.0 : -1.0
                let rotate = SKAction.customAction(withDuration: chargeDuration) { node, time in
                    let progress = time / CGFloat(self.chargeDuration)
                    let newAngle = angle + (.pi * 2 * progress * rotationSpeed)
                    let newX = cos(newAngle) * radius
                    let newY = sin(newAngle) * radius
                    node.position = CGPoint(x: newX, y: newY)
                }
                
                // Flicker effect
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.6, duration: 0.15),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                ])
                let flickerForever = SKAction.repeatForever(flicker)
                
                block.run(SKAction.sequence([
                    fadeIn,
                    SKAction.group([rotate, flickerForever])
                ]))
            }
        }
        
        // Add crackling energy blocks that orbit randomly
        for _ in 0..<12 {
            let particle = SKSpriteNode(color: .cyan, size: CGSize(width: blockSize, height: blockSize))
            particle.alpha = 0.0
            particle.position = .zero
            chargeContainer.addChild(particle)
            
            // Random orbit animation
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let radius = CGFloat.random(in: 20...50)
            let duration = TimeInterval.random(in: 0.4...0.8)
            
            let fadeIn = SKAction.fadeIn(withDuration: 0.2)
            
            let orbit = SKAction.customAction(withDuration: chargeDuration) { node, time in
                let progress = time / CGFloat(self.chargeDuration)
                let currentAngle = angle + progress * .pi * 6
                let x = cos(currentAngle) * radius
                let y = sin(currentAngle) * radius
                node.position = CGPoint(x: x, y: y)
            }
            
            let flicker = SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.fadeIn(withDuration: 0.1)
            ])
            
            particle.run(SKAction.sequence([
                fadeIn,
                SKAction.group([
                    orbit,
                    SKAction.repeatForever(flicker)
                ])
            ]))
        }
        
        // Remove charging node after animation
        chargeContainer.run(SKAction.sequence([
            SKAction.wait(forDuration: chargeDuration + 0.2),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
    
    /// Unleash lightning bolts at all nearby balls
    private func unleashLightning(from ball: BlockBall, scene: SKScene) {
        #if DEBUG
        print("⚡⚡⚡ LIGHTNING UNLEASHED from \(ball.ballKind) ball!")
        #endif
        
        // Find all balls within zap radius
        guard let starScene = scene as? StarfieldScene else { return }
        
        var targets: [BlockBall] = []
        for case let targetBall as BlockBall in scene.children {
            guard targetBall !== ball else { continue }
            
            let dx = targetBall.position.x - ball.position.x
            let dy = targetBall.position.y - ball.position.y
            let distance = hypot(dx, dy)
            
            if distance <= ZapperAccessory.zapRadius {
                targets.append(targetBall)
            }
        }
        
        #if DEBUG
        print("⚡ Found \(targets.count) targets within \(ZapperAccessory.zapRadius) points")
        #endif
        
        // Fire lightning at each target
        for target in targets {
            fireLightningBolt(from: ball.position, to: target, scene: starScene)
        }
    }
    
    /// Fire a single lightning bolt at a target
    private func fireLightningBolt(from start: CGPoint, to target: BlockBall, scene: StarfieldScene) {
        let targetPos = target.position
        
        // Create jagged lightning path
        let path = createJaggedLightningPath(from: start, to: targetPos)
        
        // Create lightning visual
        let lightning = SKShapeNode(path: path)
        lightning.strokeColor = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        lightning.lineWidth = 3.0
        lightning.glowWidth = 8.0
        lightning.zPosition = 2500
        scene.addChild(lightning)
        
        // Add glow effect
        let glow = SKShapeNode(path: path)
        glow.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6)
        glow.lineWidth = 8.0
        glow.zPosition = 2499
        scene.addChild(glow)
        
        // Flash animation
        let flash = SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.fadeOut(withDuration: 0.1)
        ])
        lightning.run(SKAction.sequence([flash, SKAction.removeFromParent()]))
        glow.run(SKAction.sequence([flash, SKAction.removeFromParent()]))
        
        // Scorch the felt along the lightning path
        scorchFeltAlongPath(path: path, scene: scene)
        
        // Apply damage to target
        if let damageSystem = scene.damageSystem {
            damageSystem.applyDirectDamage(to: target, amount: zapDamage)
            
            #if DEBUG
            print("⚡ Lightning hit \(target.ballKind) ball for \(zapDamage) damage!")
            #endif
        }
        
        // Create impact flash at target
        let impactFlash = SKShapeNode(circleOfRadius: 15)
        impactFlash.fillColor = .white
        impactFlash.strokeColor = .clear
        impactFlash.position = targetPos
        impactFlash.zPosition = 2501
        impactFlash.alpha = 0.8
        scene.addChild(impactFlash)
        
        let impactAnim = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15)
            ]),
            SKAction.removeFromParent()
        ])
        impactFlash.run(impactAnim)
    }
    
    /// Create a jagged lightning path using CGPath
    private func createJaggedLightningPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let segments = Int(distance / 10) // One segment every 10 points
        
        var currentPoint = start
        
        for i in 1..<segments {
            let progress = CGFloat(i) / CGFloat(segments)
            
            // Base position along straight line
            let baseX = start.x + dx * progress
            let baseY = start.y + dy * progress
            
            // Add random perpendicular offset for jaggedness
            let perpX = -dy / distance
            let perpY = dx / distance
            let offset = CGFloat.random(in: -15...15)
            
            let jaggedX = baseX + perpX * offset
            let jaggedY = baseY + perpY * offset
            
            currentPoint = CGPoint(x: jaggedX, y: jaggedY)
            path.addLine(to: currentPoint)
        }
        
        // Final point is exactly the target
        path.addLine(to: end)
        
        return path
    }
    
    /// Scorch the felt along the lightning path
    private func scorchFeltAlongPath(path: CGPath, scene: StarfieldScene) {
        guard let feltManager = scene.feltManager else { return }
        
        // Sample points along the path and scorch them
        let pathLength = path.approximateLength()
        let sampleInterval: CGFloat = 5.0 // Sample every 5 points
        let sampleCount = Int(pathLength / sampleInterval)
        
        for i in 0...sampleCount {
            let progress = CGFloat(i) / CGFloat(sampleCount)
            if let point = path.point(at: progress) {
                feltManager.trackBurningBallPosition(at: point, scene: scene)
            }
        }
    }
}

// MARK: - CGPath Extensions for Lightning
extension CGPath {
    /// Approximate the length of a path
    func approximateLength() -> CGFloat {
        var length: CGFloat = 0
        var previousPoint: CGPoint?
        
        self.applyWithBlock { element in
            let points = element.pointee.points
            let point: CGPoint
            
            switch element.pointee.type {
            case .moveToPoint:
                point = points[0]
            case .addLineToPoint:
                point = points[0]
                if let prev = previousPoint {
                    length += hypot(point.x - prev.x, point.y - prev.y)
                }
            case .addQuadCurveToPoint:
                point = points[1]
                if let prev = previousPoint {
                    length += hypot(point.x - prev.x, point.y - prev.y)
                }
            case .addCurveToPoint:
                point = points[2]
                if let prev = previousPoint {
                    length += hypot(point.x - prev.x, point.y - prev.y)
                }
            case .closeSubpath:
                return
            @unknown default:
                return
            }
            
            previousPoint = point
        }
        
        return length
    }
    
    /// Get a point at a specific progress along the path (0.0 to 1.0)
    func point(at progress: CGFloat) -> CGPoint? {
        let targetLength = approximateLength() * progress
        var currentLength: CGFloat = 0
        var previousPoint: CGPoint?
        var resultPoint: CGPoint?
        
        self.applyWithBlock { element in
            guard resultPoint == nil else { return }
            
            let points = element.pointee.points
            let point: CGPoint
            
            switch element.pointee.type {
            case .moveToPoint:
                point = points[0]
                previousPoint = point
                return
            case .addLineToPoint:
                point = points[0]
            case .addQuadCurveToPoint:
                point = points[1]
            case .addCurveToPoint:
                point = points[2]
            case .closeSubpath:
                return
            @unknown default:
                return
            }
            
            if let prev = previousPoint {
                let segmentLength = hypot(point.x - prev.x, point.y - prev.y)
                
                if currentLength + segmentLength >= targetLength {
                    // Target is in this segment
                    let ratio = (targetLength - currentLength) / segmentLength
                    resultPoint = CGPoint(
                        x: prev.x + (point.x - prev.x) * ratio,
                        y: prev.y + (point.y - prev.y) * ratio
                    )
                    return
                }
                
                currentLength += segmentLength
            }
            
            previousPoint = point
        }
        
        return resultPoint ?? previousPoint
    }
}

/// Speedy accessory - makes the ball move twice as fast and receive double impulses
/// The ball moves at 2x velocity and receives 2x power from collisions
final class SpeedyAccessory: BallAccessoryProtocol {
    let id = "speedy"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private let speedMultiplier: CGFloat = 2.0
    
    // Visual indicator
    private var speedLinesContainer: SKNode?
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Add visual speed lines indicator
        createSpeedLines(on: ball)
        
        #if DEBUG
        print("⚡ Speedy accessory attached to \(ball.ballKind) ball (2x speed/power)")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        speedLinesContainer?.removeFromParent()
        speedLinesContainer = nil
        self.ball = nil
        
        #if DEBUG
        print("⚡ Speedy accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        guard let body = ball.physicsBody else { return }
        
        // Apply 2x speed multiplier to current velocity every frame
        // This ensures the ball is always moving at double speed
        let currentSpeed = hypot(body.velocity.dx, body.velocity.dy)
        
        // Only apply boost if ball is moving (avoid boosting from rest)
        if currentSpeed > 5.0 {
            // The speed lines should be more visible when moving faster
            updateSpeedLinesVisibility(speed: currentSpeed)
        } else {
            // Hide speed lines when not moving
            speedLinesContainer?.alpha = 0
        }
    }
    
    /// Create speed lines visual effect
    private func createSpeedLines(on ball: BlockBall) {
        let container = SKNode()
        container.name = "speedLines"
        container.zPosition = -0.5  // Behind the ball but in front of healing/gravity fields
        
        // Create 4 speed lines at cardinal directions
        let lineLength: CGFloat = 15
        let lineWidth: CGFloat = 2
        let lineColor = SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.8)  // Yellow/orange
        
        for i in 0..<4 {
            let angle = CGFloat(i) * (.pi / 2)  // 0°, 90°, 180°, 270°
            let distance: CGFloat = 18  // Distance from ball center
            
            let line = SKSpriteNode(color: lineColor, size: CGSize(width: lineWidth, height: lineLength))
            line.position = CGPoint(
                x: cos(angle) * distance,
                y: sin(angle) * distance
            )
            line.zRotation = angle + .pi / 2  // Rotate to point outward
            line.alpha = 0
            
            container.addChild(line)
        }
        
        // Pulsing animation
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.3)
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.3)
        let pulse = SKAction.sequence([fadeIn, fadeOut])
        let repeatPulse = SKAction.repeatForever(pulse)
        
        for child in container.children {
            child.run(repeatPulse)
        }
        
        ball.addChild(container)
        speedLinesContainer = container
    }
    
    /// Update speed lines visibility based on current speed
    private func updateSpeedLinesVisibility(speed: CGFloat) {
        guard let container = speedLinesContainer else { return }
        
        // Speed lines fade in as ball moves faster
        let minSpeed: CGFloat = 10
        let maxSpeed: CGFloat = 300
        let speedRatio = min(max((speed - minSpeed) / (maxSpeed - minSpeed), 0), 1)
        
        container.alpha = speedRatio * 0.8
    }
    
    /// Apply velocity boost when ball receives an impulse
    /// This is called by the collision system to amplify impulses
    func amplifyImpulse(_ impulse: CGVector) -> CGVector {
        return CGVector(dx: impulse.dx * speedMultiplier, dy: impulse.dy * speedMultiplier)
    }
}

/// Healing accessory - heals nearby cue balls when the ball is at rest
/// Used by 6-balls to provide healing support
final class HealingAccessory: BallAccessoryProtocol {
    let id = "healing"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    
    // Healing state
    private var hasMovedOnce = false
    private var isHealingActive = false
    private var timeSinceLastHeal: TimeInterval = 0.0
    private var totalHPHealed: CGFloat = 0.0
    private var healingFieldNode: SKShapeNode?
    
    // Configuration
    static var healingRadius: CGFloat = 150.0 // Configurable via settings
    private let healingAmount: CGFloat = 10.0
    private let healingInterval: TimeInterval = 1.0
    private let maxHealingTotal: CGFloat = 30.0
    private let restLinearSpeedThreshold: CGFloat = 5.0
    private let restAngularSpeedThreshold: CGFloat = 0.5
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        #if DEBUG
        print("💚 Healing accessory attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        healingFieldNode?.removeFromParent()
        healingFieldNode = nil
        self.ball = nil
        
        #if DEBUG
        print("💚 Healing accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        guard let body = ball.physicsBody else { return }
        
        let linearSpeed = hypot(body.velocity.dx, body.velocity.dy)
        let angularSpeed = abs(body.angularVelocity)
        
        // Track if ball has moved for the first time
        if !hasMovedOnce && linearSpeed > 1.0 {
            hasMovedOnce = true
            #if DEBUG
            print("💚 6-ball has moved for the first time - healing will activate when it comes to rest")
            #endif
        }
        
        // Only activate healing after ball has moved at least once
        guard hasMovedOnce else { return }
        
        // Check if ball is at rest
        let isAtRest = (linearSpeed < restLinearSpeedThreshold && angularSpeed < restAngularSpeedThreshold)
        
        if isAtRest {
            if !isHealingActive {
                isHealingActive = true
                showHealingField(on: ball)
                #if DEBUG
                print("💚 6-ball healing ACTIVATED (ball at rest)")
                #endif
            }
        } else {
            if isHealingActive {
                isHealingActive = false
                hideHealingField()
                timeSinceLastHeal = 0.0
                #if DEBUG
                print("💚 6-ball healing DEACTIVATED (ball moving)")
                #endif
            }
        }
        
        // Apply healing if active
        if isHealingActive {
            applyHealingEffect(from: ball, deltaTime: deltaTime)
        }
    }
    
    /// Show the healing field visual indicator
    private func showHealingField(on ball: BlockBall) {
        // Remove existing field if any
        healingFieldNode?.removeFromParent()
        
        // Create a pulsing circle to indicate healing field
        let field = SKShapeNode(circleOfRadius: HealingAccessory.healingRadius)
        field.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.3, alpha: 0.3)
        field.lineWidth = 2.0
        field.fillColor = SKColor(red: 0.0, green: 0.7, blue: 0.3, alpha: 0.05)
        field.zPosition = -1
        field.name = "healingField"
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 1.0)
        let scaleDown = SKAction.scale(to: 0.9, duration: 1.0)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SKAction.repeatForever(pulse)
        field.run(repeatPulse)
        
        // Fade in
        field.alpha = 0
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        field.run(fadeIn)
        
        ball.addChild(field)
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
    
    /// Apply healing effect to nearby cue balls
    private func applyHealingEffect(from ball: BlockBall, deltaTime: TimeInterval) {
        guard let scene = ball.scene ?? ball.sceneRef else { return }
        
        // Increment timer
        timeSinceLastHeal += deltaTime
        
        // Only heal once per interval
        guard timeSinceLastHeal >= healingInterval else { return }
        
        // Reset timer
        timeSinceLastHeal = 0.0
        
        // Find all cue balls in the scene
        let allBalls = scene.children.compactMap { $0 as? BlockBall }
        let cueBalls = allBalls.filter { $0.ballKind == .cue }
        
        for cueBall in cueBalls {
            // Calculate distance to cue ball
            let dx = ball.position.x - cueBall.position.x
            let dy = ball.position.y - cueBall.position.y
            let distance = hypot(dx, dy)
            
            // Check if within healing radius
            if distance < HealingAccessory.healingRadius {
                // Get damage system from scene
                if let starScene = scene as? StarfieldScene,
                   let damageSystem = starScene.damageSystem {
                    // Heal the cue ball
                    damageSystem.heal(cueBall, amount: healingAmount)
                    
                    // Create healing visual effect
                    createHealingEffect(at: cueBall.position, in: scene)
                    
                    // Track total healing
                    totalHPHealed += healingAmount
                    
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
                damageSystem.applyDirectDamage(to: ball, amount: 9999)
            }
        }
    }
    
    /// Create a visual healing effect at the specified position
    private func createHealingEffect(at position: CGPoint, in scene: SKScene) {
        let plusSize: CGFloat = 20
        
        // Create vertical bar of the plus
        let vertical = SKSpriteNode(color: SKColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0),
                                   size: CGSize(width: 4, height: plusSize))
        vertical.position = position
        vertical.zPosition = 1001
        vertical.alpha = 0
        
        // Create horizontal bar of the plus
        let horizontal = SKSpriteNode(color: SKColor(red: 0.0, green: 1.0, blue: 0.3, alpha: 1.0),
                                     size: CGSize(width: plusSize, height: 4))
        horizontal.position = position
        horizontal.zPosition = 1001
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
    }
}

/// Pulse accessory - charges for 1 second then releases a damaging pulse when hit
/// Used by 4-balls to create area-of-effect damage
/// Configuration is read from BallDamageSystem.config at runtime
final class PulseAccessory: BallAccessoryProtocol {
    let id = "pulse"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private var isCharging = false
    private var chargingNode: SKNode?
    
    private var triggerCount: Int = 0
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // No permanent visuals - charging animation is shown when triggered
        
        #if DEBUG
        print("💜 Pulse accessory attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        visualNode.removeFromParent()
        chargingNode?.removeFromParent()
        chargingNode = nil
        self.ball = nil
        
        #if DEBUG
        print("💜 Pulse accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // This accessory is triggered by the damage system, not by update
    }
    
    /// Trigger the pulse effect (called by damage system when ball takes damage)
    func triggerPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
        guard !isCharging else {
            #if DEBUG
            print("💜 Pulse already charging, ignoring trigger")
            #endif
            return
        }
        
        // Read configuration from damage system
        let pulseDelay = damageSystem.config.pulseDamageDelay
        let maxTriggers = damageSystem.config.pulseDamageMaxTriggers
        
        #if DEBUG
        print("💜 Pulse triggered! Charging for \(pulseDelay)s...")
        #endif
        
        // Increment trigger count
        triggerCount += 1
        
        let shouldDestroyAfter = (triggerCount >= maxTriggers)
        
        #if DEBUG
        print("💜 Pulse trigger count: \(triggerCount)/\(maxTriggers)")
        #endif
        
        isCharging = true
        
        // Start charging animation (blocky ring that follows the ball)
        startChargingAnimation(ball: ball, pulseDelay: pulseDelay)
        
        // After delay, unleash pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + pulseDelay) { [weak self, weak ball] in
            guard let self = self, let ball = ball else { return }
            
            // Get damage system from scene
            guard let scene = ball.scene as? StarfieldScene,
                  let damageSystem = scene.damageSystem else {
                self.isCharging = false
                return
            }
            
            self.unleashPulse(from: ball, damageSystem: damageSystem)
            self.isCharging = false
            
            // Destroy ball if it reached max triggers
            if shouldDestroyAfter {
                #if DEBUG
                print("💜 Pulse ball reached max triggers, destroying!")
                #endif
                damageSystem.applyDirectDamage(to: ball, amount: 9999)
            }
        }
    }
    
    /// Create charging animation around the ball (blocky ring that follows it)
    private func startChargingAnimation(ball: BlockBall, pulseDelay: TimeInterval) {
        let blockSize: CGFloat = 5.0
        
        // Create a container node that will be a child of the 4-ball (travels with it)
        let chargeContainer = SKNode()
        chargeContainer.name = "pulseChargeEffect"
        chargeContainer.zPosition = -1  // Behind the ball
        ball.addChild(chargeContainer)
        chargingNode = chargeContainer
        
        // Create blocky ring around the ball using 5x5 pixel blocks
        let ringRadius: CGFloat = 20.0
        let blockCount = 16
        
        var blocks: [SKSpriteNode] = []
        
        for i in 0..<blockCount {
            let angle = (CGFloat(i) / CGFloat(blockCount)) * .pi * 2
            let x = cos(angle) * ringRadius
            let y = sin(angle) * ringRadius
            
            let block = SKSpriteNode(color: SKColor.systemPurple, size: CGSize(width: blockSize, height: blockSize))
            block.position = CGPoint(x: x, y: y)
            block.alpha = 0
            block.texture?.filteringMode = .nearest
            chargeContainer.addChild(block)
            blocks.append(block)
        }
        
        // Fade in quickly
        let fadeIn = SKAction.fadeAlpha(to: 0.7, duration: 0.15)
        
        // Pulsing animation during charge
        let pulseOut = SKAction.group([
            SKAction.scale(to: 1.4, duration: 0.3),
            SKAction.fadeAlpha(to: 0.9, duration: 0.3)
        ])
        let pulseIn = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.3),
            SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        ])
        let pulse = SKAction.sequence([pulseOut, pulseIn])
        let pulseCount = Int(pulseDelay / 0.6)
        let repeatPulse = SKAction.repeat(pulse, count: pulseCount)
        
        // Color shift during charge
        let colorShiftDuration = pulseDelay / 4
        let colorToPink = SKAction.run {
            blocks.forEach { $0.color = SKColor.systemPink }
        }
        let colorToPurple = SKAction.run {
            blocks.forEach { $0.color = SKColor.systemPurple }
        }
        let colorShift = SKAction.sequence([
            SKAction.wait(forDuration: colorShiftDuration),
            colorToPink,
            SKAction.wait(forDuration: colorShiftDuration),
            colorToPurple,
            SKAction.wait(forDuration: colorShiftDuration),
            colorToPink,
            SKAction.wait(forDuration: colorShiftDuration),
            colorToPurple
        ])
        
        // Final flash before pulse
        let finalFlash = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.1),
            SKAction.fadeAlpha(to: 0.0, duration: 0.1)
        ])
        
        // Apply animations to all blocks
        for block in blocks {
            block.run(fadeIn)
        }
        
        // Run pulse and color shift on container
        chargeContainer.run(SKAction.sequence([
            SKAction.group([repeatPulse, colorShift]),
            SKAction.run { [weak chargeContainer] in
                chargeContainer?.children.forEach { $0.run(finalFlash) }
            },
            SKAction.wait(forDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
    
    /// Unleash the pulse wave that damages nearby balls
    private func unleashPulse(from ball: BlockBall, damageSystem: BallDamageSystem) {
        guard let scene = ball.scene else { return }
        
        // Read configuration from damage system
        let radiusInBlocks = damageSystem.config.pulseDamageRadius
        let blockSize: CGFloat = 5.0
        let radius = radiusInBlocks * blockSize  // Convert blocks to points
        let center = ball.position
        
        #if DEBUG
        print("💜💜💜 PULSE UNLEASHED from \(ball.ballKind) ball! Radius: \(radiusInBlocks) blocks (\(radius) pts)")
        #endif
        
        // Visual: colorful changing translucent circle that expands to radius
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.position = center
        ring.zPosition = 3500
        ring.lineWidth = 7.0
        ring.fillColor = SKColor.clear
        ring.strokeColor = SKColor.systemPurple
        ring.alpha = 0.7
        scene.addChild(ring)
        
        // Outer ring for double-ring effect
        let outerRing = SKShapeNode(circleOfRadius: 8)
        outerRing.position = center
        outerRing.zPosition = 3499
        outerRing.lineWidth = 4.5
        outerRing.fillColor = SKColor.clear
        outerRing.strokeColor = SKColor.systemPurple.withAlphaComponent(0.3)
        outerRing.alpha = 0.5
        scene.addChild(outerRing)
        
        // Color cycle
        let colors: [SKColor] = [
            SKColor(red: 0.5, green: 0.0, blue: 0.9, alpha: 1.0),
            SKColor(red: 0.9, green: 0.0, blue: 0.7, alpha: 1.0),
            SKColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 1.0),
            SKColor(red: 0.9, green: 0.0, blue: 0.9, alpha: 1.0),
            SKColor(red: 0.9, green: 0.4, blue: 0.0, alpha: 1.0),
            SKColor(red: 0.3, green: 0.3, blue: 0.9, alpha: 1.0),
            SKColor(red: 0.6, green: 0.0, blue: 0.9, alpha: 1.0)
        ]
        let wait = SKAction.wait(forDuration: 0.05)
        var sequence: [SKAction] = []
        for color in colors {
            let setColor = SKAction.run { [weak ring, weak outerRing] in
                ring?.strokeColor = color
                outerRing?.strokeColor = color.withAlphaComponent(0.3)
            }
            sequence.append(setColor)
            sequence.append(wait)
        }
        let cycle = SKAction.sequence(sequence)
        let repeatCycle = SKAction.repeatForever(cycle)
        ring.run(repeatCycle)
        outerRing.run(repeatCycle)
        
        // Expand and fade
        let expand = SKAction.scale(to: radius / 8.0, duration: 0.55)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.55)
        let group = SKAction.group([expand, fade])
        let remove = SKAction.removeFromParent()
        ring.run(SKAction.sequence([group, remove]))
        
        let outerExpand = SKAction.scale(to: (radius / 8.0) * 1.15, duration: 0.6)
        outerExpand.timingMode = .easeOut
        let outerFade = SKAction.fadeOut(withDuration: 0.6)
        let outerGroup = SKAction.group([outerExpand, outerFade])
        outerRing.run(SKAction.sequence([outerGroup, remove]))
        
        // Find targets and apply damage
        let maxEffectRadius = radius + 5.0
        var victims: [(ball: BlockBall, distance: CGFloat)] = []
        
        for case let targetBall as BlockBall in scene.children {
            guard targetBall !== ball else { continue }
            
            // Skip cue balls - they are immune to pulse
            if targetBall.ballKind == .cue {
                continue
            }
            
            let dx = targetBall.position.x - center.x
            let dy = targetBall.position.y - center.y
            let dist = hypot(dx, dy)
            
            if dist <= maxEffectRadius {
                victims.append((ball: targetBall, distance: dist))
            }
        }
        
        #if DEBUG
        print("💜 Pulse found \(victims.count) victims within \(radius) points")
        #endif
        
        // Apply damage with falloff
        for victim in victims {
            let distance = victim.distance
            
            if distance <= radius {
                // Core zone: full damage (instant kill)
                damageSystem.performDisintegrationAnimation(on: victim.ball, intensity: 1.0)
                damageSystem.applyDirectDamage(to: victim.ball, amount: 9999)
            } else {
                // Falloff zone: scaled damage
                let falloffDistance = distance - radius
                let falloffRatio = 1.0 - (falloffDistance / 5.0)
                
                damageSystem.performDisintegrationAnimation(on: victim.ball, intensity: falloffRatio)
                
                let scaledDamage = 100.0 * falloffRatio
                damageSystem.applyDirectDamage(to: victim.ball, amount: scaledDamage)
            }
        }
    }
}

/// Spawner accessory - spawns a new cue ball when this ball takes damage from a cue ball
/// Used by 2-balls to duplicate the cue ball on contact
final class SpawnerAccessory: BallAccessoryProtocol {
    let id = "spawner"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // No visuals - this is a pure ability accessory
        // The ball's color/appearance is enough to show it has this ability
        
        #if DEBUG
        print("🔵 Spawner accessory attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        self.ball = nil
        
        #if DEBUG
        print("🔵 Spawner accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // No update needed - the damage system handles spawning on damage
        // This accessory is purely a marker that triggers behavior in BallDamageSystem
    }
    
    /// Trigger the spawner effect (called by damage system when ball takes damage from a cue ball)
    func triggerSpawn(from ball: BlockBall, source: BlockBall, damageSystem: BallDamageSystem?) {
        // Get scene and geometry
        guard let scene = ball.scene ?? ball.sceneRef else {
            #if DEBUG
            print("❌ Spawner: Cannot spawn - ball has no scene")
            #endif
            return
        }
        
        let starfieldScene = scene as? StarfieldScene
        var feltRect: CGRect = starfieldScene?.blockFeltRect ?? scene.frame
        var pocketCenters: [CGPoint] = starfieldScene?.blockPocketCenters ?? []
        var pocketRadius: CGFloat = starfieldScene?.blockPocketRadius ?? 0
        
        // Helper: Check if spawn position is valid (not in hole, not on another ball)
        func isValidSpawn(_ p: CGPoint) -> Bool {
            // Check grid for holes if available
            if let feltManager = starfieldScene?.feltManager {
                if feltManager.isHole(at: p) {
                    return false  // Can't spawn in hole
                }
                if !feltManager.isFelt(at: p) {
                    return false  // Can't spawn on non-felt
                }
            }
            
            // Check distance from existing balls
            if let starScene = starfieldScene {
                let existingBalls = starScene.children.compactMap { $0 as? BlockBall }
                for existingBall in existingBalls {
                    let distance = hypot(p.x - existingBall.position.x, p.y - existingBall.position.y)
                    if distance < 30 {  // Minimum clearance
                        return false
                    }
                }
            }
            
            return true
        }
        
        // Try to find valid spawn position with intelligent fallback
        var spawnPos: CGPoint?
        
        // Attempt 1: Try position to the right of spawner ball
        let offset = CGPoint(x: 40, y: 0)
        let base = ball.position
        var candidate = CGPoint(x: base.x + offset.x, y: base.y + offset.y)
        
        // Clamp to felt bounds and avoid pockets
        candidate.x = max(feltRect.minX + 16.0, min(feltRect.maxX - 16.0, candidate.x))
        candidate.y = max(feltRect.minY + 16.0, min(feltRect.maxY - 16.0, candidate.y))
        
        // Push away from pockets if too close
        for c in pocketCenters {
            if hypot(candidate.x - c.x, candidate.y - c.y) <= pocketRadius + 16.0 {
                let center = CGPoint(x: feltRect.midX, y: feltRect.midY)
                let dir = CGVector(dx: center.x - candidate.x, dy: center.y - candidate.y)
                let len = max(1.0, hypot(dir.dx, dir.dy))
                candidate.x += dir.dx / len * (pocketRadius + 16.0)
                candidate.y += dir.dy / len * (pocketRadius + 16.0)
            }
        }
        
        if isValidSpawn(candidate) {
            spawnPos = candidate
        } else {
            // Attempt 2: Try other directions around the spawner ball
            let directions: [CGPoint] = [
                CGPoint(x: -40, y: 0),   // Left
                CGPoint(x: 0, y: 40),    // Up
                CGPoint(x: 0, y: -40),   // Down
                CGPoint(x: 30, y: 30),   // Diagonal up-right
                CGPoint(x: -30, y: 30),  // Diagonal up-left
                CGPoint(x: 30, y: -30),  // Diagonal down-right
                CGPoint(x: -30, y: -30)  // Diagonal down-left
            ]
            
            for direction in directions {
                var testPos = CGPoint(x: base.x + direction.x, y: base.y + direction.y)
                testPos.x = max(feltRect.minX + 16.0, min(feltRect.maxX - 16.0, testPos.x))
                testPos.y = max(feltRect.minY + 16.0, min(feltRect.maxY - 16.0, testPos.y))
                
                if isValidSpawn(testPos) {
                    spawnPos = testPos
                    break
                }
            }
            
            // Attempt 3: Use random spawn system as last resort
            if spawnPos == nil {
                #if DEBUG
                print("⚠️ Spawner: Directional spawns failed, trying random spawn...")
                #endif
                spawnPos = starfieldScene?.randomSpawnPoint(minClearance: 20)
            }
            
            // Attempt 4: Absolute last resort - spawn at original candidate even if not ideal
            if spawnPos == nil {
                #if DEBUG
                print("⚠️ Spawner: All spawn attempts failed, using original position!")
                #endif
                spawnPos = candidate
            }
        }
        
        guard let finalSpawnPos = spawnPos else {
            #if DEBUG
            print("❌ Spawner: Failed to find ANY spawn position!")
            #endif
            return
        }
        
        // Create new cue ball at the spawn position
        let newCue = BlockBall(
            kind: .cue,
            shape: .circle,
            position: finalSpawnPos,
            in: scene,
            feltRect: feltRect,
            pocketCenters: pocketCenters,
            pocketRadius: pocketRadius
        )
        damageSystem?.registerBall(newCue)
        
        // Ensure global aiming includes this new cue ball
        if let starScene = starfieldScene {
            starScene.addCueBall(newCue)
        }
        newCue.canShoot = true
        
        // Set collision immunity between the new cue and the spawner ball temporarily
        if let damageSystem = damageSystem {
            damageSystem.setTemporaryImmunity(between: newCue, and: ball, duration: 0.3)
        }
        
        // Push the source cue ball away from the spawner to prevent immediate re-collision
        if let sourceBody = source.physicsBody {
            let sourceDir = CGVector(dx: source.position.x - base.x, dy: source.position.y - base.y)
            let sourceLen = max(1.0, hypot(sourceDir.dx, sourceDir.dy))
            sourceBody.applyImpulse(CGVector(dx: sourceDir.dx / sourceLen * 25, dy: sourceDir.dy / sourceLen * 25))
        }
        
        // Apply impulse away from spawner to the new cue
        if let body = newCue.physicsBody {
            let dir = CGVector(dx: finalSpawnPos.x - base.x, dy: finalSpawnPos.y - base.y)
            let len = max(1.0, hypot(dir.dx, dir.dy))
            body.applyImpulse(CGVector(dx: dir.dx / len * 25, dy: dir.dy / len * 25))
        }
        
        #if DEBUG
        print("🟦 Spawner created duplicate cue ball at \(finalSpawnPos)")
        #endif
    }
}

/// Heavy accessory - increases ball mass by a configurable multiplier, making it much harder to move
/// Used by 3-balls to create a heavyweight ball that resists movement
final class HeavyAccessory: BallAccessoryProtocol {
    let id = "heavy"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private var massMultiplier: CGFloat  // Configurable mass multiplier
    private var originalMass: CGFloat = 0.17  // Default normal mass
    
    /// Initialize with a specific mass multiplier (default 10x)
    init(massMultiplier: CGFloat = 10.0) {
        self.massMultiplier = massMultiplier
    }
    
    /// Update the mass multiplier and reapply to the ball
    func updateMassMultiplier(_ newMultiplier: CGFloat) {
        self.massMultiplier = newMultiplier
        
        // Reapply the new mass if attached to a ball
        if let body = ball?.physicsBody {
            body.mass = originalMass * massMultiplier
            
            #if DEBUG
            print("💪 Heavy accessory mass multiplier updated to \(String(format: "%.1f", massMultiplier))×")
            print("   New mass: \(String(format: "%.2f", body.mass))")
            #endif
        }
    }
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Store original mass and apply heavy multiplier
        if let body = ball.physicsBody {
            originalMass = body.mass
            body.mass = originalMass * massMultiplier
            
            #if DEBUG
            print("💪 Heavy accessory attached to \(ball.ballKind) ball")
            print("   Mass changed: \(String(format: "%.2f", originalMass)) -> \(String(format: "%.2f", body.mass))")
            print("   Multiplier: \(String(format: "%.1f", massMultiplier))×")
            #endif
        }
    }
    
    func onDetach(from ball: BlockBall) {
        // Restore original mass
        if let body = ball.physicsBody {
            body.mass = originalMass
            
            #if DEBUG
            print("💪 Heavy accessory detached - mass restored to \(String(format: "%.2f", originalMass))")
            #endif
        }
        
        self.ball = nil
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // Heavy accessory is passive - no update needed
    }
}

/// Gravity accessory - attracts nearby balls when the ball is at rest
/// Used by 1-balls to create a gravitational pull field
final class GravityAccessory: BallAccessoryProtocol {
    let id = "gravity"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    
    // Gravity state
    private var hasMovedOnce = false  // Track if ball has moved yet
    private var isGravityActive = false  // Track if gravity is currently active
    static var gravityRadius: CGFloat = 150.0  // Configurable via settings
    private let gravityStrength: CGFloat = 0.15  // Force applied per frame (very weak for slow attraction)
    private let gravityRestThreshold: CGFloat = 3.0  // Speed threshold to consider ball at rest
    private let restAngularSpeedThreshold: CGFloat = 0.5  // Angular speed threshold for rest
    private var gravityFieldNode: SKShapeNode?  // Visual indicator of gravity field
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        #if DEBUG
        print("🌍 Gravity accessory attached to \(ball.ballKind) ball")
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        hideGravityField()
        self.ball = nil
        
        #if DEBUG
        print("🌍 Gravity accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        guard let body = ball.physicsBody else { return }
        
        let ls = hypot(body.velocity.dx, body.velocity.dy)
        let angSpeed = abs(body.angularVelocity)
        
        // Track if ball has moved for the first time
        if !hasMovedOnce && ls > 1.0 {
            hasMovedOnce = true
            #if DEBUG
            print("🌍 Gravity ball has moved for the first time - gravity will activate when it comes to rest")
            #endif
        }
        
        // Update gravity state if ball has moved at least once
        if hasMovedOnce {
            // Check if ball is at rest
            if ls < self.gravityRestThreshold && angSpeed < self.restAngularSpeedThreshold {
                if !isGravityActive {
                    isGravityActive = true
                    showGravityField(for: ball)
                    #if DEBUG
                    print("🌍 Gravity ACTIVATED (ball at rest)")
                    #endif
                }
            } else {
                if isGravityActive {
                    isGravityActive = false
                    hideGravityField()
                    #if DEBUG
                    print("🌍 Gravity DEACTIVATED (ball moving)")
                    #endif
                }
            }
        }
        
        // Apply gravity effect if active
        if isGravityActive {
            applyGravityEffect(from: ball)
        }
    }
    
    /// Show the gravity field visual indicator
    private func showGravityField(for ball: BlockBall) {
        // Remove existing field if any
        gravityFieldNode?.removeFromParent()
        
        // Create a pulsing circle to indicate gravity field
        let field = SKShapeNode(circleOfRadius: GravityAccessory.gravityRadius)
        field.strokeColor = SKColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 0.3)
        field.lineWidth = 2.0
        field.fillColor = SKColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 0.05)
        field.zPosition = -1  // Behind the ball
        field.name = "gravityField"
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 1.5)
        let scaleDown = SKAction.scale(to: 0.9, duration: 1.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SKAction.repeatForever(pulse)
        field.run(repeatPulse)
        
        // Fade in
        field.alpha = 0
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        field.run(fadeIn)
        
        ball.addChild(field)
        gravityFieldNode = field
    }
    
    /// Hide the gravity field visual indicator
    private func hideGravityField() {
        guard let field = gravityFieldNode else { return }
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        field.run(SKAction.sequence([fadeOut, remove]))
        gravityFieldNode = nil
    }
    
    /// Apply gravitational pull to nearby balls
    private func applyGravityEffect(from ball: BlockBall) {
        guard let scene = ball.scene else { return }
        
        // Find all other balls in the scene
        for case let targetBall as BlockBall in scene.children {
            // Don't attract ourselves
            if targetBall === ball {
                continue
            }
            
            // Calculate distance to this ball
            let dx = ball.position.x - targetBall.position.x
            let dy = ball.position.y - targetBall.position.y
            let distance = hypot(dx, dy)
            
            // Check if within gravity radius
            if distance > 0 && distance < GravityAccessory.gravityRadius {
                // Calculate force direction (normalized)
                let forceX = dx / distance
                let forceY = dy / distance
                
                // Apply force that falls off with distance (inverse square law feels too strong, use linear)
                let distanceRatio = 1.0 - (distance / GravityAccessory.gravityRadius)  // 1.0 at center, 0.0 at edge
                let force = gravityStrength * distanceRatio
                
                // Apply impulse to the target ball
                if let targetBody = targetBall.physicsBody {
                    targetBody.applyImpulse(CGVector(dx: forceX * force, dy: forceY * force))
                }
            }
        }
    }
}

/// Temporary Burning accessory - spreads on contact and disappears after dealing 20 damage
/// Created when a ball with burning touches another ball
final class TempBurningAccessory: BallAccessoryProtocol {
    let id = "tempBurning"
    let visualNode = SKNode()
    var preventsSinking: Bool { return false }
    
    private weak var ball: BlockBall?
    private var damageTimer: TimeInterval = 0
    private let damageInterval: TimeInterval = 0.5  // Deal damage every 0.5 seconds
    private let damageAmount: CGFloat = 1.0  // 1 HP per tick
    private var totalDamageDealt: CGFloat = 0.0  // Track total damage
    private let maxTotalDamage: CGFloat = 20.0  // Burn wears off after 20 damage
    
    // Flame animation properties (same as regular burning)
    private var flames: [SKSpriteNode] = []
    private let blockSize: CGFloat = 5.0
    private var animationTime: TimeInterval = 0
    
    func onAttach(to ball: BlockBall) {
        self.ball = ball
        
        // Check if this is an 11-ball - if so, explode immediately!
        if ball.ballKind == .eleven {
            #if DEBUG
            print("💥 11-ball got temp burning - EXPLODING IMMEDIATELY!")
            #endif
            
            // Explode the ball through the damage system (instant death)
            if let scene = ball.scene as? StarfieldScene,
               let damageSystem = scene.damageSystem {
                damageSystem.applyDirectDamage(to: ball, amount: 9999)
            }
            
            return  // Don't bother creating flames, ball is exploding
        }
        
        // Create flame animation
        createFlameAnimation()
        
        // Add visual node to ball's visual container (no physics!)
        ball.visualContainer.addChild(visualNode)
        
        #if DEBUG
        print("🔥 Temp Burning accessory attached to \(ball.ballKind) ball (will wear off after 20 damage)")
        if ball.ballKind == .seven {
            print("   (7-ball is immune to burning damage but can still spread it)")
        }
        #endif
    }
    
    func onDetach(from ball: BlockBall) {
        visualNode.removeFromParent()
        flames.removeAll()
        self.ball = nil
        
        #if DEBUG
        print("🔥 Temp Burning accessory detached")
        #endif
    }
    
    func update(ball: BlockBall, deltaTime: TimeInterval) {
        // Animate the flames
        animationTime += deltaTime
        animateFlames(deltaTime: deltaTime)
        
        // Apply damage over time (except to 7-ball which is immune)
        if ball.ballKind != .seven {
            damageTimer += deltaTime
            
            if damageTimer >= damageInterval {
                damageTimer = 0
                
                // Apply damage through the damage system
                if let scene = ball.scene as? StarfieldScene,
                   let damageSystem = scene.damageSystem {
                    damageSystem.applyDirectDamage(to: ball, amount: damageAmount)
                    
                    // Track total damage dealt
                    totalDamageDealt += damageAmount
                    
                    #if DEBUG
                    print("🔥 Temp Burning damage: \(damageAmount) HP to \(ball.ballKind) ball (total: \(Int(totalDamageDealt))/20)")
                    #endif
                    
                    // Check if burn should wear off
                    if totalDamageDealt >= maxTotalDamage {
                        #if DEBUG
                        print("🔥 Temp Burning wore off after dealing 20 damage!")
                        #endif
                        
                        // Remove this accessory
                        BallAccessoryManager.shared.removeAccessory(id: "tempBurning", from: ball)
                    }
                }
            }
        }
    }
    
    private func createFlameAnimation() {
        // Create multiple flame sprites at different positions
        // Flames completely engulf the ball in all directions
        
        let flamePositions: [CGPoint] = [
            // Top flames (tallest)
            CGPoint(x: -7, y: 10),   // Top-left
            CGPoint(x: 0, y: 12),    // Top-center (tallest)
            CGPoint(x: 7, y: 10),    // Top-right
            
            // Upper-middle flames
            CGPoint(x: -10, y: 7),   // Upper-left
            CGPoint(x: -4, y: 8),    // Upper-mid-left
            CGPoint(x: 4, y: 8),     // Upper-mid-right
            CGPoint(x: 10, y: 7),    // Upper-right
            
            // Middle flames (around the equator)
            CGPoint(x: -12, y: 0),   // Middle-left
            CGPoint(x: -8, y: 2),    // Mid-left-high
            CGPoint(x: -8, y: -2),   // Mid-left-low
            CGPoint(x: 8, y: 2),     // Mid-right-high
            CGPoint(x: 8, y: -2),    // Mid-right-low
            CGPoint(x: 12, y: 0),    // Middle-right
            
            // Lower flames
            CGPoint(x: -10, y: -7),  // Lower-left
            CGPoint(x: -4, y: -6),   // Lower-mid-left
            CGPoint(x: 0, y: -8),    // Bottom-center
            CGPoint(x: 4, y: -6),    // Lower-mid-right
            CGPoint(x: 10, y: -7),   // Lower-right
            
            // Additional back flames (smaller, dimmer)
            CGPoint(x: -6, y: 4),    // Fill-left
            CGPoint(x: 6, y: 4),     // Fill-right
            CGPoint(x: -6, y: -4),   // Fill-left-low
            CGPoint(x: 6, y: -4),    // Fill-right-low
        ]
        
        for (index, position) in flamePositions.enumerated() {
            // Center top flame (index 1) is tallest, others vary
            let isTall = index == 1
            let flame = createFlameSprite(tall: isTall)
            flame.position = position
            flame.zPosition = 5 // Above ball but below UI
            
            // Vary initial alpha for depth effect (flames further from camera are dimmer)
            if index >= 19 { // Back fill flames
                flame.alpha = 0.6
            }
            
            flames.append(flame)
            visualNode.addChild(flame)
        }
    }
    
    private func createFlameSprite(tall: Bool) -> SKSpriteNode {
        // Create a flame texture using blocks
        let flameWidth = 2
        let flameHeight = tall ? 4 : 3
        let size = CGSize(width: CGFloat(flameWidth) * blockSize, 
                         height: CGFloat(flameHeight) * blockSize)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Flame gradient: yellow at bottom, orange in middle, red at top
            let colors: [UIColor] = [
                UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.9),  // Yellow
                UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.85), // Orange
                UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.8),  // Red-orange
                UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.7)   // Dark red
            ]
            
            // Draw flame blocks from bottom to top
            for row in 0..<flameHeight {
                for col in 0..<flameWidth {
                    // Taper at the top (skip some blocks)
                    if row == flameHeight - 1 && col == 1 && !tall {
                        continue // Skip top-right for shorter flames
                    }
                    
                    let colorIndex = min(row, colors.count - 1)
                    let color = colors[colorIndex]
                    
                    let x = CGFloat(col) * blockSize
                    let y = CGFloat(row) * blockSize
                    let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                    
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                }
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture)
        sprite.alpha = 0.9
        
        return sprite
    }
    
    private func animateFlames(deltaTime: TimeInterval) {
        // Flickering animation: vary alpha and slight vertical movement
        let basePositions: [CGPoint] = [
            // Top flames (tallest)
            CGPoint(x: -7, y: 10),   // Top-left
            CGPoint(x: 0, y: 12),    // Top-center (tallest)
            CGPoint(x: 7, y: 10),    // Top-right
            
            // Upper-middle flames
            CGPoint(x: -10, y: 7),   // Upper-left
            CGPoint(x: -4, y: 8),    // Upper-mid-left
            CGPoint(x: 4, y: 8),     // Upper-mid-right
            CGPoint(x: 10, y: 7),    // Upper-right
            
            // Middle flames (around the equator)
            CGPoint(x: -12, y: 0),   // Middle-left
            CGPoint(x: -8, y: 2),    // Mid-left-high
            CGPoint(x: -8, y: -2),   // Mid-left-low
            CGPoint(x: 8, y: 2),     // Mid-right-high
            CGPoint(x: 8, y: -2),    // Mid-right-low
            CGPoint(x: 12, y: 0),    // Middle-right
            
            // Lower flames
            CGPoint(x: -10, y: -7),  // Lower-left
            CGPoint(x: -4, y: -6),   // Lower-mid-left
            CGPoint(x: 0, y: -8),    // Bottom-center
            CGPoint(x: 4, y: -6),    // Lower-mid-right
            CGPoint(x: 10, y: -7),   // Lower-right
            
            // Additional back flames (smaller, dimmer)
            CGPoint(x: -6, y: 4),    // Fill-left
            CGPoint(x: 6, y: 4),     // Fill-right
            CGPoint(x: -6, y: -4),   // Fill-left-low
            CGPoint(x: 6, y: -4),    // Fill-right-low
        ]
        
        for (index, flame) in flames.enumerated() {
            guard index < basePositions.count else { continue }
            
            // Each flame flickers at slightly different rates
            let phaseOffset = CGFloat(index) * 0.3
            let flickerSpeed: CGFloat = 8.0 + CGFloat(index % 5) * 0.5
            
            // Alpha flickering - back flames stay dimmer
            let baseAlpha: CGFloat = index >= 19 ? 0.6 : 0.85
            let alpha = baseAlpha + sin(CGFloat(animationTime) * flickerSpeed + phaseOffset) * 0.15
            flame.alpha = alpha
            
            // Vertical bobbing (small movement) - varies by position
            let bobAmount: CGFloat = index < 7 ? 2.0 : 1.5  // Top flames bob more
            let bobSpeed: CGFloat = 10.0 + CGFloat(index % 7)
            let yOffset = sin(CGFloat(animationTime) * bobSpeed + phaseOffset) * bobAmount
            
            // Horizontal sway for side flames
            let swayAmount: CGFloat = 0.5
            let swaySpeed: CGFloat = 6.0 + CGFloat(index % 4)
            let xOffset = cos(CGFloat(animationTime) * swaySpeed + phaseOffset) * swayAmount
            
            // Apply to position (using base position + offsets)
            let basePosition = basePositions[index]
            flame.position = CGPoint(x: basePosition.x + xOffset, y: basePosition.y + yOffset)
        }
    }
}

/// Manager for ball accessories
final class BallAccessoryManager {
    static let shared = BallAccessoryManager()
    
    private var accessories: [String: BallAccessoryProtocol] = [:]
    private var ballAccessories: [ObjectIdentifier: [BallAccessoryProtocol]] = [:]
    
    // Global heavy accessory mass multiplier (configurable via settings)
    private(set) var heavyMassMultiplier: CGFloat = 10.0
    
    private init() {
        registerDefaultAccessories()
    }
    
    private func registerDefaultAccessories() {
        // Register built-in accessories
        registerAccessory(FlyingAccessory())
        registerAccessory(HeavyAccessory())  // NEW: Heavy mass
        registerAccessory(GravityAccessory())  // NEW: Gravity attraction
        registerAccessory(BurningAccessory())
        registerAccessory(TempBurningAccessory())
        registerAccessory(ExplodeOnContactAccessory())
        registerAccessory(ExplodeOnDestroyAccessory())  // NEW: Explode when destroyed
        registerAccessory(ZapperAccessory())  // NEW: Lightning zapper
        registerAccessory(SpawnerAccessory())  // NEW: Spawns cue balls
        registerAccessory(PulseAccessory())  // NEW: Damaging pulse
        registerAccessory(HealingAccessory())  // NEW: Heals nearby cue balls
        registerAccessory(SpeedyAccessory())  // NEW: 2x speed and power
        
        // Register all hat styles
        registerAccessory(HatAccessory(style: .topHat))
        registerAccessory(HatAccessory(style: .bowler))
        registerAccessory(HatAccessory(style: .baseball))
        registerAccessory(HatAccessory(style: .wizard))
        registerAccessory(HatAccessory(style: .cowboy))
    }
    
    func registerAccessory(_ accessory: BallAccessoryProtocol) {
        accessories[accessory.id] = accessory
    }
    
    /// Attach an accessory to a ball
    func attachAccessory(id: String, to ball: BlockBall) -> Bool {
        // Check if accessory type exists
        guard let accessoryType = accessories[id] else {
            print("⚠️ Accessory type '\(id)' not found")
            return false
        }
        
        // CRITICAL: Store the ball's physics state BEFORE attaching accessory
        // We will verify it hasn't changed after attachment
        #if DEBUG
        let physicsBodyBefore = ball.physicsBody
        let isDynamicBefore = ball.physicsBody?.isDynamic
        let collisionBitMaskBefore = ball.physicsBody?.collisionBitMask
        #endif
        
        // Create a new instance for this ball
        let accessory: BallAccessoryProtocol
        switch id {
        case "flying":
            accessory = FlyingAccessory()
        case "heavy":
            accessory = HeavyAccessory(massMultiplier: heavyMassMultiplier)
        case "gravity":
            accessory = GravityAccessory()
        case "burning":
            accessory = BurningAccessory()
        case "tempBurning":
            accessory = TempBurningAccessory()
        case "explodeOnContact":
            accessory = ExplodeOnContactAccessory()
        case "explodeOnDestroy":
            accessory = ExplodeOnDestroyAccessory()
        case "zapper":
            accessory = ZapperAccessory()
        case "spawner":
            accessory = SpawnerAccessory()
        case "pulse":
            accessory = PulseAccessory()
        case "healing":
            accessory = HealingAccessory()
        case "speedy":
            accessory = SpeedyAccessory()
        case "hat_topHat":
            accessory = HatAccessory(style: .topHat)
        case "hat_bowler":
            accessory = HatAccessory(style: .bowler)
        case "hat_baseball":
            accessory = HatAccessory(style: .baseball)
        case "hat_wizard":
            accessory = HatAccessory(style: .wizard)
        case "hat_cowboy":
            accessory = HatAccessory(style: .cowboy)
        default:
            print("⚠️ Cannot instantiate accessory '\(id)'")
            return false
        }
        
        // Check if already attached
        let ballID = ObjectIdentifier(ball)
        if let existing = ballAccessories[ballID]?.first(where: { $0.id == id }) {
            print("⚠️ Accessory '\(id)' already attached to ball")
            return false
        }
        
        // Attach accessory - wings are now independent scene nodes
        // The accessory handles adding its own nodes to the scene in onAttach
        accessory.onAttach(to: ball)
        
        // CRITICAL VERIFICATION: Ensure ball's physics was not modified
        #if DEBUG
        if ball.physicsBody !== physicsBodyBefore {
            print("❌ CRITICAL ERROR: Ball's physics body was replaced during accessory attachment!")
        }
        if ball.physicsBody?.isDynamic != isDynamicBefore {
            print("❌ CRITICAL ERROR: Ball's isDynamic was modified during accessory attachment!")
            print("   Before: \(isDynamicBefore ?? false), After: \(ball.physicsBody?.isDynamic ?? false)")
        }
        if ball.physicsBody?.collisionBitMask != collisionBitMaskBefore {
            print("❌ CRITICAL ERROR: Ball's collisionBitMask was modified during accessory attachment!")
            print("   Before: \(collisionBitMaskBefore ?? 0), After: \(ball.physicsBody?.collisionBitMask ?? 0)")
        }
        
        print("✅ Accessory attached - ball physics unchanged")
        #endif
        
        // Track accessory
        if ballAccessories[ballID] == nil {
            ballAccessories[ballID] = []
        }
        ballAccessories[ballID]?.append(accessory)
        
        return true
    }
    
    /// Remove an accessory from a ball
    func removeAccessory(id: String, from ball: BlockBall) -> Bool {
        let ballID = ObjectIdentifier(ball)
        guard let accessories = ballAccessories[ballID],
              let index = accessories.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        let accessory = accessories[index]
        accessory.visualNode.removeFromParent()
        accessory.onDetach(from: ball)
        
        ballAccessories[ballID]?.remove(at: index)
        if ballAccessories[ballID]?.isEmpty == true {
            ballAccessories[ballID] = nil
        }
        
        return true
    }
    
    /// Update all accessories for a ball
    func updateAccessories(for ball: BlockBall, deltaTime: TimeInterval) {
        let ballID = ObjectIdentifier(ball)
        guard let accessories = ballAccessories[ballID] else { return }
        
        for accessory in accessories {
            accessory.update(ball: ball, deltaTime: deltaTime)
        }
    }
    
    /// Check if a ball has an accessory that prevents sinking
    func preventsSinking(ball: BlockBall) -> Bool {
        let ballID = ObjectIdentifier(ball)
        guard let accessories = ballAccessories[ballID] else { return false }
        
        return accessories.contains(where: { $0.preventsSinking })
    }
    
    /// Get all accessories attached to a ball
    func getAccessories(for ball: BlockBall) -> [BallAccessoryProtocol] {
        let ballID = ObjectIdentifier(ball)
        return ballAccessories[ballID] ?? []
    }
    
    /// Check if a ball has a specific accessory
    func hasAccessory(ball: BlockBall, id: String) -> Bool {
        let ballID = ObjectIdentifier(ball)
        return ballAccessories[ballID]?.contains(where: { $0.id == id }) ?? false
    }
    
    /// Clean up accessories for a removed ball
    func cleanupAccessories(for ball: BlockBall) {
        let ballID = ObjectIdentifier(ball)
        if let accessories = ballAccessories[ballID] {
            for accessory in accessories {
                accessory.visualNode.removeFromParent()
                accessory.onDetach(from: ball)
            }
        }
        ballAccessories[ballID] = nil
    }
    
    /// Attach a random hat accessory to a ball
    /// - Parameter ball: The ball to attach a hat to
    /// - Returns: True if a hat was successfully attached
    func attachRandomHat(to ball: BlockBall) -> Bool {
        let hatStyles = ["hat_topHat", "hat_bowler", "hat_baseball", "hat_wizard", "hat_cowboy"]
        guard let randomHat = hatStyles.randomElement() else { return false }
        
        #if DEBUG
        print("🎩 Attaching random hat '\(randomHat)' to \(ball.ballKind) ball")
        #endif
        
        return attachAccessory(id: randomHat, to: ball)
    }
    
    // MARK: - Global Hat Settings
    
    private var hatsEnabled: Bool = true
    
    /// Set whether hats are enabled globally
    func setHatsEnabled(_ enabled: Bool) {
        hatsEnabled = enabled
        
        #if DEBUG
        print("🎩 Hats globally \(enabled ? "enabled" : "disabled")")
        #endif
    }
    
    /// Check if hats are currently enabled
    func areHatsEnabled() -> Bool {
        return hatsEnabled
    }
    
    /// Remove all hat accessories from a ball
    func removeAllHats(from ball: BlockBall) {
        let hatIDs = ["hat_topHat", "hat_bowler", "hat_baseball", "hat_wizard", "hat_cowboy"]
        for hatID in hatIDs {
            _ = removeAccessory(id: hatID, from: ball)
        }
    }
    
    /// Check if a ball has any hat accessory
    func hasAnyHat(ball: BlockBall) -> Bool {
        let hatIDs = ["hat_topHat", "hat_bowler", "hat_baseball", "hat_wizard", "hat_cowboy"]
        return hatIDs.contains { hasAccessory(ball: ball, id: $0) }
    }
    
    /// Check if a ball has any kind of burning (regular or temp)
    func hasBurning(ball: BlockBall) -> Bool {
        return hasAccessory(ball: ball, id: "burning") || hasAccessory(ball: ball, id: "tempBurning")
    }
    
    /// Check if a ball has the explode on contact ability
    func hasExplodeOnContact(ball: BlockBall) -> Bool {
        return hasAccessory(ball: ball, id: "explodeOnContact")
    }
    
    /// Check if a ball has the spawner ability
    func hasSpawner(ball: BlockBall) -> Bool {
        return hasAccessory(ball: ball, id: "spawner")
    }
    
    /// Get the spawner accessory instance for a ball (if it has one)
    func getSpawnerAccessory(for ball: BlockBall) -> SpawnerAccessory? {
        let ballID = ObjectIdentifier(ball)
        return ballAccessories[ballID]?.first(where: { $0.id == "spawner" }) as? SpawnerAccessory
    }
    
    /// Check if a ball has the heavy accessory (10x mass)
    func hasHeavy(ball: BlockBall) -> Bool {
        return hasAccessory(ball: ball, id: "heavy")
    }
    
    /// Update the heavy accessory mass multiplier globally
    /// This updates all existing heavy accessories and sets the default for new ones
    func setHeavyMassMultiplier(_ multiplier: CGFloat) {
        self.heavyMassMultiplier = multiplier
        
        #if DEBUG
        print("💪 Heavy mass multiplier set to \(String(format: "%.1f", multiplier))×")
        #endif
        
        // Update all existing heavy accessories
        for (ballID, accessories) in ballAccessories {
            for accessory in accessories {
                if let heavyAccessory = accessory as? HeavyAccessory {
                    heavyAccessory.updateMassMultiplier(multiplier)
                }
            }
        }
    }
    
    /// Get the current heavy mass multiplier
    func getHeavyMassMultiplier() -> CGFloat {
        return heavyMassMultiplier
    }
    
    /// Get the pulse accessory instance for a ball (if it has one)
    func getPulseAccessory(for ball: BlockBall) -> PulseAccessory? {
        let ballID = ObjectIdentifier(ball)
        return ballAccessories[ballID]?.first(where: { $0.id == "pulse" }) as? PulseAccessory
    }
}
