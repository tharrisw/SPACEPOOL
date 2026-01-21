//
//  LevelGenerator.swift
//  SpacePool
//
//  Created by AI on 1/17/26.
//

import SpriteKit

/// Describes the content of a level
struct LevelSpec {
    let levelNumber: Int
    let eightBalls: Int
    let obstacles: Int
    let gimmick: Gimmick
}

/// Simple level gimmicks that tweak physics/behavior
enum Gimmick {
    case none
    case lowFriction      // balls roll longer
    case highBounce       // balls bounce more
    case slipperyFelt     // very low friction and damping
}

/// Generates level specifications based on level number and scaling rules
final class LevelGenerator {
    func spec(for level: Int) -> LevelSpec {
        let levelNumber = max(1, level)
        
        // Force Level 1 to be a simple single 8-ball with no obstacles or gimmicks
        if levelNumber == 1 {
            return LevelSpec(levelNumber: 1, eightBalls: 1, obstacles: 0, gimmick: .none)
        }

        // Determine difficulty tier
        let tier = levelNumber / 5 // every 5 levels increase base counts
        let baseEightBalls = min(6, 1 + tier) // cap at 6 eight-balls
        let baseObstacles = min(10, tier)     // up to 10 obstacles over time

        // Add some variation
        let extraBall = (levelNumber % 3 == 0) ? 1 : 0
        let extraObstacle = (levelNumber % 2 == 0) ? 1 : 0

        let eightBalls = max(1, baseEightBalls + extraBall)
        let obstacles = max(0, baseObstacles + extraObstacle)

        // Determine gimmick odds: start low and increase slightly
        let gimmickOdds: Double = min(0.35, 0.05 + Double(levelNumber) * 0.01) // up to 35%
        let roll = Double.random(in: 0...1)
        let gimmick: Gimmick
        if roll < gimmickOdds {
            // Choose a gimmick
            let options: [Gimmick] = [.lowFriction, .highBounce, .slipperyFelt]
            gimmick = options.randomElement() ?? .none
        } else {
            gimmick = .none
        }

        return LevelSpec(levelNumber: levelNumber, eightBalls: eightBalls, obstacles: obstacles, gimmick: gimmick)
    }
}

