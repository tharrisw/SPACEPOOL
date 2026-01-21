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
        
        // Call completion after fade-in finishes
        let complete = SKAction.run { [weak self] in
            self?.complete()
        }

        let sequence = SKAction.sequence([initialWait, fadeIn, complete])

        // Run the animation on all logo blocks simultaneously
        // Only need to run completion on one block to avoid multiple calls
        if let firstBlock = logoBlocks.first {
            firstBlock.run(sequence)
            // Run fade-in only on remaining blocks
            let fadeSequence = SKAction.sequence([initialWait, fadeIn])
            logoBlocks.dropFirst().forEach { $0.run(fadeSequence) }
        }
    }

    /// Skip the title animation and go directly to the game
    func skipAnimation() {
        guard !hasCompleted else { return }
        
        // Remove any pending actions and hide immediately
        logoBlocks.forEach { block in
            block.removeAllActions()
            block.alpha = 0
        }

        complete()
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
