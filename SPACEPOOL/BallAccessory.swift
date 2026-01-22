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
    
    private init() {
        registerDefaultAccessories()
    }
    
    private func registerDefaultAccessories() {
        // Register built-in accessories
        registerAccessory(FlyingAccessory())
        registerAccessory(BurningAccessory())
        registerAccessory(TempBurningAccessory())
        registerAccessory(ExplodeOnContactAccessory())
        registerAccessory(ExplodeOnDestroyAccessory())  // NEW: Explode when destroyed
        
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
        case "burning":
            accessory = BurningAccessory()
        case "tempBurning":
            accessory = TempBurningAccessory()
        case "explodeOnContact":
            accessory = ExplodeOnContactAccessory()
        case "explodeOnDestroy":
            accessory = ExplodeOnDestroyAccessory()
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
}
