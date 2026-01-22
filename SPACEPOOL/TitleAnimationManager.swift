//
//  TitleAnimationManager.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Manages the title animation sequence and skip functionality
@MainActor
final class TitleAnimationManager {
    // MARK: - Properties
    private let logoBlocks: [SKSpriteNode]
    private var hasCompleted = false
    private var onComplete: (() -> Void)?

    // MARK: - Initialization
    init(logoBlocks: [SKSpriteNode]) {
        self.logoBlocks = logoBlocks
    }

    // MARK: - Public API

    /// Start the title animation sequence
    /// - Parameter onComplete: Closure to call when animation completes
    func startAnimation(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        // Wait 1 second to show starfield
        let initialWait = SKAction.wait(forDuration: 1.0)

        // Fade in over 3 seconds
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 3.0)
        
        // Wait at full opacity for a moment
        let holdWait = SKAction.wait(forDuration: 1.0)
        
        // Fade out before completing
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.5)
        
        // Call completion after fade-out finishes
        let complete = SKAction.run { [weak self] in
            self?.complete()
        }

        let sequence = SKAction.sequence([initialWait, fadeIn, holdWait, fadeOut, complete])

        // Run the animation on all logo blocks simultaneously
        // Only need to run completion on one block to avoid multiple calls
        if let firstBlock = logoBlocks.first {
            firstBlock.run(sequence)
            // Run fade sequence only on remaining blocks (without completion)
            let fadeSequence = SKAction.sequence([initialWait, fadeIn, holdWait, fadeOut])
            logoBlocks.dropFirst().forEach { $0.run(fadeSequence) }
        }
    }

    /// Skip the title animation and fade out gracefully before going to the game
    func skipAnimation() {
        guard !hasCompleted else { return }
        
        // Remove any pending actions
        logoBlocks.forEach { $0.removeAllActions() }
        
        // If logo is already visible, fade it out before completing
        if let firstBlock = logoBlocks.first, firstBlock.alpha > 0.1 {
            // Fade out gracefully
            let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.5)
            let completeAction = SKAction.run { [weak self] in
                self?.complete()
            }
            let sequence = SKAction.sequence([fadeOut, completeAction])
            
            // Run fade-out on all blocks, but only call completion on first
            firstBlock.run(sequence)
            logoBlocks.dropFirst().forEach { $0.run(fadeOut) }
        } else {
            // Logo not visible yet, just hide immediately and complete
            logoBlocks.forEach { $0.alpha = 0 }
            complete()
        }
    }

    // MARK: - Private Methods

    private func complete() {
        // Ensure we only complete once
        guard !hasCompleted else { return }
        hasCompleted = true

        // Capture and clear to avoid potential retain cycles
        let completion = onComplete
        onComplete = nil
        completion?()
    }
}
