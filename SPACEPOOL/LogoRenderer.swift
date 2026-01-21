//  LogoRenderer.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Renders the "SPACEPOOL" logo using pixel art blocks
class LogoRenderer {
    // MARK: - Properties
    private weak var scene: SKScene?
    private var logoBlocks: [SKSpriteNode] = []
    
    // MARK: - Letter Patterns
    // Each letter is designed in a 5x7 grid with italic slant
    private let letterS: [[Int]] = [
        [0,0,1,1,1],
        [0,1,0,0,1],
        [0,1,0,0,0],
        [0,0,1,1,0],
        [0,0,0,1,0],
        [1,0,0,1,0],
        [0,1,1,0,0]
    ]
    
    private let letterP: [[Int]] = [
        [0,1,1,1,0],
        [0,1,0,0,1],
        [0,1,0,0,1],
        [0,1,1,1,0],
        [0,1,0,0,0],
        [1,0,0,0,0],
        [1,0,0,0,0]
    ]
    
    private let letterA: [[Int]] = [
        [0,0,1,0,0],
        [0,1,0,1,0],
        [0,1,0,1,0],
        [0,1,1,1,0],
        [0,1,0,1,0],
        [1,0,0,0,1],
        [1,0,0,0,1]
    ]
    
    private let letterC: [[Int]] = [
        [0,0,1,1,0],
        [0,1,0,0,1],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [1,0,0,0,1],
        [0,1,1,1,0]
    ]
    
    private let letterE: [[Int]] = [
        [0,1,1,1,1],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [0,1,1,1,0],
        [0,1,0,0,0],
        [1,0,0,0,0],
        [1,1,1,1,1]
    ]
    
    private let letterO: [[Int]] = [
        [0,0,1,1,0],
        [0,1,0,0,1],
        [0,1,0,0,1],
        [0,1,0,0,1],
        [0,1,0,0,1],
        [1,0,0,0,1],
        [0,1,1,1,0]
    ]
    
    private let letterL: [[Int]] = [
        [0,1,0,0,0],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [0,1,0,0,0],
        [1,0,0,0,0],
        [1,1,1,1,1]
    ]
    
    // MARK: - Initialization
    init(scene: SKScene) {
        self.scene = scene
    }
    
    // MARK: - Public Methods
    
    /// Renders the SPACEPOOL logo at the given position with the specified color
    /// - Parameters:
    ///   - centerPoint: The center point of the scene
    ///   - color: The color to use for the logo blocks
    ///   - yOffset: Vertical offset from center (default: 100)
    /// - Returns: Array of sprite nodes that make up the logo
    @discardableResult
    func renderLogo(centerPoint: CGPoint, color: SKColor, yOffset: CGFloat = 100) -> [SKSpriteNode] {
        guard let scene = scene else { return [] }
        
        let blockSize: CGFloat = 10
        let letterSpacing: CGFloat = blockSize * 0.5
        
        // Array of letters for "SPACEPOOL"
        let letters = [letterS, letterP, letterA, letterC, letterE, letterP, letterO, letterO, letterL]
        
        // Calculate total width
        let letterWidth = 5 * blockSize
        let totalLetters = letters.count
        let totalSpacing = letterSpacing * CGFloat(totalLetters - 1)
        let totalWidth = CGFloat(totalLetters) * letterWidth + totalSpacing
        
        // Start position
        let startX = centerPoint.x - (totalWidth / 2)
        let startY = centerPoint.y + yOffset
        
        var currentX = startX
        var blocks: [SKSpriteNode] = []
        
        // Draw each letter with italic offset
        for letter in letters {
            for (row, rowData) in letter.enumerated() {
                // Create italic slant by offsetting each row
                let italicOffset = CGFloat(7 - row) * 1.5
                
                for (col, value) in rowData.enumerated() {
                    if value == 1 {
                        let block = SKSpriteNode(color: color, size: CGSize(width: blockSize, height: blockSize))
                        
                        // Calculate position with italic offset
                        let x = currentX + CGFloat(col) * blockSize + italicOffset
                        let y = startY - CGFloat(row) * blockSize
                        
                        block.position = CGPoint(x: x, y: y)
                        block.zPosition = 60
                        block.texture?.filteringMode = .nearest
                        
                        scene.addChild(block)
                        blocks.append(block)
                    }
                }
            }
            
            // Move to next letter position
            currentX += letterWidth + letterSpacing
        }
        
        logoBlocks = blocks
        return blocks
    }
    
    /// Hide all logo blocks
    func hideLogo() {
        for block in logoBlocks {
            block.alpha = 0
        }
    }
    
    /// Show all logo blocks
    func showLogo() {
        for block in logoBlocks {
            block.alpha = 1
        }
    }
    
    /// Update the color of all logo blocks
    func updateColor(_ color: SKColor) {
        for block in logoBlocks {
            block.color = color
        }
    }
    
    /// Get all logo blocks
    var blocks: [SKSpriteNode] {
        return logoBlocks
    }
}

