// Create a modular controller for the cue ball: manages spawning, input, visuals, physics, and persistence. Tacos
// This file is self-contained and interacts with an SKScene provided by the caller.

import SpriteKit
import UIKit

final class CueBallController {
    // Public configuration
    struct Config {
        var radius: CGFloat = 12
        var maxPowerDefault: CGFloat = 800  // Reasonable max impulse magnitude
        var maxShotDistance: CGFloat = 250  // Drag distance mapped to max power
        var ballRestLinearSpeedThreshold: CGFloat = 5
        var ballRestAngularSpeedThreshold: CGFloat = 0.5
        var ballRestCheckDuration: TimeInterval = 0.5
        var ballRestitution: CGFloat = 0.95
        var ballFriction: CGFloat = 0.02
        var ballLinearDamping: CGFloat = 0.25
        var ballAngularDamping: CGFloat = 0.2
        var lineColor: SKColor = .white
        var lineWidth: CGFloat = 3
        var arrowHeadLength: CGFloat = 12
        var arrowHeadAngle: CGFloat = .pi / 8
    }

    // Persistence key
    private let maxPowerKey = "CueBallMaxPower"

    // Scene and nodes
    private weak var scene: SKScene?
    private var tableFrameRect: CGRect = .zero

    private(set) var ball: SKShapeNode?
    private var aimLine: SKShapeNode?

    // State
    private var config: Config
    private var maxPower: CGFloat
    private var isAiming = false
    private var touchStartPoint: CGPoint = .zero
    private var restCheckTimer: TimeInterval = 0
    private var canShoot: Bool = true

    // Physics categories
    struct PhysicsCategory {
        static let cueBall: UInt32 = 1 << 0
        static let tableBounds: UInt32 = 1 << 1
        static let otherBalls: UInt32 = 1 << 2
    }

    init(scene: SKScene, tableFrameRect: CGRect, config: Config = Config()) {
        self.scene = scene
        self.tableFrameRect = tableFrameRect
        self.config = config
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: maxPowerKey) as? CGFloat
        self.maxPower = stored ?? config.maxPowerDefault
        if stored == nil {
            defaults.set(self.maxPower, forKey: maxPowerKey)
        }
    }

    func setMaxPower(_ value: CGFloat) {
        maxPower = value
        UserDefaults.standard.set(value, forKey: maxPowerKey)
    }

    // MARK: - Setup
    func spawnCueBall(at position: CGPoint) {
        guard let scene = scene else { return }
        let ball = SKShapeNode(circleOfRadius: config.radius)
        ball.fillColor = .white
        ball.strokeColor = .lightGray
        ball.lineWidth = 1
        ball.position = position
        ball.zPosition = 20

        // Physics body
        let body = SKPhysicsBody(circleOfRadius: config.radius)
        body.affectedByGravity = false
        body.allowsRotation = true
        body.restitution = config.ballRestitution
        body.friction = config.ballFriction
        body.linearDamping = config.ballLinearDamping
        body.angularDamping = config.ballAngularDamping
        body.categoryBitMask = PhysicsCategory.cueBall
        body.collisionBitMask = PhysicsCategory.tableBounds | PhysicsCategory.otherBalls | PhysicsCategory.cueBall
        body.contactTestBitMask = PhysicsCategory.otherBalls | PhysicsCategory.tableBounds
        ball.physicsBody = body

        scene.addChild(ball)
        self.ball = ball

        // Create or update aim line
        if aimLine == nil {
            let line = SKShapeNode()
            line.strokeColor = config.lineColor
            line.lineWidth = config.lineWidth
            line.zPosition = ball.zPosition + 1
            scene.addChild(line)
            aimLine = line
        }
        aimLine?.isHidden = true

        // Ensure table bounds are set up for collisions
        setupTableBounds()
    }

    private func setupTableBounds() {
        guard let scene = scene else { return }
        // Create an edge loop around the inner felt rect so the ball bounces off the cushions.
        // Remove existing bounds node if any
        scene.childNode(withName: "tableBounds")?.removeFromParent()

        let boundsNode = SKNode()
        boundsNode.name = "tableBounds"
        boundsNode.zPosition = 15
        boundsNode.position = .zero
        let body = SKPhysicsBody(edgeLoopFrom: tableFrameRect)
        body.friction = 0.02
        body.restitution = 0.95
        body.categoryBitMask = PhysicsCategory.tableBounds
        body.collisionBitMask = PhysicsCategory.cueBall | PhysicsCategory.otherBalls
        body.contactTestBitMask = PhysicsCategory.cueBall | PhysicsCategory.otherBalls
        boundsNode.physicsBody = body
        scene.addChild(boundsNode)
    }

    // MARK: - Input handling
    func touchesBegan(_ touches: Set<UITouch>) {
        guard canShoot, let scene = scene, let ball = ball, let touch = touches.first else { return }
        let location = touch.location(in: scene)
        if ball.contains(location) {
            isAiming = true
            touchStartPoint = ball.position
            aimLine?.position = ball.position  // Set aimLine position to ball position
            aimLine?.isHidden = false
            updateAimLine(to: location)
        }
    }

    func touchesMoved(_ touches: Set<UITouch>) {
        guard isAiming, let scene = scene, let touch = touches.first else { return }
        let location = touch.location(in: scene)
        updateAimLine(to: location)
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        guard isAiming, let scene = scene, let touch = touches.first, let ball = ball, let body = ball.physicsBody else { return }
        isAiming = false
        aimLine?.isHidden = true

        let endPoint = touch.location(in: scene)
        let shotVector = CGVector(dx: ball.position.x - endPoint.x, dy: ball.position.y - endPoint.y)
        let distance = hypot(shotVector.dx, shotVector.dy)
        if distance < 5 { return } // ignore tiny taps

        // Map drag distance to impulse up to maxPower
        let clamped = min(distance, config.maxShotDistance)
        let power = (clamped / max(config.maxShotDistance, 1)) * maxPower
        let length = hypot(shotVector.dx, shotVector.dy)
        let unit = length > 0 ? CGVector(dx: shotVector.dx / length, dy: shotVector.dy / length) : .zero
        let impulse = CGVector(dx: unit.dx * power, dy: unit.dy * power)

        body.applyImpulse(impulse)
        canShoot = false
        restCheckTimer = 0
    }

    private func updateAimLine(to current: CGPoint) {
        guard let ball = ball, let aimLine = aimLine, let scene = scene else { return }
        
        // Convert scene point to aimLine's local coordinate space
        let localCurrent = scene.convert(current, to: aimLine)
        
        // Vector from origin (ball) to finger in local space
        let dx = localCurrent.x
        let dy = localCurrent.y
        let distance = min(hypot(dx, dy), config.maxShotDistance)
        
        // We want to shoot opposite to where we're pulling
        let angle = atan2(-dy, -dx)

        // Draw a line with an arrow head to show direction and power
        let path = CGMutablePath()
        let startPoint = CGPoint.zero  // Start at origin (which is the ball position)
        let endPoint = CGPoint(x: cos(angle) * distance,
                               y: sin(angle) * distance)
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        // Arrow head
        let ah = config.arrowHeadLength
        let left = CGPoint(x: endPoint.x + cos(angle + .pi - config.arrowHeadAngle) * ah,
                           y: endPoint.y + sin(angle + .pi - config.arrowHeadAngle) * ah)
        let right = CGPoint(x: endPoint.x + cos(angle + .pi + config.arrowHeadAngle) * ah,
                            y: endPoint.y + sin(angle + .pi + config.arrowHeadAngle) * ah)
        path.move(to: endPoint)
        path.addLine(to: left)
        path.move(to: endPoint)
        path.addLine(to: right)

        aimLine.path = path
        aimLine.alpha = 0.5 + 0.5 * (distance / max(config.maxShotDistance, 1))
    }

    // MARK: - Update loop
    func update(deltaTime: TimeInterval) {
        guard let body = ball?.physicsBody else { return }
        if !canShoot {
            restCheckTimer += deltaTime
            // When the ball has been slow for a short period, allow next shot
            let linearSpeed = hypot(body.velocity.dx, body.velocity.dy)
            let angularSpeed = abs(body.angularVelocity)
            if linearSpeed < config.ballRestLinearSpeedThreshold && angularSpeed < config.ballRestAngularSpeedThreshold {
                if restCheckTimer >= config.ballRestCheckDuration {
                    canShoot = true
                    restCheckTimer = 0
                }
            } else {
                restCheckTimer = 0
            }
        }
    }
}
