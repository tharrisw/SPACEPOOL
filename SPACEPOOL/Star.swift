import SpriteKit

/// Represents a single star with its physics and visual properties
class Star {
    let sprite: SKSpriteNode
    var velocity: CGVector
    let growthMultiplier: Double
    let baseSpeed: Double
    let angle: Double
    
    // Twinkle properties
    let shouldTwinkle: Bool
    let twinkleDuration: Double
    let minTwinkleWait: Double
    let maxTwinkleWait: Double
    let minAlpha: Double
    
    // Supernova properties
    let isSupernova: Bool
    var supernovaTriggered: Bool = false
    let supernovaExplosionDistance: Double  // Distance at which supernova will explode (normalized 0-1)
    
    // Size properties
    let isInitialStar: Bool
    
    init(sprite: SKSpriteNode, velocity: CGVector, growthMultiplier: Double,
         baseSpeed: Double, angle: Double, shouldTwinkle: Bool,
         twinkleDuration: Double, minTwinkleWait: Double, maxTwinkleWait: Double,
         minAlpha: Double, isSupernova: Bool, supernovaExplosionDistance: Double = 0,
         isInitialStar: Bool = false) {
        self.sprite = sprite
        self.velocity = velocity
        self.growthMultiplier = growthMultiplier
        self.baseSpeed = baseSpeed
        self.angle = angle
        self.shouldTwinkle = shouldTwinkle
        self.twinkleDuration = twinkleDuration
        self.minTwinkleWait = minTwinkleWait
        self.maxTwinkleWait = maxTwinkleWait
        self.minAlpha = minAlpha
        self.isSupernova = isSupernova
        self.supernovaExplosionDistance = supernovaExplosionDistance
        self.isInitialStar = isInitialStar
    }
}
