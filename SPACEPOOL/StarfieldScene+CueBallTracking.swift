import Foundation
import SpriteKit

extension StarfieldScene {
    /// Add a cue ball to internal tracking and sync with current aiming state.
    @objc func addCueBall(_ ball: BlockBall) {
        // Add to tracking array if not already present
        if !blockCueBalls.contains(where: { $0 === ball }) {
            blockCueBalls.append(ball)
            
            // If global aiming is currently active, sync the new ball with the current aim state
            if isGlobalAiming {
                ball.beginGlobalAim()
                let dx = globalCurrentLocation.x - globalDragStart.x
                let dy = globalCurrentLocation.y - globalDragStart.y
                let distance = hypot(dx, dy)
                if distance >= globalAimStartThreshold {
                    let dir = CGVector(dx: dx, dy: dy)
                    ball.updateGlobalAim(direction: dir, magnitude: distance)
                }
            }
            
            #if DEBUG
            print("✅ Added cue ball to tracking (total: \(blockCueBalls.count))")
            #endif
        }
    }

    /// Remove a cue ball from internal tracking.
    @objc func removeCueBall(_ ball: BlockBall) {
        if let index = blockCueBalls.firstIndex(where: { $0 === ball }) {
            blockCueBalls.remove(at: index)
            #if DEBUG
            print("🗑 Removed cue ball from tracking (total: \(blockCueBalls.count))")
            #endif
        }
    }

    /// Returns all cue balls currently in the scene by discovery.
    /// This avoids relying on stored properties and stays robust for newly spawned balls.
    func allCueBalls() -> [BlockBall] {
        return self.children.compactMap { $0 as? BlockBall }.filter { $0.ballKind == .cue }
    }
    
    /// Update hat visibility on all cue balls based on current setting
    func updateHatsOnAllCueBalls() {
        let cueBalls = allCueBalls()
        let hatsEnabled = BallAccessoryManager.shared.areHatsEnabled()
        
        for ball in cueBalls {
            if hatsEnabled {
                // Add hat if not already present
                if !BallAccessoryManager.shared.hasAnyHat(ball: ball) {
                    _ = BallAccessoryManager.shared.attachRandomHat(to: ball)
                }
            } else {
                // Remove hat if present
                if BallAccessoryManager.shared.hasAnyHat(ball: ball) {
                    BallAccessoryManager.shared.removeAllHats(from: ball)
                }
            }
        }
        
        #if DEBUG
        print("🎩 Updated hats on \(cueBalls.count) cue balls (hats \(hatsEnabled ? "enabled" : "disabled"))")
        #endif
    }
}

