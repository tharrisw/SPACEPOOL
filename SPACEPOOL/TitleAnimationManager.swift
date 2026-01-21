//
//  TitleAnimationManager.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Manages the title animation sequence and skip functionality
class TitleAnimationManager {
    // MARK: - Properties
    private var logoBlocks: [SKSpriteNode]
    private var titleAnimationComplete = false
    private var titleFadingOut = false
    private var onComplete: (() -> Void)?
    
    // MARK: - Initialization
    init(logoBlocks: [SKSpriteNode]) {
        self.logoBlocks = logoBlocks
    }
    
    // MARK: - Public Methods
    
    /// Start the title animation sequence
    /// - Parameter onComplete: Closure to call when animation completes
    func startAnimation(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        
        // Wait 1 second to show starfield
        let initialWait = SKAction.wait(forDuration: 1.0)
        
        // Fade in over 3 seconds
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 3.0)
        
        // Hold indefinitely (no fade out - stays until tapped)
        let sequence = SKAction.sequence([initialWait, fadeIn])
        
        // Run the animation on all logo blocks simultaneously
        for block in logoBlocks {
            block.run(sequence)
        }
    }
    
    /// Skip the title animation and go directly to the game
    func skipAnimation() {
        guard !titleAnimationComplete else { return }
        skipToEnd()
    }
    
    /// Check if animation is complete
    var isComplete: Bool {
        return titleAnimationComplete
    }
    
    // MARK: - Private Methods
    
    private func skipToEnd() {
        // Remove any pending actions
        for block in logoBlocks {
            block.removeAllActions()
            block.alpha = 0
        }
        
        // Mark as complete and call completion handler
        completeAnimation()
    }
    
    private func completeAnimation() {
        titleAnimationComplete = true
        titleFadingOut = false
        onComplete?()
    }
}
