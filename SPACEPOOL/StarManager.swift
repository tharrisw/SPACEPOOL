//
//  StarManager.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Manages star spawning, updating, and special events like supernovas and comets
class StarManager {
    // MARK: - Properties
    private weak var scene: SKScene?
    private var random: SeededRandom
    
    // Star tracking
    private(set) var stars: [Star] = []
    private(set) var totalStarsSpawned: Int = 0
    private var timeSinceLastSpawn: TimeInterval = 0
    
    // Configuration constants
    private let spawnInterval: TimeInterval = 0.15
    private let maxStars: Int = 300
    private let initialStarCount: Int = 100
    private let minSize: Double = 2.0
    private let maxSize: Double = 75.0
    private let minGrowthMultiplier: Double = 0.2
    private let maxGrowthMultiplier: Double = 2.5
    private let visibilityThreshold: Double = 0.05
    private let fadeInRange: Double = 0.03
    private let baseGrowthRate: Double = 0.08
    private let baseInitialGrowthRate: Double = 0.015
    private let removalBuffer: Double = 20.0
    private let twinklePercentage: Double = 0.6
    
    // Special Events configuration
    private let specialEventOdds: Double = 0.0001  // 1 in 10,000 chance per star
    
    // Comet configuration
    private let cometMinSize: Double = 8.0
    private let cometMaxSize: Double = 16.0
    private let cometMinSpeed: Double = 150.0
    private let cometMaxSpeed: Double = 300.0
    private let cometColor = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)  // Blue
    
    // Screen properties
    private var centerPoint: CGPoint
    private var maxDistanceFromCenter: Double
    private var sceneSize: CGSize
    
    // Speed scaling (from game state)
    private var baseMinSpeed: Double = 20.0
    private var baseMaxSpeed: Double = 60.0
    private var speedScale: (Double) -> Double
    
    // Special event types
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
    
    // MARK: - Initialization
    init(scene: SKScene, random: SeededRandom, speedScale: @escaping (Double) -> Double) {
        self.scene = scene
        self.random = random
        self.speedScale = speedScale
        self.sceneSize = scene.size
        self.centerPoint = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        self.maxDistanceFromCenter = sqrt(pow(scene.size.width / 2, 2) + pow(scene.size.height / 2, 2))
    }
    
    // MARK: - Public Methods
    
    /// Populate initial stars across the screen
    func populateInitialStars() {
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
    
    /// Update all stars for the given delta time
    func update(deltaTime: TimeInterval) -> Bool {
        // Update spawn timer and spawn new stars if needed
        var didSpawnStar = false
        timeSinceLastSpawn += deltaTime
        if timeSinceLastSpawn >= spawnInterval && stars.count < maxStars {
            timeSinceLastSpawn = 0
            spawnStar(at: centerPoint, isInitial: false)
            didSpawnStar = true
        }
        
        // Update existing stars
        updateStars(deltaTime: deltaTime)
        
        return didSpawnStar
    }
    
    // MARK: - Private Methods
    
    private func spawnStar(at position: CGPoint, isInitial: Bool, angle: Double? = nil) {
        guard let scene = scene else { return }
        
        totalStarsSpawned += 1
        
        // Check for special event trigger (only for non-initial stars)
        var triggeredEvent: SpecialEvent? = nil
        if !isInitial && random.nextDouble() < specialEventOdds {
            triggeredEvent = triggerRandomSpecialEvent()
        }
        
        // Skip spawning this star if any special event was triggered
        if triggeredEvent != nil {
            return
        }
        
        // Create sprite
        let sprite = SKSpriteNode(color: .white, size: CGSize(width: minSize, height: minSize))
        sprite.position = position
        sprite.zPosition = 1
        
        // Disable antialiasing for pixel-perfect rendering
        sprite.texture?.filteringMode = .nearest
        
        // Set initial alpha
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
        
        // Determine color
        let color = selectStarColor(isSupernova: false)
        sprite.color = color
        
        // Calculate velocity with scaling
        let starAngle = angle ?? random.nextDouble(in: 0...(2 * .pi))
        let minSpeed = speedScale(baseMinSpeed)
        let maxSpeed = speedScale(baseMaxSpeed)
        let speed = random.nextDouble(in: minSpeed...maxSpeed)
        let vx = cos(starAngle) * speed
        let vy = sin(starAngle) * speed
        let velocity = CGVector(dx: vx, dy: vy)
        
        // Twinkle properties
        let shouldTwinkle = random.nextDouble() < twinklePercentage
        let twinkleDuration = random.nextDouble(in: 0.3...0.8)
        let minTwinkleWait = random.nextDouble(in: 0.5...1.5)
        let maxTwinkleWait = random.nextDouble(in: 2.0...4.0)
        let minAlpha = random.nextDouble(in: 0.15...0.35)
        
        // Growth multiplier
        let growthMultiplier = random.nextDouble(in: minGrowthMultiplier...maxGrowthMultiplier)
        
        // Create star object
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
        scene.addChild(sprite)
        
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
            spawnManualSupernova()
            return .supernova
            
        case .comet:
            spawnComet()
            return .comet
        }
    }
    
    private func spawnManualSupernova() {
        guard let scene = scene else { return }
        
        // Spawn a supernova closer to center for longer visibility
        let randomAngle = random.nextDouble(in: 0...(2 * .pi))
        let randomDistance = random.nextDouble(in: 0.05...0.25) * maxDistanceFromCenter
        
        let x = centerPoint.x + CGFloat(cos(randomAngle) * randomDistance)
        let y = centerPoint.y + CGFloat(sin(randomAngle) * randomDistance)
        
        // Create sprite
        let sprite = SKSpriteNode(color: .white, size: CGSize(width: minSize, height: minSize))
        sprite.position = CGPoint(x: x, y: y)
        sprite.zPosition = 1
        sprite.zRotation = .pi / 4  // Diamond shape
        sprite.texture?.filteringMode = .nearest
        sprite.alpha = 0
        
        // Set supernova color
        sprite.color = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        
        // Create velocity (outward from center) - much slower speed!
        let minSpeed = speedScale(baseMinSpeed)
        let speed = random.nextDouble(in: minSpeed * 0.3...minSpeed * 0.6)
        let vx = cos(randomAngle) * speed
        let vy = sin(randomAngle) * speed
        let velocity = CGVector(dx: vx, dy: vy)
        
        // Explosion distance - will travel farther before exploding
        let explosionDistance = random.nextDouble(in: 0.5...0.8)
        
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
        scene.addChild(sprite)
        
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
        
        // Phase 4: Initial Expansion (0.12 seconds)
        let initialExpansion = SKAction.scale(to: 22.5, duration: 0.12)
        
        // Group flash and expansion together
        let flashAndExpand = SKAction.group([flash, initialExpansion])
        
        // Phase 5: Recoil Shrink (0.15 seconds)
        let recoilShrink = SKAction.scale(to: 18.0, duration: 0.15)
        
        // Phase 6: Re-expansion (0.25 seconds)
        let reExpansion = SKAction.scale(to: 24.0, duration: 0.25)
        
        // Phase 7: Color Shift Sequence (1.5 seconds total)
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
        
        // Start twinkling effect after initial flash
        let twinkleStart = SKAction.wait(forDuration: 0.8)
        let startTwinkleAction = SKAction.run { [weak self, weak star] in
            self?.startSupernovaTwinkle(for: star)
        }
        let twinkleSequence = SKAction.sequence([twinkleStart, startTwinkleAction])
        
        star.sprite.run(twinkleSequence, withKey: "startTwinkle")
    }
    
    private func startSupernovaTwinkle(for star: Star?) {
        guard let star = star else { return }
        guard star.sprite.action(forKey: "supernovaSequence") != nil else { return }
        
        // Generate random twinkle parameters for uneven effect
        let twinkleDuration = random.nextDouble(in: 0.05...0.15)
        let minAlpha = random.nextDouble(in: 0.6...0.85)
        let waitBetween = random.nextDouble(in: 0.02...0.08)
        
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
        guard let scene = scene else { return }
        
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
            startPosition = CGPoint(x: random.nextDouble(in: 0...Double(sceneSize.width)), y: Double(sceneSize.height))
        case 1: // Right
            startPosition = CGPoint(x: Double(sceneSize.width), y: random.nextDouble(in: 0...Double(sceneSize.height)))
        case 2: // Bottom
            startPosition = CGPoint(x: random.nextDouble(in: 0...Double(sceneSize.width)), y: 0)
        default: // Left
            startPosition = CGPoint(x: 0, y: random.nextDouble(in: 0...Double(sceneSize.height)))
        }
        
        // Get random end position on opposite side
        let endPosition: CGPoint
        switch endSide {
        case 0: // Top
            endPosition = CGPoint(x: random.nextDouble(in: 0...Double(sceneSize.width)), y: Double(sceneSize.height))
        case 1: // Right
            endPosition = CGPoint(x: Double(sceneSize.width), y: random.nextDouble(in: 0...Double(sceneSize.height)))
        case 2: // Bottom
            endPosition = CGPoint(x: random.nextDouble(in: 0...Double(sceneSize.width)), y: 0)
        default: // Left
            endPosition = CGPoint(x: 0, y: random.nextDouble(in: 0...Double(sceneSize.height)))
        }
        
        // Create comet sprite
        let comet = SKSpriteNode(color: cometColor, size: CGSize(width: cometSize, height: cometSize))
        comet.position = startPosition
        comet.zPosition = 2
        comet.texture?.filteringMode = .nearest
        scene.addChild(comet)
        
        // Calculate travel distance and duration
        let distance = hypot(endPosition.x - startPosition.x, endPosition.y - startPosition.y)
        let duration = TimeInterval(distance / CGFloat(speed))
        
        // Move comet
        let moveAction = SKAction.move(to: endPosition, duration: duration)
        
        // Spawn space dust trail at intervals
        let dustSpawnInterval = 0.05
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
        guard let scene = scene else { return }
        
        // Very small dust particle
        let dustSize = random.nextDouble(in: 0.5...1.5)
        let dust = SKSpriteNode(color: cometColor, size: CGSize(width: dustSize, height: dustSize))
        
        // Add slight random offset from comet position
        let offsetX = random.nextDouble(in: -3...3)
        let offsetY = random.nextDouble(in: -3...3)
        dust.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
        dust.zPosition = 1.5
        dust.texture?.filteringMode = .nearest
        dust.alpha = 1.0
        
        scene.addChild(dust)
        
        // Rapid sparkle effect
        let sparkleInterval = random.nextDouble(in: 0.05...0.15)
        let sparkleDuration = random.nextDouble(in: 0.02...0.08)
        let minSparkleAlpha = random.nextDouble(in: 0.3...0.6)
        
        let sparkleOut = SKAction.fadeAlpha(to: minSparkleAlpha, duration: sparkleDuration)
        let sparkleIn = SKAction.fadeAlpha(to: 1.0, duration: sparkleDuration)
        let sparkleWait = SKAction.wait(forDuration: sparkleInterval)
        let sparkleSequence = SKAction.sequence([sparkleOut, sparkleIn, sparkleWait])
        let sparkleForever = SKAction.repeatForever(sparkleSequence)
        
        dust.run(sparkleForever, withKey: "sparkle")
        
        // Slow fade out
        let fadeOutDuration = random.nextDouble(in: 3.0...8.0)
        let fadeOut = SKAction.fadeOut(withDuration: fadeOutDuration)
        
        dust.run(fadeOut) { [weak dust] in
            dust?.removeAllActions()
            dust?.removeFromParent()
        }
    }
    
    private func updateStars(deltaTime: TimeInterval) {
        var starsToRemove: [Star] = []
        
        let growthRate = speedScale(baseGrowthRate)
        let initialGrowthRate = speedScale(baseInitialGrowthRate)
        
        for star in stars {
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
                continue
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
                var newSize = minSize + (maxSize - minSize) * normalizedDistance * star.growthMultiplier * currentGrowthRate
                
                // Cap initial star sizes
                if star.isInitialStar {
                    newSize = min(newSize, maxSize * 0.2)
                }
                
                star.sprite.size = CGSize(width: newSize, height: newSize)
            }
            
            // Check if star is off screen
            let bounds = CGRect(
                x: -removalBuffer,
                y: -removalBuffer,
                width: sceneSize.width + removalBuffer * 2,
                height: sceneSize.height + removalBuffer * 2
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
}
