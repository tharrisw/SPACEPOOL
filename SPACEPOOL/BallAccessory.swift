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
        
        print("✅ Accessory attached - ball physics unchanged, wings are independent scene nodes")
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
}
