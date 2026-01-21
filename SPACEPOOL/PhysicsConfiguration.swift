//
//  PhysicsConfiguration.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import Foundation
import CoreGraphics

/// Holds all physics-related configuration for BlockBall gameplay
struct PhysicsConfiguration {
    // MARK: - BlockBall Physics Properties
    var ballMass: CGFloat = 0.17
    var ballFriction: CGFloat = 0.12
    var ballLinearDamping: CGFloat = 0.65
    var ballAngularDamping: CGFloat = 0.50
    var ballRestitution: CGFloat = 0.85
    
    // MARK: - Shooting Properties
    var maxShotDistance: CGFloat = 250
    var maxImpulse: CGFloat = 150
    
    // MARK: - Rest/Stop Detection
    var restLinearSpeedThreshold: CGFloat = 5
    var restAngularSpeedThreshold: CGFloat = 0.5
    var stopSpeedThreshold: CGFloat = 12.0
    var stopAngularThreshold: CGFloat = 0.8
    
    // MARK: - Pocket/Sinking Properties
    var supportSampleRays: Int = 12
    var supportSampleDepth: CGFloat = 1.5
    var minUnsupportedAtZeroSpeed: CGFloat = 0.45
    var maxUnsupportedAtHighSpeed: CGFloat = 0.95
    var lowSpeedThreshold: CGFloat = 40.0
    var highSpeedThreshold: CGFloat = 500.0
    var minTimeOverPocket: TimeInterval = 0.1
    var maxTimeOverPocket: TimeInterval = 3.0
    
    // MARK: - Default Instance
    static let `default` = PhysicsConfiguration()
}
