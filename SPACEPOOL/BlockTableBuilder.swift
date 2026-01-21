//
//  BlockTableBuilder.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Result of building a block table
struct BlockTableResult {
    let container: SKNode
    let allNodes: [SKNode]
    let physicsNodes: [SKNode]
    let feltRect: CGRect
    let pocketCenters: [CGPoint]
    let pocketRadius: CGFloat
    let feltManager: FeltManager  // NEW: Manages dynamic felt state
}

/// Manages the dynamic felt state - swaps between texture and individual blocks
class FeltManager {
    // MARK: - Properties
    private let blockSize: CGFloat = 5.0
    private let feltRect: CGRect
    private let feltColor: SKColor
    private let pocketCenters: [CGPoint]
    private let pocketRadius: CGFloat
    private weak var container: SKNode?
    
    // Track which felt blocks exist (true = exists, false = destroyed)
    private var feltGrid: [[Bool]]
    private let gridCols: Int
    private let gridRows: Int
    
    // Current rendering mode
    private var isTextureMode: Bool = true  // Use optimized texture mode by default
    private var feltTextureSprite: SKSpriteNode?
    private var individualBlocks: [SKSpriteNode] = []
    
    init(feltRect: CGRect, feltColor: SKColor, pocketCenters: [CGPoint], pocketRadius: CGFloat, container: SKNode) {
        self.feltRect = feltRect
        self.feltColor = feltColor
        self.pocketCenters = pocketCenters
        self.pocketRadius = pocketRadius
        self.container = container
        
        // Calculate grid dimensions
        self.gridCols = Int(feltRect.width / blockSize)
        self.gridRows = Int(feltRect.height / blockSize)
        
        // Initialize grid - all blocks exist initially
        self.feltGrid = Array(repeating: Array(repeating: true, count: gridCols), count: gridRows)
        
        // Mark pocket areas as already destroyed
        markPocketAreas()
    }
    
    private func markPocketAreas() {
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                let px = feltRect.minX + CGFloat(col) * blockSize + blockSize / 2
                let py = feltRect.minY + CGFloat(row) * blockSize + blockSize / 2
                
                if isPocket(x: px, y: py) {
                    feltGrid[row][col] = false
                }
            }
        }
    }
    
    private func isPocket(x: CGFloat, y: CGFloat) -> Bool {
        let p = CGPoint(x: x, y: y)
        for c in pocketCenters {
            if hypot(p.x - c.x, p.y - c.y) <= pocketRadius {
                return true
            }
        }
        return false
    }
    
    // MARK: - Texture Mode (99% of time)
    
    func createInitialTexture() {
        guard let container = container else { return }
        
        // Create optimized texture sprite for felt
        let texture = bakeFeltTexture()
        let sprite = SKSpriteNode(texture: texture)
        sprite.position = CGPoint(x: feltRect.midX, y: feltRect.midY)
        sprite.zPosition = 21
        sprite.texture?.filteringMode = .nearest
        sprite.name = "FeltTexture"
        
        container.addChild(sprite)
        feltTextureSprite = sprite
        isTextureMode = true
        
        print("✅ Created optimized felt texture (single sprite)")
    }
    
    private func bakeFeltTexture() -> SKTexture {
        let size = CGSize(width: feltRect.width, height: feltRect.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(feltColor.cgColor)
            
            for row in 0..<gridRows {
                for col in 0..<gridCols {
                    if !feltGrid[row][col] { continue }  // Skip destroyed blocks
                    
                    let rect = CGRect(
                        x: CGFloat(col) * blockSize,
                        y: CGFloat(row) * blockSize,
                        width: blockSize,
                        height: blockSize
                    )
                    ctx.fill(rect)
                }
            }
        }
        
        return SKTexture(image: image)
    }
    
    // MARK: - Block Mode (during explosions)
    
    func switchToBlockMode(aroundPosition position: CGPoint, radius: CGFloat) {
        // Already in block mode, no need to switch
        if !isTextureMode {
            return
        }
        
        guard let container = container else { return }
        
        // Remove texture sprite
        feltTextureSprite?.removeFromParent()
        feltTextureSprite = nil
        
        // Create ALL felt blocks (not just in explosion radius)
        // This ensures the entire felt is visible after switching from texture
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                if !feltGrid[row][col] { continue }  // Skip destroyed blocks (pockets)
                
                let px = feltRect.minX + CGFloat(col) * blockSize + blockSize / 2
                let py = feltRect.minY + CGFloat(row) * blockSize + blockSize / 2
                
                let block = SKSpriteNode(color: feltColor, size: CGSize(width: blockSize, height: blockSize))
                block.position = CGPoint(x: px, y: py)
                block.zPosition = 21
                block.texture?.filteringMode = .nearest
                block.name = "FeltBlock_\(row)_\(col)"
                
                container.addChild(block)
                individualBlocks.append(block)
            }
        }
        
        isTextureMode = false
        print("🔄 Switched to block mode: created \(individualBlocks.count) felt blocks")
    }
    
    func destroyBlocksInRadius(position: CGPoint, radius: CGFloat) -> [SKSpriteNode] {
        var destroyedBlocks: [SKSpriteNode] = []
        
        // Find and destroy blocks in radius
        for block in individualBlocks {
            let dx = block.position.x - position.x
            let dy = block.position.y - position.y
            let distance = hypot(dx, dy)
            
            if distance <= radius {
                // Update grid state
                let col = Int((block.position.x - feltRect.minX) / blockSize)
                let row = Int((block.position.y - feltRect.minY) / blockSize)
                
                if row >= 0 && row < gridRows && col >= 0 && col < gridCols {
                    feltGrid[row][col] = false
                }
                
                destroyedBlocks.append(block)
            }
        }
        
        // Remove from tracking
        individualBlocks.removeAll { block in
            destroyedBlocks.contains { $0 === block }
        }
        
        return destroyedBlocks
    }
    
    /// Remove a single felt block from the scene and update internal state
    func removeBlock(_ block: SKSpriteNode) {
        // Update grid state
        let col = Int((block.position.x - feltRect.minX) / blockSize)
        let row = Int((block.position.y - feltRect.minY) / blockSize)
        if row >= 0 && row < gridRows && col >= 0 && col < gridCols {
            feltGrid[row][col] = false
        }
        
        // Remove from tracking list
        individualBlocks.removeAll { $0 === block }
        
        // Remove from scene
        block.removeFromParent()
    }
    
    func switchBackToTextureMode() {
        guard !isTextureMode, let container = container else { return }
        
        // Remove all individual blocks
        for block in individualBlocks {
            block.removeFromParent()
        }
        individualBlocks.removeAll()
        
        // Bake new texture with holes
        let texture = bakeFeltTexture()
        let sprite = SKSpriteNode(texture: texture)
        sprite.position = CGPoint(x: feltRect.midX, y: feltRect.midY)
        sprite.zPosition = 21
        sprite.texture?.filteringMode = .nearest
        sprite.name = "FeltTexture"
        
        container.addChild(sprite)
        feltTextureSprite = sprite
        isTextureMode = true
        
        print("🔄 Switched back to texture mode with updated holes")
    }
    
    // MARK: - Pocket Detection (Geometric)
    
    func getBlocksInExplosionRadius(position: CGPoint, radius: CGFloat, scene: SKScene) -> [SKSpriteNode] {
        // If in texture mode, need to switch to block mode first
        if isTextureMode {
            switchToBlockMode(aroundPosition: position, radius: radius)
        }
        
        // Now we have individual blocks to work with
        let blocksInRadius = individualBlocks.filter { block in
            let dx = block.position.x - position.x
            let dy = block.position.y - position.y
            return hypot(dx, dy) <= radius
        }
        
        return blocksInRadius
    }
}

/// Builds a pool table out of 5x5 pixel blocks
class BlockTableBuilder {
    // MARK: - Properties
    private let blockSize: CGFloat = 5.0
    
    // MARK: - Public Methods
    
    /// Build a block table with the given configuration
    /// - Parameters:
    ///   - sceneSize: The size of the scene
    ///   - centerPoint: The center point where the table should be positioned
    ///   - feltColor: Color for the felt (play area)
    ///   - railColor: Color for the rails (bumpers)
    /// - Returns: BlockTableResult containing all generated nodes and geometry info
    func buildTable(
        sceneSize: CGSize,
        centerPoint: CGPoint,
        feltColor: SKColor,
        railColor: SKColor
    ) -> BlockTableResult {
        
        // Calculate table dimensions
        let limitingSide = min(sceneSize.height, sceneSize.width / 1.7)
        let screenSizeToUse = limitingSide * 0.95
        let tableWidth: CGFloat = screenSizeToUse * 1.7
        let tableHeight: CGFloat = screenSizeToUse
        let railThickness: CGFloat = tableHeight * 0.14
        let cornerRadius: CGFloat = railThickness
        
        // Compute grid counts
        let cols = Int(round(tableWidth / blockSize))
        let rows = Int(round(tableHeight / blockSize))
        
        // Align table and rail dimensions to the 5x5 block grid
        let alignedTableWidth = CGFloat(cols) * blockSize
        let alignedTableHeight = CGFloat(rows) * blockSize
        let railThicknessBlocks = Int(round(railThickness / blockSize))
        let alignedRailThickness = CGFloat(railThicknessBlocks) * blockSize
        
        // Center table at scene center
        let originX = centerPoint.x - CGFloat(cols) * blockSize / 2
        let originY = centerPoint.y - CGFloat(rows) * blockSize / 2
        
        // Felt rect inside rails
        let feltWidth = alignedTableWidth - 2 * alignedRailThickness
        let feltHeight = alignedTableHeight - 2 * alignedRailThickness
        let feltCols = Int(round(feltWidth / blockSize))
        let feltRows = Int(round(feltHeight / blockSize))
        
        // Pocket dimensions/positions
        let holeRadius: CGFloat = tableHeight * 0.057
        let sidePocketInset: CGFloat = holeRadius * 0.45
        
        // Compute pocket centers in scene coordinates
        let tableCenter = CGPoint(
            x: originX + alignedTableWidth / 2,
            y: originY + alignedTableHeight / 2
        )
        let halfFeltW = CGFloat(feltCols) * blockSize / 2
        let halfFeltH = CGFloat(feltRows) * blockSize / 2
        
        let cornerPocketCenters: [CGPoint] = [
            CGPoint(x: tableCenter.x - halfFeltW, y: tableCenter.y + halfFeltH),
            CGPoint(x: tableCenter.x + halfFeltW, y: tableCenter.y + halfFeltH),
            CGPoint(x: tableCenter.x - halfFeltW, y: tableCenter.y - halfFeltH),
            CGPoint(x: tableCenter.x + halfFeltW, y: tableCenter.y - halfFeltH)
        ]
        
        let sidePocketCenters: [CGPoint] = [
            CGPoint(x: tableCenter.x, y: tableCenter.y + halfFeltH + sidePocketInset),
            CGPoint(x: tableCenter.x, y: tableCenter.y - halfFeltH - sidePocketInset)
        ]
        
        let allPocketCenters = cornerPocketCenters + sidePocketCenters
        
        // Helper: test if a point is inside the outer rounded-rectangle table shape
        func isInsideRoundedRect(x: CGFloat, y: CGFloat) -> Bool {
            let halfW = alignedTableWidth / 2
            let halfH = alignedTableHeight / 2
            let r = max(0, min(cornerRadius, min(halfW, halfH)))
            let dx = abs(x - tableCenter.x)
            let dy = abs(y - tableCenter.y)
            
            if dx > halfW || dy > halfH { return false }
            if dx <= halfW - r || dy <= halfH - r { return true }
            
            let cx = halfW - r
            let cy = halfH - r
            let lx = dx - cx
            let ly = dy - cy
            return (lx * lx + ly * ly) <= r * r
        }
        
        // Helper: test if a position is inside any pocket radius
        func isPocket(x: CGFloat, y: CGFloat) -> Bool {
            let p = CGPoint(x: x, y: y)
            for c in allPocketCenters {
                if hypot(p.x - c.x, p.y - c.y) <= holeRadius { return true }
            }
            return false
        }
        
        // Container for block table
        let container = SKNode()
        container.name = "BlockTable"
        container.zPosition = 20
        
        var allNodes: [SKNode] = [container]
        var physicsNodes: [SKNode] = []
        
        // Calculate felt rectangle first
        let feltRect = CGRect(
            x: tableCenter.x - feltWidth/2,
            y: tableCenter.y - feltHeight/2,
            width: feltWidth,
            height: feltHeight
        )
        
        // ✅ MEGA OPTIMIZATION: Use FeltManager for dynamic felt rendering
        let feltManager = FeltManager(
            feltRect: feltRect,
            feltColor: feltColor,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            container: container
        )
        
        // Create initial felt texture (single sprite instead of 5800+ blocks!)
        feltManager.createInitialTexture()
        
        // OPTIMIZATION: Render rails as single texture
        let railTexture = createRailTexture(
            tableWidth: alignedTableWidth,
            tableHeight: alignedTableHeight,
            feltWidth: feltWidth,
            feltHeight: feltHeight,
            railColor: railColor,
            cornerRadius: cornerRadius,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            blockSize: blockSize,
            tableCenter: tableCenter,
            rows: rows,
            cols: cols,
            originX: originX,
            originY: originY
        )
        
        // Create a single sprite for all rails
        let railSprite = SKSpriteNode(texture: railTexture)
        railSprite.position = tableCenter
        railSprite.zPosition = 22
        railSprite.texture?.filteringMode = .nearest
        container.addChild(railSprite)
        allNodes.append(railSprite)
        
        // Felt is now managed by FeltManager (already created above)
        // No individual blocks needed here!
        
        // ✅ PERFORMANCE OPTIMIZATION: Single edge loop physics for all rails
        // Instead of 3664+ individual physics bodies, use ONE edge loop barrier
        createRailPhysicsBarrier(
            container: container,
            feltRect: feltRect,
            railThickness: alignedRailThickness,
            cornerRadius: cornerRadius,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            physicsNodes: &physicsNodes
        )
        
        print("🧱 Block Table drawn with \(allNodes.count) nodes")
        print("⚡ Rail physics: \(physicsNodes.count) barrier segments (was 3664+ individual blocks)")
        print("🎨 Rails: 1 texture sprite (was ~3600 individual sprites)")
        print("✅ Felt: 1 optimized texture sprite (was ~5800 individual blocks)")
        print("📊 TOTAL: ~\(allNodes.count) nodes (\(physicsNodes.count) physics)")
        print("   feltRect: \(feltRect) holeRadius: \(holeRadius)")
        
        return BlockTableResult(
            container: container,
            allNodes: allNodes,
            physicsNodes: physicsNodes,
            feltRect: feltRect,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            feltManager: feltManager
        )
    }
    
    // MARK: - Edge Loop Physics Barrier
    
    /// Creates a single edge-based physics barrier around the felt area
    /// This replaces thousands of individual rail block physics bodies with ONE efficient barrier
    private func createRailPhysicsBarrier(
        container: SKNode,
        feltRect: CGRect,
        railThickness: CGFloat,
        cornerRadius: CGFloat,
        pocketCenters: [CGPoint],
        pocketRadius: CGFloat,
        physicsNodes: inout [SKNode]
    ) {
        // Create an invisible node to hold the physics body
        let barrierNode = SKNode()
        barrierNode.name = "RailPhysicsBarrier"
        barrierNode.position = .zero
        barrierNode.zPosition = 22
        
        // IMPROVED: Create THICK rectangular barriers for each wall section
        // This prevents balls from slipping through
        
        let minX = feltRect.minX
        let maxX = feltRect.maxX
        let minY = feltRect.minY
        let maxY = feltRect.maxY
        
        let pocketGap = pocketRadius * 2.2  // Slightly larger opening for smooth pocket entry
        
        // Get pocket positions
        let topPockets = pocketCenters.filter { $0.y > feltRect.midY }.sorted { $0.x < $1.x }
        let bottomPockets = pocketCenters.filter { $0.y < feltRect.midY }.sorted { $0.x < $1.x }
        let leftPockets = pocketCenters.filter { $0.x < feltRect.midX }.sorted { $0.y > $1.y }
        let rightPockets = pocketCenters.filter { $0.x > feltRect.midX }.sorted { $0.y > $1.y }
        
        // Create thick rectangular barriers for each rail section
        var barriers: [SKNode] = []
        
        // TOP WALL SEGMENTS (outward = up)
        var currentX = minX
        for pocket in topPockets {
            let gapStart = pocket.x - pocketGap / 2
            if currentX < gapStart {
                let segment = createBarrierSegment(
                    from: CGPoint(x: currentX, y: maxY),
                    to: CGPoint(x: gapStart, y: maxY),
                    thickness: railThickness,
                    outwardDirection: CGVector(dx: 0, dy: 1)  // Up
                )
                barriers.append(segment)
            }
            currentX = pocket.x + pocketGap / 2
        }
        if currentX < maxX {
            let segment = createBarrierSegment(
                from: CGPoint(x: currentX, y: maxY),
                to: CGPoint(x: maxX, y: maxY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: 1)  // Up
            )
            barriers.append(segment)
        }
        
        // RIGHT WALL SEGMENTS (outward = right)
        var currentY = maxY
        for pocket in rightPockets {
            let gapStart = pocket.y + pocketGap / 2
            if currentY > gapStart {
                let segment = createBarrierSegment(
                    from: CGPoint(x: maxX, y: currentY),
                    to: CGPoint(x: maxX, y: gapStart),
                    thickness: railThickness,
                    outwardDirection: CGVector(dx: 1, dy: 0)  // Right
                )
                barriers.append(segment)
            }
            currentY = pocket.y - pocketGap / 2
        }
        if currentY > minY {
            let segment = createBarrierSegment(
                from: CGPoint(x: maxX, y: currentY),
                to: CGPoint(x: maxX, y: minY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 1, dy: 0)  // Right
            )
            barriers.append(segment)
        }
        
        // BOTTOM WALL SEGMENTS (outward = down)
        currentX = maxX
        for pocket in bottomPockets.reversed() {
            let gapStart = pocket.x + pocketGap / 2
            if currentX > gapStart {
                let segment = createBarrierSegment(
                    from: CGPoint(x: currentX, y: minY),
                    to: CGPoint(x: gapStart, y: minY),
                    thickness: railThickness,
                    outwardDirection: CGVector(dx: 0, dy: -1)  // Down
                )
                barriers.append(segment)
            }
            currentX = pocket.x - pocketGap / 2
        }
        if currentX > minX {
            let segment = createBarrierSegment(
                from: CGPoint(x: currentX, y: minY),
                to: CGPoint(x: minX, y: minY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: -1)  // Down
            )
            barriers.append(segment)
        }
        
        // LEFT WALL SEGMENTS (outward = left)
        currentY = minY
        for pocket in leftPockets.reversed() {
            let gapStart = pocket.y - pocketGap / 2
            if currentY < gapStart {
                let segment = createBarrierSegment(
                    from: CGPoint(x: minX, y: currentY),
                    to: CGPoint(x: minX, y: gapStart),
                    thickness: railThickness,
                    outwardDirection: CGVector(dx: -1, dy: 0)  // Left
                )
                barriers.append(segment)
            }
            currentY = pocket.y + pocketGap / 2
        }
        if currentY < maxY {
            let segment = createBarrierSegment(
                from: CGPoint(x: minX, y: currentY),
                to: CGPoint(x: minX, y: maxY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: -1, dy: 0)  // Left
            )
            barriers.append(segment)
        }
        
        // Add all barrier segments to container
        for barrier in barriers {
            container.addChild(barrier)
            physicsNodes.append(barrier)
        }
        
        // CRITICAL FIX: Add "back wall" and "side wall" barriers around each pocket opening
        // These create a physical "pocket box" that prevents balls with flying accessory
        // from escaping through pocket gaps
        let pocketBackWallOffset: CGFloat = pocketRadius * 1.5  // How far behind the pocket to place the wall
        
        // TOP POCKETS - add horizontal back walls and vertical side walls
        for pocket in topPockets {
            let backWallY = maxY + pocketBackWallOffset
            
            // Back wall (horizontal)
            let backWall = createBarrierSegment(
                from: CGPoint(x: pocket.x - pocketGap / 2, y: backWallY),
                to: CGPoint(x: pocket.x + pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: 1)  // Up (away from felt)
            )
            container.addChild(backWall)
            physicsNodes.append(backWall)
            
            // Left side wall (vertical)
            let leftWall = createBarrierSegment(
                from: CGPoint(x: pocket.x - pocketGap / 2, y: maxY),
                to: CGPoint(x: pocket.x - pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: -1, dy: 0)  // Left
            )
            container.addChild(leftWall)
            physicsNodes.append(leftWall)
            
            // Right side wall (vertical)
            let rightWall = createBarrierSegment(
                from: CGPoint(x: pocket.x + pocketGap / 2, y: maxY),
                to: CGPoint(x: pocket.x + pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 1, dy: 0)  // Right
            )
            container.addChild(rightWall)
            physicsNodes.append(rightWall)
        }
        
        // BOTTOM POCKETS - add horizontal back walls and vertical side walls
        for pocket in bottomPockets {
            let backWallY = minY - pocketBackWallOffset
            
            // Back wall (horizontal)
            let backWall = createBarrierSegment(
                from: CGPoint(x: pocket.x - pocketGap / 2, y: backWallY),
                to: CGPoint(x: pocket.x + pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: -1)  // Down (away from felt)
            )
            container.addChild(backWall)
            physicsNodes.append(backWall)
            
            // Left side wall (vertical)
            let leftWall = createBarrierSegment(
                from: CGPoint(x: pocket.x - pocketGap / 2, y: minY),
                to: CGPoint(x: pocket.x - pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: -1, dy: 0)  // Left
            )
            container.addChild(leftWall)
            physicsNodes.append(leftWall)
            
            // Right side wall (vertical)
            let rightWall = createBarrierSegment(
                from: CGPoint(x: pocket.x + pocketGap / 2, y: minY),
                to: CGPoint(x: pocket.x + pocketGap / 2, y: backWallY),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 1, dy: 0)  // Right
            )
            container.addChild(rightWall)
            physicsNodes.append(rightWall)
        }
        
        // LEFT POCKETS - add vertical back walls and horizontal side walls
        for pocket in leftPockets {
            let backWallX = minX - pocketBackWallOffset
            
            // Back wall (vertical)
            let backWall = createBarrierSegment(
                from: CGPoint(x: backWallX, y: pocket.y - pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y + pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: -1, dy: 0)  // Left (away from felt)
            )
            container.addChild(backWall)
            physicsNodes.append(backWall)
            
            // Top side wall (horizontal)
            let topWall = createBarrierSegment(
                from: CGPoint(x: minX, y: pocket.y + pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y + pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: 1)  // Up
            )
            container.addChild(topWall)
            physicsNodes.append(topWall)
            
            // Bottom side wall (horizontal)
            let bottomWall = createBarrierSegment(
                from: CGPoint(x: minX, y: pocket.y - pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y - pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: -1)  // Down
            )
            container.addChild(bottomWall)
            physicsNodes.append(bottomWall)
        }
        
        // RIGHT POCKETS - add vertical back walls and horizontal side walls
        for pocket in rightPockets {
            let backWallX = maxX + pocketBackWallOffset
            
            // Back wall (vertical)
            let backWall = createBarrierSegment(
                from: CGPoint(x: backWallX, y: pocket.y - pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y + pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 1, dy: 0)  // Right (away from felt)
            )
            container.addChild(backWall)
            physicsNodes.append(backWall)
            
            // Top side wall (horizontal)
            let topWall = createBarrierSegment(
                from: CGPoint(x: maxX, y: pocket.y + pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y + pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: 1)  // Up
            )
            container.addChild(topWall)
            physicsNodes.append(topWall)
            
            // Bottom side wall (horizontal)
            let bottomWall = createBarrierSegment(
                from: CGPoint(x: maxX, y: pocket.y - pocketGap / 2),
                to: CGPoint(x: backWallX, y: pocket.y - pocketGap / 2),
                thickness: railThickness,
                outwardDirection: CGVector(dx: 0, dy: -1)  // Down
            )
            container.addChild(bottomWall)
            physicsNodes.append(bottomWall)
        }
    }
    
    /// Create a thick rectangular barrier segment between two points
    /// The barrier is positioned so its INNER edge is at the felt boundary
    /// - Parameters:
    ///   - start: Starting point of the barrier (at felt edge)
    ///   - end: Ending point of the barrier (at felt edge)
    ///   - thickness: Thickness of the barrier (extends outward from felt)
    ///   - outwardDirection: Unit vector pointing away from the playing area
    private func createBarrierSegment(from start: CGPoint, to end: CGPoint, thickness: CGFloat, outwardDirection: CGVector) -> SKNode {
        let node = SKNode()
        
        // Calculate segment dimensions
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let angle = atan2(dy, dx)
        
        // CRITICAL: Barrier must be thick enough to catch fast-moving balls (prevent tunneling)
        let physicsThickness: CGFloat = 20.0  // Thick enough to prevent tunneling at high speeds
        
        let size = CGSize(width: length, height: physicsThickness)
        let physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody.isDynamic = false
        physicsBody.friction = 0.08
        physicsBody.restitution = 0.85
        physicsBody.usesPreciseCollisionDetection = true  // Prevent tunneling with fast-moving balls
        physicsBody.categoryBitMask = 0x1 << 1  // Rail category
        physicsBody.collisionBitMask = 0x1 << 0  // Collides with balls
        
        // Position the barrier so its INNER edge is at the felt boundary
        // This prevents balls from getting trapped between barriers at pocket openings
        let offset = physicsThickness / 2
        
        node.position = CGPoint(
            x: (start.x + end.x) / 2 + outwardDirection.dx * offset,
            y: (start.y + end.y) / 2 + outwardDirection.dy * offset
        )
        node.zRotation = angle
        node.physicsBody = physicsBody
        
        return node
    }
    
    // MARK: - Rail Texture Generation
    
    /// Create a single texture for all rail blocks (massive performance boost)
    private func createRailTexture(
        tableWidth: CGFloat,
        tableHeight: CGFloat,
        feltWidth: CGFloat,
        feltHeight: CGFloat,
        railColor: SKColor,
        cornerRadius: CGFloat,
        pocketCenters: [CGPoint],
        pocketRadius: CGFloat,
        blockSize: CGFloat,
        tableCenter: CGPoint,
        rows: Int,
        cols: Int,
        originX: CGFloat,
        originY: CGFloat
    ) -> SKTexture {
        
        let size = CGSize(width: tableWidth, height: tableHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Helper functions
            func isInsideRoundedRect(x: CGFloat, y: CGFloat) -> Bool {
                let halfW = tableWidth / 2
                let halfH = tableHeight / 2
                let r = max(0, min(cornerRadius, min(halfW, halfH)))
                let dx = abs(x - tableWidth / 2)
                let dy = abs(y - tableHeight / 2)
                
                if dx > halfW || dy > halfH { return false }
                if dx <= halfW - r || dy <= halfH - r { return true }
                
                let cx = halfW - r
                let cy = halfH - r
                let lx = dx - cx
                let ly = dy - cy
                return (lx * lx + ly * ly) <= r * r
            }
            
            func isPocket(x: CGFloat, y: CGFloat) -> Bool {
                let p = CGPoint(x: x, y: y)
                for c in pocketCenters {
                    // Convert to texture space
                    let texX = c.x - tableCenter.x + tableWidth / 2
                    let texY = c.y - tableCenter.y + tableHeight / 2
                    let center = CGPoint(x: texX, y: texY)
                    if hypot(p.x - center.x, p.y - center.y) <= pocketRadius { return true }
                }
                return false
            }
            
            // Set rail color
            ctx.setFillColor(railColor.cgColor)
            
            // Draw rail blocks
            for r in 0..<rows {
                for c in 0..<cols {
                    let px = CGFloat(c) * blockSize + blockSize / 2
                    let py = CGFloat(r) * blockSize + blockSize / 2
                    
                    // Determine if this cell is within felt area
                    let inFeltX = abs(px - tableWidth / 2) <= feltWidth / 2
                    let inFeltY = abs(py - tableHeight / 2) <= feltHeight / 2
                    let isFelt = inFeltX && inFeltY
                    
                    // Skip if it's felt (we only render rails here)
                    if isFelt { continue }
                    
                    // Determine if within table bounds
                    let inTableX = abs(px - tableWidth / 2) <= tableWidth / 2
                    let inTableY = abs(py - tableHeight / 2) <= tableHeight / 2
                    if !inTableX || !inTableY { continue }
                    
                    if !isInsideRoundedRect(x: px, y: py) { continue }
                    if isPocket(x: px, y: py) { continue }
                    
                    // Handle corner pocket mouth widening
                    let strip = blockSize * 2
                    let halfFeltW = feltWidth / 2
                    let halfFeltH = feltHeight / 2
                    let centerX = tableWidth / 2
                    let centerY = tableHeight / 2
                    
                    let topStripLeft = CGRect(x: centerX - halfFeltW, y: centerY + halfFeltH, width: strip, height: strip)
                    let topStripRight = CGRect(x: centerX + halfFeltW - strip, y: centerY + halfFeltH, width: strip, height: strip)
                    let bottomStripLeft = CGRect(x: centerX - halfFeltW, y: centerY - halfFeltH - strip, width: strip, height: strip)
                    let bottomStripRight = CGRect(x: centerX + halfFeltW - strip, y: centerY - halfFeltH - strip, width: strip, height: strip)
                    let leftStripTop = CGRect(x: centerX - halfFeltW - strip, y: centerY + halfFeltH - strip, width: strip, height: strip)
                    let leftStripBottom = CGRect(x: centerX - halfFeltW - strip, y: centerY - halfFeltH, width: strip, height: strip)
                    let rightStripTop = CGRect(x: centerX + halfFeltW, y: centerY + halfFeltH - strip, width: strip, height: strip)
                    let rightStripBottom = CGRect(x: centerX + halfFeltW, y: centerY - halfFeltH, width: strip, height: strip)
                    
                    let p = CGPoint(x: px, y: py)
                    if topStripLeft.contains(p) || topStripRight.contains(p) ||
                       bottomStripLeft.contains(p) || bottomStripRight.contains(p) ||
                       leftStripTop.contains(p) || leftStripBottom.contains(p) ||
                       rightStripTop.contains(p) || rightStripBottom.contains(p) {
                        continue
                    }
                    
                    // Draw rail block
                    let rect = CGRect(
                        x: px - blockSize / 2,
                        y: py - blockSize / 2,
                        width: blockSize,
                        height: blockSize
                    )
                    ctx.fill(rect)
                }
            }
        }
        
        return SKTexture(image: image)
    }
}

