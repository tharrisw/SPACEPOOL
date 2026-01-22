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
        tableConfig = tableConfig ?? TableConfiguration(randomSchemeIndex: selectedColorSchemeIndex)
        
        // Pause physics during rebuild to prevent race conditions
        let wasRunning = physicsWorld.speed > 0
        physicsWorld.speed = 0
        
        // Disconnect old FeltManager to prevent memory leaks and stale references
        damageSystem?.feltManager = nil
        
        // Teardown existing table content efficiently using tracked arrays
        // Remove tracked pool table nodes
        for node in poolTableNodes {
            node.removeFromParent()
        }
        poolTableNodes.removeAll()
        
        // Remove tracked physics nodes
        for node in blockTablePhysicsNodes {
            node.removeFromParent()
        }
        blockTablePhysicsNodes.removeAll()
        
        // Remove all BlockBall instances (both tracked and any strays)
        for ball in blockCueBalls {
            ball.removeFromParent()
        }
        blockCueBalls.removeAll()
        
        // Final cleanup: remove any remaining BlockTable container or stray balls
        self.childNode(withName: "BlockTable")?.removeFromParent()
        enumerateChildNodes(withName: "//*") { node, _ in
            if node is BlockBall {
                node.removeFromParent()
            }
        }
        
        // Build the new table
        let builder = BlockTableBuilder()
        let result = builder.buildTable(
            sceneSize: size,
            centerPoint: centerPoint,
            feltColor: tableConfig.feltColor,
            railColor: tableConfig.frameColor
        )
        
        // Add container to scene
        addChild(result.container)
        
        // Store references
        self.poolTableNodes = result.allNodes
        self.blockTablePhysicsNodes = result.physicsNodes
        self.blockFeltRect = result.feltRect
        self.blockPocketCenters = result.pocketCenters
        self.blockPocketRadius = result.pocketRadius
        self.feltManager = result.feltManager  // CRITICAL: Store strong reference
        self.tableGrid = result.tableGrid      // NEW: Store unified grid system
        
        // 🔥 CRITICAL FIX: Connect FeltManager to damage system for 11-ball explosions
        damageSystem?.feltManager = result.feltManager
        print("🔗 FeltManager connected to damage system for explosive holes!")
        print("🎯 TableGrid connected to scene for O(1) spatial queries!")
        
        // Resume physics if it was running
        if wasRunning {
            physicsWorld.speed = 1.0
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

