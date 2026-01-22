//
//  BallDamageSystem.swift
//  SpacePool
//
//  Damage system for BlockBall gameplay
//

import Foundation
import SpriteKit
import CoreGraphics

/// Delegate to notify when balls are destroyed or level objectives are met
protocol BallDamageSystemDelegate: AnyObject {
    /// Called when a ball is destroyed (after HP reaches 0)
    func ballDamageSystem(_ system: BallDamageSystem, didDestroyBall ball: BlockBall)
    
    /// Called when all non-cue balls have been destroyed
    func ballDamageSystemDidClearAllTargets(_ system: BallDamageSystem)
    
    /// Called when a cue ball is destroyed and needs to be respawned
    func ballDamageSystemShouldRespawnCueBall(_ system: BallDamageSystem)
    
    /// Called when a 2-ball takes damage from a cue ball collision (optional)
    /// - Parameters:
    ///   - system: The damage system
    ///   - twoBall: The 2-ball that took damage
    ///   - cueBall: The cue ball that hit it
    func ballDamageSystem(_ system: BallDamageSystem, twoBall: BlockBall, tookDamageFrom cueBall: BlockBall)
}

// Make the 2-ball delegate method optional with a default implementation
extension BallDamageSystemDelegate {
    func ballDamageSystem(_ system: BallDamageSystem, twoBall: BlockBall, tookDamageFrom cueBall: BlockBall) {
        // Default: do nothing (optional implementation)
    }
}

/// Manages health and damage for balls in the pool game
final class BallDamageSystem {
    
    // MARK: - Configuration
    struct DamageConfig {
        enum DestructionEffect {
            case explode  // Fast explosive burst
            case crumble  // Slow separation and fall
        }
        
        /// Starting HP for all balls
        var startingHP: CGFloat = 100
        
        /// Damage dealt when cue ball hits non-cue ball
        var cueBallCollisionDamage: CGFloat = 80
        
        /// Damage dealt when same-type balls collide
        /// Note: For cue-cue, this is 4 base damage, which becomes 1 after 75% armor (100 hits to destroy)
        /// For 8-8, this is 1 damage with no armor (100 hits to destroy)
        var sameTypeDamage: CGFloat = 4
        
        /// Armor percentage for cue balls (0.0 - 1.0)
        var cueBallArmor: CGFloat = 0.75
        
        /// Minimum collision impulse to trigger damage
        var minDamageImpulse: CGFloat = 50
        
        /// Show visual HP indicators
        var showHealthBars: Bool = true
        
        /// Show damage numbers when balls take damage
        var showDamageNumbers: Bool = false
        
        /// Type of destruction effect when ball HP reaches 0
        var destructionEffect: DestructionEffect = .crumble
        
        /// Global damage multiplier (1.0 = normal, 10.0 = one-hit kills)
        var damageMultiplier: CGFloat = 1.0
        
        /// Damage multiplier for eleven balls (default 1.0 = normal, 3.0 = triple damage)
        var elevenBallDamageMultiplier: CGFloat = 1.0
        
        // MARK: Accessory Settings
        // These settings control accessories that can be attached to any ball
        
        /// Damage pulse radius in blocks (default 18.0)
        /// Controls the damagePulse accessory radius
        var pulseDamageRadius: CGFloat = 18.0
        
        /// Damage pulse delay in seconds before triggering (default 1.0)
        /// Controls the damagePulse accessory charge time
        var pulseDamageDelay: TimeInterval = 1.0
        
        /// Maximum number of times damage pulse can trigger (default 2)
        /// Controls how many times the damagePulse accessory can activate before ball is destroyed
        var pulseDamageMaxTriggers: Int = 2
        
        /// Explosion radius in blocks (default 10.0)
        /// Controls the explosion radius for both explodeOnContact and explodeOnDestroy accessories
        var explosionRadius: CGFloat = 10.0
        
        /// Number of explosions before permanent destruction (default 1)
        /// Determines how many times a ball with explodeOnContact can explode before being permanently destroyed
        var explosionsBeforeDestruction: Int = 1
    }
    
    // MARK: - Ball Health State
    private class BallHealth {
        var currentHP: CGFloat
        var maxHP: CGFloat
        weak var ball: BlockBall?
        var healthBar: SKNode?
        var fourBallTriggerCount: Int = 0  // Track 4ball triggers
        var explodeOnContactCount: Int = 0  // Track explodeOnContact accessory explosions
        
        init(ball: BlockBall, maxHP: CGFloat) {
            self.ball = ball
            self.maxHP = maxHP
            self.currentHP = maxHP
        }
        
        var isAlive: Bool {
            return currentHP > 0
        }
        
        var healthPercentage: CGFloat {
            return currentHP / maxHP
        }
    }
    
    // MARK: - Properties
    var config: DamageConfig  // Made public for UI toggles
    private var ballHealthMap: [ObjectIdentifier: BallHealth] = [:]
    private weak var scene: SKScene?
    weak var delegate: BallDamageSystemDelegate?
    
    // Track the last source ball that dealt damage in a collision for onDamage hooks
    private var lastDamageSource: BlockBall?
    
    // 🔥 NEW: FeltManager reference for dynamic felt destruction
    weak var feltManager: FeltManager?
    
    // Cooldown to prevent multiple damage events from single collision
    private var collisionCooldowns: [String: TimeInterval] = [:]
    private let cooldownDuration: TimeInterval = 0.1
    
    // Temporary immunity to prevent immediate re-collision (e.g., when 2-ball spawns new cue)
    private var immunityPairs: [String: TimeInterval] = [:]
    
    #if DEBUG
    private let debugEnabled: Bool = true
    #else
    private let debugEnabled: Bool = false
    #endif
    
    // MARK: - Initialization
    init(scene: SKScene, config: DamageConfig = DamageConfig()) {
        self.scene = scene
        self.config = config
        
        // Auto-wire delegate to the scene if it conforms so special events (like 2-ball reactions) fire
        if self.delegate == nil, let delegateScene = scene as? BallDamageSystemDelegate {
            self.delegate = delegateScene
            #if DEBUG
            if debugEnabled {
                print("🧩 BallDamageSystem delegate auto-assigned to scene")
            }
            #endif
        }
    }
    
    // MARK: - Ball Registration
    
    /// Register a ball with the damage system
    /// - Parameters:
    ///   - ball: The ball to register
    ///   - customHP: Optional custom HP value. If nil, uses config.startingHP (with special cases)
    func registerBall(_ ball: BlockBall, customHP: CGFloat? = nil) {
        let id = ObjectIdentifier(ball)
        
        // Determine max HP
        let maxHP: CGFloat
        if let custom = customHP {
            maxHP = custom
        } else {
            // Special HP values for specific ball types
            switch ball.ballKind {
            case .nine:
                maxHP = 50  // 9-balls have 50 HP (zapper balls are more fragile)
            default:
                maxHP = config.startingHP  // Default 100 HP
            }
        }
        
        let health = BallHealth(ball: ball, maxHP: maxHP)
        ballHealthMap[id] = health
        
        #if DEBUG
        if debugEnabled {
            print("❤️ Registering \(ball.ballKind) ball (ID: \(id)) with \(maxHP) HP")
            print("   Total registered balls: \(ballHealthMap.count)")
        }
        #endif
        
        if config.showHealthBars {
            createHealthBar(for: ball, health: health)
            #if DEBUG
            if debugEnabled {
                print("   ✅ Health bar created at z: 2000")
            }
            #endif
        }
    }
    
    /// Unregister a ball (e.g., when it sinks)
    func unregisterBall(_ ball: BlockBall) {
        let id = ObjectIdentifier(ball)
        if let health = ballHealthMap[id] {
            // Immediately remove and cleanup health bar
            health.healthBar?.removeAllActions()
            health.healthBar?.removeFromParent()
            health.healthBar = nil
            
            // Remove from tracking
            ballHealthMap.removeValue(forKey: id)
            
            #if DEBUG
            if debugEnabled {
                print("💔 Unregistered \(ball.ballKind) ball and removed health bar")
            }
            #endif
        } else {
            #if DEBUG
            if debugEnabled {
                print("⚠️ Attempted to unregister ball that wasn't registered")
            }
            #endif
        }
    }
    
    // MARK: - Collision Handling
    
    /// Process a collision between two balls
    func handleCollision(between ball1: BlockBall, and ball2: BlockBall, impulse: CGFloat) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        #if DEBUG
        if debugEnabled {
            print("💥 handleCollision called - Impulse: \(String(format: "%.1f", impulse)), Threshold: \(config.minDamageImpulse)")
            print("   ⏱️ Collision start time: \(startTime)")
        }
        #endif
        
        // Check temporary immunity first (e.g., newly spawned ball from 2-ball)
        let collisionKey = makeCooldownKey(ball1, ball2)
        if hasImmunity(collisionKey) {
            #if DEBUG
            if debugEnabled {
                print("   🛡 Balls have temporary immunity, skipping damage")
            }
            #endif
            return
        }
        
        // Check cooldown to avoid double-processing
        if isOnCooldown(collisionKey) {
            #if DEBUG
            if debugEnabled {
                print("   ⏰ Collision on cooldown, skipping")
            }
            #endif
            return
        }
        
        let afterCooldownCheck = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        if debugEnabled {
            print("   ⏱️ After cooldown check: +\(String(format: "%.4f", (afterCooldownCheck - startTime) * 1000))ms")
        }
        #endif
        
        setCooldown(collisionKey)
        
        // Check if either ball has explodeOnContact accessory - they should explode on ANY touch
        let ball1HasExplodeOnContact = BallAccessoryManager.shared.hasAccessory(ball: ball1, id: "explodeOnContact")
        let ball2HasExplodeOnContact = BallAccessoryManager.shared.hasAccessory(ball: ball2, id: "explodeOnContact")
        let hasExplodeOnContact = ball1HasExplodeOnContact || ball2HasExplodeOnContact
        
        let afterAccessoryCheck = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        if debugEnabled {
            print("   ⏱️ After accessory check: +\(String(format: "%.4f", (afterAccessoryCheck - startTime) * 1000))ms")
            print("   💣 Has explodeOnContact: \(hasExplodeOnContact) (ball1: \(ball1HasExplodeOnContact), ball2: \(ball2HasExplodeOnContact))")
        }
        #endif
        
        // Only check impulse threshold if neither ball has explodeOnContact
        if !hasExplodeOnContact {
            guard impulse >= config.minDamageImpulse else {
                #if DEBUG
                if debugEnabled {
                    print("   ⚠️ Impulse too weak (\(String(format: "%.1f", impulse)) < \(config.minDamageImpulse)), no damage")
                }
                #endif
                return
            }
        } else {
            #if DEBUG
            if debugEnabled {
                print("   💣 Ball has explodeOnContact - bypassing impulse check (impulse: \(String(format: "%.1f", impulse)))")
            }
            #endif
        }
        
        let kind1 = ball1.ballKind
        let kind2 = ball2.ballKind
        
        var damage1: CGFloat = 0
        var damage2: CGFloat = 0
        
        // Determine damage based on ball types
        // LOGIC:
        // - Cue → Any other: 10 damage to other, 5 damage back to cue
        // - Cue → Cue: 1 damage each
        // - Any other → Any other: 1 damage each
        let damageMultiplier: CGFloat = config.damageMultiplier  // Use config multiplier (1.0-10.0)
        
        if kind1 == .cue && kind2 == .cue {
            // Two cue balls colliding - 1 damage each
            damage1 = 1 * damageMultiplier
            damage2 = 1 * damageMultiplier
            #if DEBUG
            if debugEnabled {
                print("⚔️ Two cue balls collided for \(damage1) damage each")
            }
            #endif
        } else if kind1 == .cue && kind2 != .cue {
            // Cue ball (ball1) hitting non-cue ball (ball2)
            // - Cue deals 10 damage to the other ball
            // - Other ball deals 5 damage back to cue
            damage2 = 10 * damageMultiplier  // Damage to the non-cue ball
            damage1 = 5 * damageMultiplier   // Damage back to the cue ball
            #if DEBUG
            if debugEnabled {
                print("⚔️ Cue ball hit \(kind2) ball: \(kind2) takes \(damage2) damage, cue takes \(damage1) damage")
            }
            #endif
        } else if kind2 == .cue && kind1 != .cue {
            // Cue ball (ball2) hitting non-cue ball (ball1) - reverse of above
            damage1 = 10 * damageMultiplier  // Damage to the non-cue ball
            damage2 = 5 * damageMultiplier   // Damage back to the cue ball
            #if DEBUG
            if debugEnabled {
                print("⚔️ Cue ball hit \(kind1) ball: \(kind1) takes \(damage1) damage, cue takes \(damage2) damage")
            }
            #endif
        } else {
            // Non-cue to non-cue (8-ball, 11-ball, or any combination)
            // 1 damage each
            damage1 = 1 * damageMultiplier
            damage2 = 1 * damageMultiplier
            #if DEBUG
            if debugEnabled {
                print("⚔️ \(kind1) and \(kind2) collided for \(damage1) damage each")
            }
            #endif
        }
        
        // Apply damage with source tracking
        if damage1 > 0 {
            // ball2 is the source of damage to ball1
            lastDamageSource = ball2
            applyDamage(damage1, to: ball1, at: ball1.position)
        }
        if damage2 > 0 {
            // ball1 is the source of damage to ball2
            lastDamageSource = ball1
            applyDamage(damage2, to: ball2, at: ball2.position)
        }
        
        // Apply speedy accessory velocity boost after collision
        // Check if either ball has speedy accessory and amplify their velocities
        if BallAccessoryManager.shared.hasAccessory(ball: ball1, id: "speedy"),
           let body1 = ball1.physicsBody {
            // Double the velocity for ball1
            body1.velocity = CGVector(dx: body1.velocity.dx * 2.0, dy: body1.velocity.dy * 2.0)
            #if DEBUG
            if debugEnabled {
                print("⚡ Speedy accessory: Doubled ball1 velocity")
            }
            #endif
        }
        
        if BallAccessoryManager.shared.hasAccessory(ball: ball2, id: "speedy"),
           let body2 = ball2.physicsBody {
            // Double the velocity for ball2
            body2.velocity = CGVector(dx: body2.velocity.dx * 2.0, dy: body2.velocity.dy * 2.0)
            #if DEBUG
            if debugEnabled {
                print("⚡ Speedy accessory: Doubled ball2 velocity")
            }
            #endif
        }
    }
    
    // MARK: - Public Damage API
    
    /// Apply damage directly to a specific ball (for special mechanics like 4-ball collision)
    /// - Parameters:
    ///   - ball: The ball to damage
    ///   - damage: Amount of damage to apply
    func applyDirectDamage(to ball: BlockBall, amount damage: CGFloat) {
        applyDamage(damage, to: ball, at: ball.position)
    }
    
    // MARK: - Damage Application
    
    /// Apply damage to a ball, accounting for armor
    private func applyDamage(_ rawDamage: CGFloat, to ball: BlockBall, at position: CGPoint) {
        let id = ObjectIdentifier(ball)
        
        #if DEBUG
        if debugEnabled {
            print("🎯 Attempting to apply \(rawDamage) damage to \(ball.ballKind) ball (ID: \(id))")
            print("   Registered balls count: \(ballHealthMap.count)")
            print("   Ball is registered: \(ballHealthMap[id] != nil)")
        }
        #endif
        
        guard let health = ballHealthMap[id] else {
            #if DEBUG
            if debugEnabled {
                print("   ❌ ERROR: Ball not found in health map!")
            }
            #endif
            return
        }
        
        guard health.isAlive else {
            #if DEBUG
            if debugEnabled {
                print("   ⚰️ Ball is already dead, skipping damage")
            }
            #endif
            return
        }
        
        // Apply eleven ball damage multiplier if applicable
        var actualDamage = rawDamage
        if ball.ballKind == .eleven {
            actualDamage *= config.elevenBallDamageMultiplier
            
            #if DEBUG
            if debugEnabled {
                print("   💥 Eleven ball damage multiplier applied: \(rawDamage) -> \(actualDamage)")
            }
            #endif
        }
        
        // SPECIAL: If this ball has explodeOnContact accessory, ANY damage triggers instant explosion
        if BallAccessoryManager.shared.hasAccessory(ball: ball, id: "explodeOnContact") {
            let explosionStartTime = CFAbsoluteTimeGetCurrent()
            #if DEBUG
            if debugEnabled {
                print("   💣💣💣 EXPLODE ON CONTACT TRIGGERED!")
                print("   ⏱️ Explosion start time: \(explosionStartTime)")
            }
            #endif
            
            // Check if this ball has exploded too many times
            health.explodeOnContactCount += 1
            
            #if DEBUG
            if debugEnabled {
                print("   💣 \(ball.ballKind) ball has explodeOnContact accessory - explosion count: \(health.explodeOnContactCount)/\(config.explosionsBeforeDestruction)")
            }
            #endif
            
            // Check if we've reached the max explosion limit
            if health.explodeOnContactCount >= config.explosionsBeforeDestruction {
                #if DEBUG
                if debugEnabled {
                    print("   💀 \(ball.ballKind) ball reached max explosions (\(config.explosionsBeforeDestruction)), destroying completely!")
                }
                #endif
                
                let beforePhysicsStop = CFAbsoluteTimeGetCurrent()
                
                // INSTANT EXPLOSION - Skip all visual conversion, just explode
                ball.physicsBody?.velocity = .zero
                ball.physicsBody?.angularVelocity = 0
                ball.physicsBody?.isDynamic = false
                
                let afterPhysicsStop = CFAbsoluteTimeGetCurrent()
                #if DEBUG
                if debugEnabled {
                    print("   ⏱️ Physics stop: +\(String(format: "%.4f", (afterPhysicsStop - beforePhysicsStop) * 1000))ms")
                }
                #endif
                
                // Skip convertToBlocks() - just create explosion immediately
                createMassiveExplosion(at: ball.position, ball: ball)
                
                let afterExplosion = CFAbsoluteTimeGetCurrent()
                #if DEBUG
                if debugEnabled {
                    print("   ⏱️ After createMassiveExplosion: +\(String(format: "%.4f", (afterExplosion - afterPhysicsStop) * 1000))ms")
                    print("   ⏱️ Total explosion time: +\(String(format: "%.4f", (afterExplosion - explosionStartTime) * 1000))ms")
                }
                #endif
                
                // Mark as dead and notify delegate
                health.currentHP = 0
                delegate?.ballDamageSystem(self, didDestroyBall: ball)
                
                // Remove from scene immediately (hide it)
                ball.alpha = 0
                ball.removeFromParent()
                
                #if DEBUG
                if debugEnabled {
                    let finalTime = CFAbsoluteTimeGetCurrent()
                    print("   ⏱️ TOTAL TIME FROM EXPLOSION START: +\(String(format: "%.4f", (finalTime - explosionStartTime) * 1000))ms")
                }
                #endif
                
                return  // Skip normal damage processing
            } else {
                #if DEBUG
                if debugEnabled {
                    print("   ♻️ \(ball.ballKind) ball exploding but will regenerate (\(health.explodeOnContactCount)/\(config.explosionsBeforeDestruction))")
                }
                #endif
                
                // INSTANT EXPLOSION - Skip all visual conversion, just explode
                ball.physicsBody?.velocity = .zero
                ball.physicsBody?.angularVelocity = 0
                ball.physicsBody?.isDynamic = false
                
                // Skip convertToBlocks() - just create explosion immediately
                createMassiveExplosion(at: ball.position, ball: ball)
                
                // Remove from scene immediately (hide it)
                ball.alpha = 0
                ball.removeFromParent()
                
                return  // Skip normal damage processing
            }
        }
        
        health.currentHP = max(0, health.currentHP - actualDamage)

        // SPECIAL: 4-ball triggers pulse via accessory when it takes damage
        if ball.ballKind == .four && actualDamage > 0 {
            if let pulseAccessory = BallAccessoryManager.shared.getPulseAccessory(for: ball) {
                pulseAccessory.triggerPulse(from: ball, damageSystem: self)
            }
        }
        
        #if DEBUG
        if debugEnabled {
            print("💥 \(ball.ballKind) ball took \(actualDamage) damage. HP: \(health.currentHP)/\(health.maxHP)")
        }
        #endif
        
        // Update visual
        updateHealthBar(for: health)
        showDamageEffect(at: position, damage: actualDamage)

        // Invoke per-ball damage hook (now simplified since 2-ball uses accessory)
        ball.onDamage(amount: actualDamage, source: lastDamageSource, system: self)
        
        // Check if ball has spawner accessory and trigger it
        if let spawner = BallAccessoryManager.shared.getSpawnerAccessory(for: ball),
           let source = lastDamageSource,
           source.ballKind == .cue {
            spawner.triggerSpawn(from: ball, source: source, damageSystem: self)
        }
        
        // Clear source after use
        lastDamageSource = nil
        
        // Check if ball has zapper accessory and trigger it
        if BallAccessoryManager.shared.hasAccessory(ball: ball, id: "zapper") {
            // Get the zapper accessory and trigger it
            let accessories = BallAccessoryManager.shared.getAccessories(for: ball)
            if let zapper = accessories.first(where: { $0.id == "zapper" }) as? ZapperAccessory,
               let scene = scene {
                zapper.triggerZap(from: ball, scene: scene)
            }
        }
        
        // Check for death
        if !health.isAlive {
            handleBallDestruction(ball, health: health)
        }
    }
    
    /// Handle ball destruction when HP reaches 0
    private func handleBallDestruction(_ ball: BlockBall, health: BallHealth) {
        #if DEBUG
        if debugEnabled {
            print("💀 \(ball.ballKind) ball destroyed!")
        }
        #endif
        
        // Check if this is a cue ball before destruction
        let isCueBall = ball.ballKind == .cue
        
        // Check if this ball has explode accessories
        let hasExplodeOnContact = BallAccessoryManager.shared.hasAccessory(ball: ball, id: "explodeOnContact")
        let hasExplodeOnDestroy = BallAccessoryManager.shared.hasAccessory(ball: ball, id: "explodeOnDestroy")
        
        // Stop all ball movement immediately
        ball.physicsBody?.velocity = .zero
        ball.physicsBody?.angularVelocity = 0
        ball.physicsBody?.isDynamic = false  // Prevent any further physics interactions
        
        // Notify delegate about the destruction
        delegate?.ballDamageSystem(self, didDestroyBall: ball)
        
        // If ball has explode on contact accessory, create massive explosion and destroy nearby blocks
        if hasExplodeOnContact {
            // Convert to blocks before explosion
            ball.convertToBlocks()
            createMassiveExplosion(at: ball.position, ball: ball)
        }
        // NEW: If ball has explode on destroy accessory, create explosion at death
        else if hasExplodeOnDestroy {
            #if DEBUG
            print("💥 Ball has explodeOnDestroy - creating explosion at death position!")
            #endif
            
            // Convert to blocks before explosion
            ball.convertToBlocks()
            createMassiveExplosion(at: ball.position, ball: ball)
        }
        else {
            // Create destruction effect based on config for normal balls
            switch config.destructionEffect {
            case .explode:
                // Convert to blocks before explosion
                ball.convertToBlocks()
                createDestructionEffect(at: ball.position, ball: ball)
            case .crumble:
                // Convert to blocks before crumble
                ball.convertToBlocks()
                createCrumbleEffect(at: ball.position, ball: ball)
            }
        }
        
        // Remove health bar
        health.healthBar?.removeFromParent()
        
        // Trigger ball removal (you might want to add a method to BlockBall for this)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let scaleDown = SKAction.scale(to: 0.1, duration: 0.3)
        let group = SKAction.group([fadeOut, scaleDown])
        let remove = SKAction.removeFromParent()
        ball.run(SKAction.sequence([group, remove]))
        
        // Unregister
        unregisterBall(ball)
        
        // If a cue ball was destroyed, only request respawn if none remain
        if isCueBall {
            #if DEBUG
            if debugEnabled {
                print("🔄 Cue ball destroyed. Alive cue balls remaining: \(aliveCueBallCount)")
            }
            #endif
            if aliveCueBallCount == 0 {
                #if DEBUG
                if debugEnabled {
                    print("✅ No cue balls remain — requesting respawn")
                }
                #endif
                delegate?.ballDamageSystemShouldRespawnCueBall(self)
            } else {
                #if DEBUG
                if debugEnabled {
                    print("⏭️ Not respawning cue ball because others are still alive")
                }
                #endif
            }
        }
        
        // Check if all non-cue balls are gone
        checkForLevelCompletion()
    }
    
    /// Check if all target balls (non-cue balls) have been destroyed
    private func checkForLevelCompletion() {
        #if DEBUG
        if debugEnabled {
            print("🔍 Checking for level completion...")
            print("   Total registered balls: \(ballHealthMap.count)")
            for (id, health) in ballHealthMap {
                if let ball = health.ball {
                    print("   - \(ball.ballKind) ball: alive=\(health.isAlive), HP=\(health.currentHP)")
                } else {
                    print("   - Unknown ball (nil reference): alive=\(health.isAlive)")
                }
            }
        }
        #endif
        
        let remainingTargets = ballHealthMap.values.filter { health in
            guard let ball = health.ball, health.isAlive else { return false }
            return ball.ballKind != .cue
        }
        
        #if DEBUG
        if debugEnabled {
            print("🎯 Remaining target balls: \(remainingTargets.count)")
        }
        #endif
        
        if remainingTargets.isEmpty {
            #if DEBUG
            if debugEnabled {
                print("🎉 All target balls destroyed! Level complete!")
                print("🛑 FREEZING all cue balls immediately for instant feedback!")
            }
            #endif
            
            // ⚡ PERFORMANCE & UX: Immediately freeze all cue balls
            freezeAllCueBalls()
            
            delegate?.ballDamageSystemDidClearAllTargets(self)
        }
    }
    
    /// Immediately freeze all cue balls (called when level is complete)
    private func freezeAllCueBalls() {
        for health in ballHealthMap.values {
            guard let ball = health.ball else { continue }
            guard ball.ballKind == .cue else { continue }
            guard let body = ball.physicsBody else { continue }
            
            // Slam to a stop - no gradual slowdown
            body.velocity = .zero
            body.angularVelocity = 0
            
            // Make kinematic to prevent any further movement from collisions
            body.isDynamic = false
            
            #if DEBUG
            if debugEnabled {
                print("🛑 Froze cue ball at position \(ball.position)")
            }
            #endif
        }
    }
    
    // MARK: - Health Bar Visuals
    
    private func createHealthBar(for ball: BlockBall, health: BallHealth) {
        guard let scene = scene else { return }
        
        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 4
        let barYOffset: CGFloat = 20
        
        let container = SKNode()
        container.name = "healthBar"
        container.zPosition = 2000
        
        // Background (red)
        let background = SKSpriteNode(color: .red, size: CGSize(width: barWidth, height: barHeight))
        background.name = "healthBarBG"
        container.addChild(background)
        
        // Foreground (green)
        let foreground = SKSpriteNode(color: .green, size: CGSize(width: barWidth, height: barHeight))
        foreground.name = "healthBarFG"
        foreground.anchorPoint = CGPoint(x: 0, y: 0.5)
        foreground.position = CGPoint(x: -barWidth / 2, y: 0)
        container.addChild(foreground)
        
        // Border
        let border = SKShapeNode(rect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: barWidth, height: barHeight))
        border.strokeColor = .white
        border.lineWidth = 0.5
        border.fillColor = .clear
        container.addChild(border)
        
        scene.addChild(container)
        health.healthBar = container
        
        updateHealthBar(for: health)
    }
    
    private func updateHealthBar(for health: BallHealth) {
        guard let ball = health.ball,
              let container = health.healthBar,
              let foreground = container.childNode(withName: "healthBarFG") as? SKSpriteNode else {
            return
        }
        
        // Position above ball
        let barYOffset: CGFloat = 20
        container.position = CGPoint(x: ball.position.x, y: ball.position.y + barYOffset)
        
        // Update foreground width based on health percentage
        let barWidth: CGFloat = 30
        let newWidth = barWidth * health.healthPercentage
        foreground.xScale = health.healthPercentage
        
        // Color transition: green -> yellow -> orange -> red
        if health.healthPercentage > 0.66 {
            foreground.color = .green
        } else if health.healthPercentage > 0.33 {
            foreground.color = .yellow
        } else if health.healthPercentage > 0.15 {
            foreground.color = .orange
        } else {
            foreground.color = .red
        }
        
        // Hide health bar if at full health (optional)
        container.alpha = health.healthPercentage < 1.0 ? 1.0 : 0.3
    }
    
    // MARK: - Visual Effects
    
    private func showDamageEffect(at position: CGPoint, damage: CGFloat) {
        // Skip if damage numbers are disabled
        guard config.showDamageNumbers else { return }
        
        guard let scene = scene else { return }
        
        #if DEBUG
        if debugEnabled {
            print("✨ Creating damage label: -\(Int(damage)) at \(position)")
        }
        #endif
        
        // Create damage number - make it bigger and more visible
        let damageText = "-\(Int(damage))"
        let label = SKLabelNode(text: damageText)
        label.fontSize = 20  // Increased from 14
        label.fontColor = .red
        label.fontName = "Helvetica-Bold"
        label.position = position
        label.zPosition = 5000  // Very high z-position to ensure visibility
        
        scene.addChild(label)
        
        #if DEBUG
        if debugEnabled {
            print("   Label added to scene at z: \(label.zPosition)")
        }
        #endif
        
        // Animate: float up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 1.0)  // Slower, more visible
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        label.run(SKAction.sequence([group, remove]))
        
        // Create impact flash
        createImpactFlash(at: position)
    }
    
    private func createImpactFlash(at position: CGPoint) {
        guard let scene = scene else { return }
        
        let flash = SKShapeNode(circleOfRadius: 8)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.zPosition = 2500
        flash.alpha = 0.8
        
        scene.addChild(flash)
        
        let scaleUp = SKAction.scale(to: 2.0, duration: 0.15)
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        flash.run(SKAction.sequence([group, remove]))
    }
    
    private func createDestructionEffect(at position: CGPoint, ball: BlockBall) {
        guard let scene = scene else { return }
        
        // Find the visual container to extract the actual blocks
        guard let visualContainer = ball.children.first(where: { $0.name == "ballVisual" }) else {
            #if DEBUG
            if debugEnabled {
                print("⚠️ Could not find visual container for destruction effect")
            }
            #endif
            return
        }
        
        // Get all block sprites from the visual container (excluding the 8-ball spot and twoSpot)
        let blocks = visualContainer.children.compactMap { $0 as? SKSpriteNode }.filter { $0.name != "eightSpot" && $0.name != "twoSpot" }
        
        #if DEBUG
        if debugEnabled {
            print("💥 Exploding \(blocks.count) blocks from \(ball.ballKind) ball")
        }
        #endif
        
        // Launch each block in a random direction
        for block in blocks {
            // Get the block's world position
            let blockWorldPos = scene.convert(block.position, from: visualContainer)
            
            // Create a copy of the block for the explosion
            let explodingBlock = SKSpriteNode(color: block.color, size: block.size)
            explodingBlock.position = blockWorldPos
            explodingBlock.zPosition = 2500
            explodingBlock.texture?.filteringMode = .nearest
            explodingBlock.colorBlendFactor = block.colorBlendFactor
            
            scene.addChild(explodingBlock)
            
            // Calculate explosion direction (radial from center)
            let dx = blockWorldPos.x - position.x
            let dy = blockWorldPos.y - position.y
            let distance = hypot(dx, dy)
            
            // Normalize and add some randomness
            let explosionSpeed: CGFloat = CGFloat.random(in: 80...150)
            var vx = (distance > 0) ? (dx / distance) * explosionSpeed : CGFloat.random(in: -1...1) * explosionSpeed
            var vy = (distance > 0) ? (dy / distance) * explosionSpeed : CGFloat.random(in: -1...1) * explosionSpeed
            
            // Add some randomness to make it more chaotic
            vx += CGFloat.random(in: -30...30)
            vy += CGFloat.random(in: -30...30)
            
            let duration: TimeInterval = 0.6
            
            // Apply physics-like rotation
            let randomRotation = CGFloat.random(in: -(.pi * 2)...(.pi * 2))
            let rotate = SKAction.rotate(byAngle: randomRotation, duration: duration)
            
            let moveAction = SKAction.moveBy(x: vx, y: vy, duration: duration)
            let fadeOut = SKAction.fadeOut(withDuration: duration)
            let scaleDown = SKAction.scale(to: 0.3, duration: duration)
            
            let group = SKAction.group([moveAction, fadeOut, scaleDown, rotate])
            let remove = SKAction.removeFromParent()
            
            explodingBlock.run(SKAction.sequence([group, remove]))
        }
        
        #if DEBUG
        if debugEnabled {
            print("💥 Destruction effect created at \(position)")
        }
        #endif
    }
    
    /// Alternative destruction effect where blocks slowly crumble and fall apart
    private func createCrumbleEffect(at position: CGPoint, ball: BlockBall) {
        guard let scene = scene else { return }
        
        // Find the visual container to extract the actual blocks
        guard let visualContainer = ball.children.first(where: { $0.name == "ballVisual" }) else {
            #if DEBUG
            if debugEnabled {
                print("⚠️ Could not find visual container for crumble effect")
            }
            #endif
            return
        }
        
        // Get all block sprites from the visual container (excluding the 8-ball spot and twoSpot)
        let blocks = visualContainer.children.compactMap { $0 as? SKSpriteNode }.filter { $0.name != "eightSpot" && $0.name != "twoSpot" }
        
        #if DEBUG
        if debugEnabled {
            print("🧱 Crumbling \(blocks.count) blocks from \(ball.ballKind) ball")
        }
        #endif
        
        // Process blocks in stages - blocks further from center break off first
        var blockDistances: [(block: SKSpriteNode, distance: CGFloat, worldPos: CGPoint)] = []
        
        for block in blocks {
            let blockWorldPos = scene.convert(block.position, from: visualContainer)
            let dx = blockWorldPos.x - position.x
            let dy = blockWorldPos.y - position.y
            let distance = hypot(dx, dy)
            blockDistances.append((block, distance, blockWorldPos))
        }
        
        // Sort by distance (furthest first)
        blockDistances.sort { $0.distance > $1.distance }
        
        // Determine ground level (50% closer - was 80, now 40)
        var groundLevel = position.y - 40
        
        // Clamp to scene bounds to prevent going below the table rail
        // Assume rail is at the bottom ~20% of the scene
        let minGroundLevel = scene.frame.minY + (scene.frame.height * 0.2)
        if groundLevel < minGroundLevel {
            groundLevel = minGroundLevel
            #if DEBUG
            if debugEnabled {
                print("🧱 Clamping pile to rail edge at y: \(groundLevel)")
            }
            #endif
        }
        
        // Create crumbling blocks with staggered timing
        for (index, blockInfo) in blockDistances.enumerated() {
            let block = blockInfo.block
            let blockWorldPos = blockInfo.worldPos
            
            // Create a copy of the block
            let crumbleBlock = SKSpriteNode(color: block.color, size: block.size)
            crumbleBlock.position = blockWorldPos
            crumbleBlock.zPosition = 2500
            crumbleBlock.texture?.filteringMode = .nearest
            crumbleBlock.colorBlendFactor = block.colorBlendFactor
            
            scene.addChild(crumbleBlock)
            
            // Calculate staggered delay - outer blocks fall first
            let delayPerBlock: TimeInterval = 0.02
            let initialDelay = TimeInterval(index) * delayPerBlock
            
            // Calculate direction from center (for initial separation)
            let dx = blockWorldPos.x - position.x
            let dy = blockWorldPos.y - position.y
            let distance = hypot(dx, dy)
            
            // Normalize direction
            let dirX = distance > 0 ? dx / distance : 0
            let dirY = distance > 0 ? dy / distance : 0
            
            // Small outward drift as blocks separate
            let separationDistance: CGFloat = CGFloat.random(in: 3...8)
            let separationDuration: TimeInterval = 0.15
            
            // Calculate final landing position in pile
            let horizontalDrift: CGFloat = CGFloat.random(in: -20...20)
            let finalX = blockWorldPos.x + dirX * separationDistance + horizontalDrift
            let finalY = groundLevel + CGFloat.random(in: 0...8) // Slight vertical variation for pile effect
            
            // Calculate fall distance
            let fallDistance = blockWorldPos.y + (dirY * separationDistance) - finalY
            let fallDuration: TimeInterval = 0.5
            
            // Slight wobble rotation
            let wobbleAngle: CGFloat = CGFloat.random(in: -(.pi / 4)...(.pi / 4))
            
            // Build the action sequence
            let wait = SKAction.wait(forDuration: initialDelay)
            
            // Phase 1: Separate from ball slightly
            let separate = SKAction.moveBy(
                x: dirX * separationDistance,
                y: dirY * separationDistance,
                duration: separationDuration
            )
            separate.timingMode = .easeOut
            
            let initialRotate = SKAction.rotate(byAngle: wobbleAngle * 0.3, duration: separationDuration)
            let separateGroup = SKAction.group([separate, initialRotate])
            
            // Phase 2: Fall to ground and land
            let fall = SKAction.move(
                to: CGPoint(x: finalX, y: finalY),
                duration: fallDuration
            )
            fall.timingMode = .easeIn
            
            let tumble = SKAction.rotate(byAngle: wobbleAngle, duration: fallDuration)
            let fallGroup = SKAction.group([fall, tumble])
            
            // Phase 3: Settle briefly (pile up moment)
            let settle = SKAction.wait(forDuration: 0.3)
            
            // Phase 4: Fade out from the pile
            let pileFadeOut = SKAction.fadeOut(withDuration: 0.4)
            pileFadeOut.timingMode = .easeIn
            
            let pileScaleDown = SKAction.scale(to: 0.6, duration: 0.4)
            pileScaleDown.timingMode = .easeIn
            
            let disappear = SKAction.group([pileFadeOut, pileScaleDown])
            
            // Final sequence
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([wait, separateGroup, fallGroup, settle, disappear, remove])
            
            crumbleBlock.run(sequence)
        }
        
        #if DEBUG
        if debugEnabled {
            print("🧱 Crumble effect created at \(position) with pile buildup at y: \(groundLevel)")
        }
        #endif
    }
    
    /// Massive explosion effect for eleven ball - creates shockwave that destroys blocks in radius
    private func createMassiveExplosion(at position: CGPoint, ball: BlockBall) {
        let explosionMethodStart = CFAbsoluteTimeGetCurrent()
        
        guard let scene = scene else { return }
        
        #if DEBUG
        if debugEnabled {
            print("💥💥💥 MASSIVE EXPLOSION from \(ball.ballKind) ball at \(position)")
            print("   ⏱️ createMassiveExplosion start: \(explosionMethodStart)")
        }
        #endif
        
        let blockSize: CGFloat = 5.0 // Size of each felt block
        let explosionRadius: CGFloat = config.explosionRadius * blockSize // Use config value
        
        let beforeShockwave = CFAbsoluteTimeGetCurrent()
        
        // Create shockwave visual effect FIRST - most visible/important
        createShockwave(at: position, radius: explosionRadius)
        
        let afterShockwave = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        if debugEnabled {
            print("   ⏱️ Shockwave created: +\(String(format: "%.4f", (afterShockwave - beforeShockwave) * 1000))ms")
        }
        #endif
        
        // Defer felt block destruction to next frame to avoid blocking
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // DESTROY FELT BLOCKS - Create ragged hole in the playing surface
            self.destroyFeltBlocks(at: position, radius: explosionRadius, blockSize: blockSize, in: scene)
        }
        
        #if DEBUG
        if debugEnabled {
            let afterDeferFelt = CFAbsoluteTimeGetCurrent()
            print("   ⏱️ Felt destruction deferred: +\(String(format: "%.4f", (afterDeferFelt - afterShockwave) * 1000))ms")
            print("   ⏱️ TOTAL createMassiveExplosion: +\(String(format: "%.4f", (afterDeferFelt - explosionMethodStart) * 1000))ms")
        }
        #endif
        
        // Get all registered balls and damage their blocks if within radius
        for (_, health) in ballHealthMap {
            guard let targetBall = health.ball,
                  targetBall !== ball, // Don't affect the exploding ball itself
                  health.isAlive else { continue }
            
            let dx = targetBall.position.x - position.x
            let dy = targetBall.position.y - position.y
            let distance = hypot(dx, dy)
            
            // If ball is within explosion radius, destroy its blocks and deal massive damage
            if distance <= explosionRadius {
                #if DEBUG
                if debugEnabled {
                    print("   💥 \(targetBall.ballKind) ball within explosion radius (distance: \(String(format: "%.1f", distance)))")
                }
                #endif
                
                // SPECIAL CASE: Balls with explode on contact accessory instantly chain-explode!
                if BallAccessoryManager.shared.hasAccessory(ball: targetBall, id: "explodeOnContact") {
                    #if DEBUG
                    if debugEnabled {
                        print("   💥💥 CHAIN REACTION! \(targetBall.ballKind) ball with explodeOnContact instantly destroyed!")
                    }
                    #endif
                    
                    // Instantly destroy the ball (set HP to 0)
                    health.currentHP = 0
                    handleBallDestruction(targetBall, health: health)
                    continue  // Skip to next ball
                }
                
                // SPECIAL CASE: Balls with explode on destroy should get instant-killed to trigger chain reaction
                if BallAccessoryManager.shared.hasAccessory(ball: targetBall, id: "explodeOnDestroy") {
                    #if DEBUG
                    if debugEnabled {
                        print("   💥💥 CHAIN REACTION! \(targetBall.ballKind) ball with explodeOnDestroy instantly destroyed!")
                    }
                    #endif
                    
                    // Instantly destroy the ball (set HP to 0)
                    health.currentHP = 0
                    handleBallDestruction(targetBall, health: health)
                    continue  // Skip to next ball
                }
                
                // Get the visual container and extract blocks
                guard let visualContainer = targetBall.children.first(where: { $0.name == "ballVisual" }) else {
                    continue
                }
                
                let blocks = visualContainer.children.compactMap { $0 as? SKSpriteNode }.filter { 
                    $0.name != "eightSpot" && $0.name != "twoSpot" && $0.name != "elevenStripe" 
                }
                
                // Calculate how many blocks to destroy based on distance
                // Closer = more blocks destroyed
                let destructionRatio = 1.0 - (distance / explosionRadius)
                let blocksToDestroy = Int(CGFloat(blocks.count) * destructionRatio)
                
                #if DEBUG
                if debugEnabled {
                    print("   💥 Destroying \(blocksToDestroy) of \(blocks.count) blocks (ratio: \(String(format: "%.2f", destructionRatio)))")
                }
                #endif
                
                // Randomly select and explode blocks
                let shuffledBlocks = blocks.shuffled()
                for i in 0..<min(blocksToDestroy, shuffledBlocks.count) {
                    let block = shuffledBlocks[i]
                    explodeBlock(block, from: visualContainer, explosionCenter: position, inScene: scene)
                }
                
                // Apply 80 damage to all balls in radius (regardless of distance)
                let explosionDamage: CGFloat = 80.0
                applyDamage(explosionDamage, to: targetBall, at: targetBall.position)
                
                #if DEBUG
                if debugEnabled {
                    print("   💥 Applied \(explosionDamage) explosion damage to \(targetBall.ballKind) ball")
                }
                #endif
            }
        }
        
        // Create the ball's own destruction effect (explode all blocks)
        createDestructionEffect(at: position, ball: ball)
    }
    
    /// Destroy felt blocks in an irregular radius to create a ragged hole
    private func destroyFeltBlocks(at position: CGPoint, radius: CGFloat, blockSize: CGFloat, in scene: SKScene) {
        #if DEBUG
        if debugEnabled {
            print("🕳️ Grid-only explosion at \(position) with radius \(radius)")
            print("   FeltManager available: \(feltManager != nil)")
        }
        #endif
        
        // Use FeltManager's grid-only explosion (NO BLOCK MODE SWITCHING!)
        guard let fm = feltManager else {
            print("⚠️ No FeltManager - skipping explosion")
            return
        }
        
        // Grid-only explosion: instant, no scene graph changes, just texture rebake
        let destroyedCount = fm.createExplosion(at: position, radius: radius, scene: scene)
        
        #if DEBUG
        if debugEnabled {
            print("✅ Grid-only explosion complete: \(destroyedCount) cells destroyed")
        }
        #endif
    }
    
    /// Create expanding shockwave visual
    private func createShockwave(at position: CGPoint, radius: CGFloat) {
        guard let scene = scene else { return }
        
        // Create multiple expanding rings for shockwave effect
        for i in 0..<3 {
            let delay = TimeInterval(i) * 0.05
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak scene] in
                guard let scene = scene else { return }
                
                let ring = SKShapeNode(circleOfRadius: 5)
                ring.strokeColor = .orange
                ring.fillColor = .clear
                ring.lineWidth = 3.0
                ring.position = position
                ring.zPosition = 3000
                ring.alpha = 0.8
                
                scene.addChild(ring)
                
                let expand = SKAction.scale(to: radius / 5.0, duration: 0.4)
                expand.timingMode = .easeOut
                let fadeOut = SKAction.fadeOut(withDuration: 0.4)
                let thicken = SKAction.customAction(withDuration: 0.4) { node, elapsedTime in
                    if let shape = node as? SKShapeNode {
                        shape.lineWidth = 3.0 * (1.0 - elapsedTime / 0.4)
                    }
                }
                let group = SKAction.group([expand, fadeOut, thicken])
                let remove = SKAction.removeFromParent()
                
                ring.run(SKAction.sequence([group, remove]))
            }
        }
        
        // Add bright flash at center
        let flash = SKShapeNode(circleOfRadius: radius * 0.3)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.zPosition = 2999
        flash.alpha = 1.0
        
        scene.addChild(flash)
        
        let scaleUp = SKAction.scale(to: 2.0, duration: 0.3)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        flash.run(SKAction.sequence([group, remove]))
        
        #if DEBUG
        if debugEnabled {
            print("💥 Shockwave created with radius: \(radius)")
        }
        #endif
    }
    
    /// Explode a single block from a ball
    private func explodeBlock(_ block: SKSpriteNode, from visualContainer: SKNode, explosionCenter: CGPoint, inScene scene: SKScene) {
        // Get the block's world position
        let blockWorldPos = scene.convert(block.position, from: visualContainer)
        
        // Create a copy of the block for the explosion
        let explodingBlock = SKSpriteNode(color: block.color, size: block.size)
        explodingBlock.position = blockWorldPos
        explodingBlock.zPosition = 2500
        explodingBlock.texture?.filteringMode = .nearest
        explodingBlock.colorBlendFactor = block.colorBlendFactor
        
        scene.addChild(explodingBlock)
        
        // Calculate explosion direction (radial from explosion center)
        let dx = blockWorldPos.x - explosionCenter.x
        let dy = blockWorldPos.y - explosionCenter.y
        let distance = hypot(dx, dy)
        
        // Normalize and apply explosive force
        let explosionSpeed: CGFloat = CGFloat.random(in: 120...200)
        let vx = (distance > 0) ? (dx / distance) * explosionSpeed : CGFloat.random(in: -1...1) * explosionSpeed
        let vy = (distance > 0) ? (dy / distance) * explosionSpeed : CGFloat.random(in: -1...1) * explosionSpeed
        
        let duration: TimeInterval = 0.8
        
        // Apply chaotic rotation
        let randomRotation = CGFloat.random(in: -(.pi * 3)...(.pi * 3))
        let rotate = SKAction.rotate(byAngle: randomRotation, duration: duration)
        
        let moveAction = SKAction.moveBy(x: vx, y: vy, duration: duration)
        let fadeOut = SKAction.fadeOut(withDuration: duration)
        let scaleDown = SKAction.scale(to: 0.2, duration: duration)
        
        let group = SKAction.group([moveAction, fadeOut, scaleDown, rotate])
        let remove = SKAction.removeFromParent()
        
        explodingBlock.run(SKAction.sequence([group, remove]))
        
        // Remove original block from ball
        block.removeFromParent()
    }

    // MARK: - Four Ball Special: Disintegration animation
    // NOTE: Pulse charging and triggering is now handled by PulseAccessory
    // The damage system only provides the disintegration animation effect
    
    /// Unique disintegration animation used only by the 4-ball pulse
    /// - Parameters:
    ///   - ball: The ball to disintegrate
    ///   - intensity: Effect intensity from 0.0 to 1.0 (1.0 = full effect, lower = weaker)
    func performDisintegrationAnimation(on ball: BlockBall, intensity: CGFloat) {
        guard let scene = scene else { return }
        // Convert to blocks to animate pieces
        ball.convertToBlocks()
        
        // Find visual blocks to disintegrate
        guard let visualContainer = ball.children.first(where: { $0.name == "ballVisual" }) else { return }
        let blocks = visualContainer.children.compactMap { $0 as? SKSpriteNode }
        
        // Scale number of blocks affected by intensity
        let affectedBlockCount = Int(CGFloat(blocks.count) * intensity)
        let affectedBlocks = blocks.shuffled().prefix(affectedBlockCount)
        
        for (index, block) in affectedBlocks.enumerated() {
            let worldPos = scene.convert(block.position, from: visualContainer)
            let piece = SKSpriteNode(color: block.color, size: block.size)
            piece.position = worldPos
            piece.zPosition = 3600
            piece.alpha = 1.0
            piece.texture?.filteringMode = .nearest
            scene.addChild(piece)
            
            // Stagger start for shimmering dissolve
            let delay = SKAction.wait(forDuration: 0.01 * Double(index % 10))
            
            // Scale drift and effects by intensity
            let driftScale = intensity
            let drift = CGVector(
                dx: CGFloat.random(in: -40...40) * driftScale,
                dy: CGFloat.random(in: 20...80) * driftScale
            )
            
            // Duration scales inversely with intensity (weaker = faster fade)
            let baseDuration: TimeInterval = 0.35
            let duration = baseDuration * TimeInterval(intensity)
            
            let move = SKAction.moveBy(x: drift.dx, y: drift.dy, duration: duration)
            move.timingMode = .easeOut
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -(.pi)...(.pi)) * intensity, duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let shrink = SKAction.scale(to: 0.01, duration: duration)
            let colorize = SKAction.customAction(withDuration: duration) { node, t in
                if let sprite = node as? SKSpriteNode {
                    let progress = t / duration
                    // Hue shift for colorful dissolve - scale saturation by intensity
                    sprite.colorBlendFactor = 0.8 * intensity
                    sprite.color = SKColor(hue: CGFloat(progress), saturation: 0.9 * intensity, brightness: 1.0, alpha: 1.0)
                }
            }
            let group = SKAction.group([move, spin, fade, shrink, colorize])
            let remove = SKAction.removeFromParent()
            piece.run(SKAction.sequence([delay, group, remove]))
        }
    }
    
    // MARK: - Cooldown Management
    
    private func makeCooldownKey(_ ball1: BlockBall, _ ball2: BlockBall) -> String {
        let id1 = ObjectIdentifier(ball1).hashValue
        let id2 = ObjectIdentifier(ball2).hashValue
        // Sort to ensure same key regardless of order
        return id1 < id2 ? "\(id1)-\(id2)" : "\(id2)-\(id1)"
    }
    
    private func isOnCooldown(_ key: String) -> Bool {
        guard let lastTime = collisionCooldowns[key] else { return false }
        return CACurrentMediaTime() - lastTime < cooldownDuration
    }
    
    private func setCooldown(_ key: String) {
        collisionCooldowns[key] = CACurrentMediaTime()
    }
    
    private func cleanupOldCooldowns() {
        let now = CACurrentMediaTime()
        collisionCooldowns = collisionCooldowns.filter { now - $0.value < cooldownDuration }
    }
    
    // MARK: - Temporary Immunity Management
    
    /// Set temporary immunity between two balls to prevent damage
    /// Useful when spawning balls near each other (e.g., 2-ball splitting)
    func setTemporaryImmunity(between ball1: BlockBall, and ball2: BlockBall, duration: TimeInterval) {
        let key = makeCooldownKey(ball1, ball2)
        immunityPairs[key] = CACurrentMediaTime() + duration
        #if DEBUG
        if debugEnabled {
            print("🛡 Set temporary immunity between \(ball1.ballKind) and \(ball2.ballKind) for \(duration)s")
        }
        #endif
    }
    
    private func hasImmunity(_ key: String) -> Bool {
        guard let expiryTime = immunityPairs[key] else { return false }
        let now = CACurrentMediaTime()
        if now >= expiryTime {
            // Immunity expired, remove it
            immunityPairs.removeValue(forKey: key)
            return false
        }
        return true
    }
    
    private func cleanupExpiredImmunities() {
        let now = CACurrentMediaTime()
        immunityPairs = immunityPairs.filter { $0.value > now }
    }
    
    // MARK: - Update
    
    /// Call this every frame to update health bars and cleanup cooldowns
    func update(deltaTime: TimeInterval) {
        // Update health bar positions and clean up orphaned bars
        var orphanedIDs: [ObjectIdentifier] = []
        
        for (id, health) in ballHealthMap {
            // Check if ball still exists
            if health.ball == nil || health.ball?.parent == nil {
                // Ball was removed but not unregistered properly
                orphanedIDs.append(id)
                health.healthBar?.removeFromParent()
                #if DEBUG
                if debugEnabled {
                    print("🧹 Cleaning up orphaned health bar")
                }
                #endif
            } else {
                // Update position for active balls
                updateHealthBar(for: health)
            }
        }
        
        // Remove orphaned entries
        for id in orphanedIDs {
            ballHealthMap.removeValue(forKey: id)
        }
        
        // Periodically cleanup old cooldowns and expired immunities
        if Int(CACurrentMediaTime()) % 5 == 0 {
            cleanupOldCooldowns()
            cleanupExpiredImmunities()
        }
    }
    
    // MARK: - Query Methods
    
    /// Get current HP for a ball
    func getHP(for ball: BlockBall) -> CGFloat? {
        let id = ObjectIdentifier(ball)
        return ballHealthMap[id]?.currentHP
    }
    
    /// Get max HP for a ball
    func getMaxHP(for ball: BlockBall) -> CGFloat? {
        let id = ObjectIdentifier(ball)
        return ballHealthMap[id]?.maxHP
    }
    
    /// Check if a ball is alive
    func isAlive(_ ball: BlockBall) -> Bool {
        let id = ObjectIdentifier(ball)
        return ballHealthMap[id]?.isAlive ?? false
    }
    
    /// Get all registered balls
    var registeredBalls: [BlockBall] {
        return ballHealthMap.values.compactMap { $0.ball }
    }
    
    /// Get count of alive non-cue balls (target balls)
    var aliveTargetBallCount: Int {
        return ballHealthMap.values.filter { health in
            guard let ball = health.ball, health.isAlive else { return false }
            return ball.ballKind != .cue
        }.count
    }
    
    /// Get count of alive cue balls
    var aliveCueBallCount: Int {
        return ballHealthMap.values.filter { health in
            guard let ball = health.ball, health.isAlive else { return false }
            return ball.ballKind == .cue
        }.count
    }
    
    /// Reset all balls to full health
    func resetAllHealth() {
        for (_, health) in ballHealthMap {
            health.currentHP = health.maxHP
            updateHealthBar(for: health)
        }
        
        #if DEBUG
        if debugEnabled {
            print("❤️‍🩹 Reset all ball health")
        }
        #endif
    }
    
    /// Heal a specific ball
    func heal(_ ball: BlockBall, amount: CGFloat) {
        let id = ObjectIdentifier(ball)
        guard let health = ballHealthMap[id] else { return }
        
        health.currentHP = min(health.maxHP, health.currentHP + amount)
        updateHealthBar(for: health)
        
        #if DEBUG
        if debugEnabled {
            print("❤️‍🩹 Healed \(ball.ballKind) ball for \(amount). HP: \(health.currentHP)/\(health.maxHP)")
        }
        #endif
    }
    
    /// Show all health bars
    func showAllHealthBars() {
        for (_, health) in ballHealthMap {
            health.healthBar?.isHidden = false
        }
    }
    
    /// Hide all health bars
    func hideAllHealthBars() {
        for (_, health) in ballHealthMap {
            health.healthBar?.isHidden = true
        }
    }
    
}

