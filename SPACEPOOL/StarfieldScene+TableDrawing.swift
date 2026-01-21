//
//  StarfieldScene+TableDrawing.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Extension for table drawing functionality
extension StarfieldScene {
    
    // MARK: - Table Drawing
    
    /// Draw the block table and spawn initial balls
    func drawBlockTable() {
        // Fallback: ensure tableConfig is initialized
        if tableConfig == nil {
            tableConfig = TableConfiguration(randomSchemeIndex: selectedColorSchemeIndex)
        }
        
        let builder = BlockTableBuilder()
        
        // Teardown any existing Block Table content and balls before rebuilding
        self.childNode(withName: "BlockTable")?.removeFromParent()
        // Remove any existing BlockBall nodes to ensure fresh instances
        for n in self.children {
            if n is BlockBall { n.removeFromParent() }
        }
        self.blockTablePhysicsNodes.removeAll()
        self.poolTableNodes.removeAll()
        self.blockCueBalls.removeAll()  // Changed: clear the array instead of setting to nil
        
        // Build the table
        let result = builder.buildTable(
            sceneSize: size,
            centerPoint: centerPoint,
            feltColor: tableConfig.feltColor,
            railColor: tableConfig.frameColor
        )
        
        // Add container to scene
        addChild(result.container)
        
        // Ensure new table respects current suppression/visibility
        applyTableVisibilityToCurrentTable()
        
        // Store references
        self.poolTableNodes = result.allNodes
        self.blockTablePhysicsNodes = result.physicsNodes
        self.blockFeltRect = result.feltRect
        self.blockPocketCenters = result.pocketCenters
        self.blockPocketRadius = result.pocketRadius
        self.feltManager = result.feltManager  // CRITICAL: Store strong reference
        
        // 🔥 CRITICAL FIX: Connect FeltManager to damage system for 11-ball explosions
        if let damageSystem = self.damageSystem {
            damageSystem.feltManager = result.feltManager
            print("🔗 FeltManager connected to damage system for explosive holes!")
        }
        
        // Update UI colors to match table theme
        updateUIColors()
    }
    
    // MARK: - Helper Methods
    
    private func updateUIColors() {
        // Update existing labels if already created to use theme color
        self.levelHeadingLabel?.fontColor = StarfieldScene.ThemeColor1
        self.levelValueLabel?.fontColor = StarfieldScene.ThemeColor1
        self.scoreHeadingLabel?.fontColor = StarfieldScene.ThemeColor1
        self.scoreValueLabel?.fontColor = StarfieldScene.ThemeColor1
        
        // Update SpacePool logo blocks to match new theme color
        for block in self.logoBlocks {
            block.color = StarfieldScene.ThemeColor1
        }
    }
}

