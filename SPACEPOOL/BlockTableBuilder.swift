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
    let tableGrid: TableGrid      // NEW: Unified grid system for all table elements
}

/// Manages the dynamic felt rendering using the unified TableGrid system
/// NO MORE BLOCK MODE SWITCHING - uses grid-only explosions!
class FeltManager {
    // MARK: - Properties
    private weak var container: SKNode?
    private let tableGrid: TableGrid
    private var feltTextureSprite: SKSpriteNode?
    
    // Single overlay sprite for temporary burns (animated, then baked)
    private var burnOverlaySprite: SKSpriteNode?
    private var burnOverlayImage: UIImage?
    private var burnOverlayNeedsRedraw: Bool = false
    private var burnAnimationQueue: [(position: CGPoint, radius: CGFloat, grey: CGFloat, alpha: CGFloat)] = []
    
    // MARK: - Scorch Tracking
    // Track which grid cells have been scorched by burning balls
    private var scorchedCells: Set<GridCell> = []
    private var permanentScorchSprite: SKSpriteNode?
    private var permanentScorchImage: UIImage?
    private var newScorchedCells: Set<GridCell> = []  // NEW: Track cells to add this frame
    
    // Pre-computed scorch patterns for deterministic rendering
    private var cellScorchData: [GridCell: ScorchData] = [:]
    
    // Helper struct for hashable grid coordinates
    private struct GridCell: Hashable {
        let col: Int
        let row: Int
    }
    
    // Helper struct for deterministic scorch appearance
    private struct ScorchData {
        let grey: CGFloat
        let alpha: CGFloat
        let neighbors: [(col: Int, row: Int, grey: CGFloat, alpha: CGFloat)]
    }
    
    init(tableGrid: TableGrid, container: SKNode) {
        self.tableGrid = tableGrid
        self.container = container
    }
    
    // MARK: - Texture Management
    
    /// Create initial felt texture from grid
    func createInitialTexture() {
        guard let container = container else { return }
        
        let texture = tableGrid.generateFeltTexture()
        let sprite = SKSpriteNode(texture: texture)
        sprite.position = CGPoint(x: tableGrid.feltRect.midX, y: tableGrid.feltRect.midY)
        sprite.zPosition = 21
        sprite.texture?.filteringMode = .nearest
        sprite.name = "FeltTexture"
        
        container.addChild(sprite)
        feltTextureSprite = sprite
        
        print("✅ Created optimized felt texture using TableGrid")
    }
    
    /// Rebake felt texture after grid changes (explosions, etc.)
    func rebakeTexture() {
        guard let sprite = feltTextureSprite else { return }
        
        let newTexture = tableGrid.generateFeltTexture()
        sprite.texture = newTexture
        
        #if DEBUG
        print("🎨 Rebaked felt texture with updated holes")
        #endif
    }
    
    // MARK: - Grid-Only Explosions (NO BLOCK MODE!)
    
    /// Create explosion hole in felt using grid-only approach
    /// - Returns: Number of cells destroyed
    @discardableResult
    func createExplosion(at position: CGPoint, radius: CGFloat, scene: SKScene) -> Int {
        #if DEBUG
        print("💥 Creating explosion at \(position) radius: \(radius)")
        #endif
        
        // Check if this is a boss level
        let isBossLevel = (scene as? StarfieldScene)?.isBossLevel ?? false
        
        var destroyedCount = 0
        
        // BOSS LEVEL: Skip felt modifications but still create visual effects
        if !isBossLevel {
            // 1. Destroy grid cells (fast - just array updates)
            destroyedCount = tableGrid.destroyCellsInRadius(center: position, radius: radius, raggedness: 0.3)
            
            // 2. Remove scorch mark sprites within explosion radius
            removeScorchMarksInRadius(center: position, radius: radius)
            
            // 3. Add scorch marks around the perimeter of the explosion
            addScorchMarksAroundExplosion(center: position, radius: radius, scene: scene)
            
            // 4. Rebake texture once with new holes
            rebakeTexture()
            
            #if DEBUG
            print("   🕳️ Destroyed \(destroyedCount) felt cells and added scorch marks")
            #endif
        } else {
            #if DEBUG
            print("   🚫 Skipping felt modification (boss level)")
            #endif
        }
        
        // 5. ALWAYS create visual debris particles for explosion effect (even on boss levels)
        createDebrisParticles(at: position, radius: radius, count: 30, scene: scene)
        
        #if DEBUG
        print("✅ Explosion complete: \(destroyedCount) cells destroyed, visual effects created")
        #endif
        
        return destroyedCount
    }
    
    /// Remove scorch mark sprites within explosion radius
    private func removeScorchMarksInRadius(center: CGPoint, radius: CGFloat) {
        guard let container = container else { return }
        
        // Calculate grid bounds for explosion area
        let (centerCol, centerRow) = tableGrid.worldToGrid(point: center)
        let radiusInBlocks = Int(ceil(radius / tableGrid.blockSize))
        
        var removedCount = 0
        
        // Check all cells in explosion bounding box
        for dy in -radiusInBlocks...radiusInBlocks {
            for dx in -radiusInBlocks...radiusInBlocks {
                let col = centerCol + dx
                let row = centerRow + dy
                
                // Bounds check
                guard row >= 0 && row < tableGrid.rows && col >= 0 && col < tableGrid.cols else {
                    continue
                }
                
                // Calculate distance from explosion center
                let cellWorld = tableGrid.gridToWorld(col: col, row: row)
                let distance = hypot(cellWorld.x - center.x, cellWorld.y - center.y)
                
                // If within explosion radius, remove scorch marks
                if distance <= radius {
                    let cell = GridCell(col: col, row: row)
                    
                    // Remove from tracking set
                    if scorchedCells.remove(cell) != nil {
                        removedCount += 1
                        
                        // Remove main scorch sprite
                        let mainSpriteName = "scorch_\(col)_\(row)"
                        container.childNode(withName: mainSpriteName)?.removeFromParent()
                        
                        // Remove neighbor sprites (check all possible indices)
                        for i in 0..<8 {
                            let neighborSpriteName = "scorch_neighbor_\(col)_\(row)_\(i)"
                            container.childNode(withName: neighborSpriteName)?.removeFromParent()
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        if removedCount > 0 {
            print("🧹 Removed \(removedCount) scorch marks from explosion area")
        }
        #endif
    }
    
    /// Add scorch marks around the perimeter of an explosion
    /// Scorches any felt blocks within explosion radius that survived (weren't destroyed)
    private func addScorchMarksAroundExplosion(center: CGPoint, radius: CGFloat, scene: SKScene) {
        let (centerCol, centerRow) = tableGrid.worldToGrid(point: center)
        let radiusInBlocks = Int(ceil(radius / tableGrid.blockSize))
        
        var scorchedCount = 0
        
        // Check all cells within explosion radius
        for dy in -radiusInBlocks...radiusInBlocks {
            for dx in -radiusInBlocks...radiusInBlocks {
                let col = centerCol + dx
                let row = centerRow + dy
                
                // Bounds check
                guard row >= 0 && row < tableGrid.rows && col >= 0 && col < tableGrid.cols else {
                    continue
                }
                
                // Calculate distance from explosion center
                let cellWorld = tableGrid.gridToWorld(col: col, row: row)
                let distance = hypot(cellWorld.x - center.x, cellWorld.y - center.y)
                
                // Check if within explosion radius
                if distance <= radius {
                    // Only scorch felt cells that SURVIVED (not destroyed)
                    if tableGrid.grid[row][col] == .felt {
                        let cell = GridCell(col: col, row: row)
                        
                        // Only add if not already scorched
                        if !scorchedCells.contains(cell) {
                            scorchedCells.insert(cell)
                            createScorchSprite(for: cell, scene: scene)
                            scorchedCount += 1
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        if scorchedCount > 0 {
            print("🔥 Added \(scorchedCount) scorch marks to blocks that survived explosion")
        }
        #endif
    }
    
    /// Create debris particles for visual explosion effect
    private func createDebrisParticles(at position: CGPoint, radius: CGFloat, count: Int, scene: SKScene) {
        // Use felt color for regular levels, or a visible color for boss levels
        let isBossLevel = (scene as? StarfieldScene)?.isBossLevel ?? false
        let debrisColor: SKColor = isBossLevel ? SKColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1.0) : tableGrid.feltColor  // Orange/red for boss levels
        let blockSize: CGFloat = 5.0
        
        for _ in 0..<count {
            // Create debris sprite (single 5x5 block)
            let debris = SKSpriteNode(color: debrisColor, size: CGSize(width: blockSize, height: blockSize))
            debris.position = position
            debris.zPosition = 2500  // Above everything
            debris.texture?.filteringMode = .nearest
            
            // Random explosion direction
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 150...250)
            let distance = radius * CGFloat.random(in: 0.5...1.5)
            
            // Calculate end position
            let endX = position.x + cos(angle) * distance
            let endY = position.y + sin(angle) * distance
            
            // Create animation sequence
            let moveAction = SKAction.move(to: CGPoint(x: endX, y: endY), duration: 0.4)
            moveAction.timingMode = .easeOut
            
            let fadeAction = SKAction.fadeOut(withDuration: 0.4)
            let scaleAction = SKAction.scale(to: 0.5, duration: 0.4)
            
            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            
            debris.run(group) {
                debris.removeFromParent()
            }
            
            scene.addChild(debris)
        }
    }
    
    // MARK: - Grid Query Methods (for ball collision detection)
    
    /// Check if a grid position has been destroyed
    func isGridPositionDestroyed(row: Int, col: Int) -> Bool {
        guard row >= 0 && row < tableGrid.rows && col >= 0 && col < tableGrid.cols else {
            return true  // Out of bounds = no felt
        }
        
        let cellType = tableGrid.grid[row][col]
        return cellType == .destroyed || cellType == .pocket
    }
    
    /// Check if world position is felt (not destroyed)
    func isFelt(at worldPoint: CGPoint) -> Bool {
        return tableGrid.isFelt(at: worldPoint)
    }
    
    /// Check if world position is a hole (pocket or destroyed)
    func isHole(at worldPoint: CGPoint) -> Bool {
        return tableGrid.isHole(at: worldPoint)
    }
    
    /// Create a single burn mark overlay at a position with a radius, animated on overlay sprite
    func createSingeMarkOverlay(at position: CGPoint, radius: CGFloat, scene: SKScene) {
        // BOSS LEVEL CHECK: Don't create burn marks on boss levels (no visible table)
        if let starfieldScene = scene as? StarfieldScene, starfieldScene.isBossLevel {
            return
        }
        
        // Queue this burn for overlay rendering
        let greyShade = CGFloat.random(in: 0.15...0.35)
        let alpha = CGFloat.random(in: 0.4...0.6)
        let entry = (position: position, radius: radius, grey: greyShade, alpha: alpha)
        burnAnimationQueue.append(entry)
        renderBurnOverlayIfNeeded(scene: scene)
    }
    
    // MARK: - Scorch Tracking for Burning Balls
    
    /// Track a burning ball's position and scorch the felt if it enters a new grid cell
    /// This creates permanent grey marks showing the ball's path across the felt
    /// - Parameters:
    ///   - position: Current world position of the burning ball
    ///   - scene: The scene to add visual effects to
    func trackBurningBallPosition(at position: CGPoint, scene: SKScene) {
        // BOSS LEVEL CHECK: Don't scorch felt on boss levels (no visible table)
        if let starfieldScene = scene as? StarfieldScene, starfieldScene.isBossLevel {
            return
        }
        
        // Convert world position to grid coordinates
        let (col, row) = tableGrid.worldToGrid(point: position)
        
        // Check if this position is valid felt
        guard row >= 0 && row < tableGrid.rows && col >= 0 && col < tableGrid.cols else {
            return
        }
        
        // Only scorch felt cells (not destroyed, pocket, or rail)
        guard tableGrid.grid[row][col] == .felt else {
            return
        }
        
        let cell = GridCell(col: col, row: row)
        
        // If we haven't scorched this cell yet, create a scorch sprite for it
        if !scorchedCells.contains(cell) {
            scorchedCells.insert(cell)
            
            // Create a sprite node for this scorch mark (no texture regeneration!)
            createScorchSprite(for: cell, scene: scene)
            
            #if DEBUG
            print("🔥 Created scorch sprite at (\(col), \(row)) - total scorched: \(scorchedCells.count)")
            #endif
        }
    }
    
    /// Create an individual sprite node for a scorch mark at a grid cell
    /// This avoids texture regeneration and juddering
    private func createScorchSprite(for cell: GridCell, scene: SKScene) {
        guard let container = container else { return }
        
        let blockSize = tableGrid.blockSize
        let greyShades: [CGFloat] = [0.15, 0.20, 0.25, 0.30, 0.35, 0.40]
        
        // Use cell coordinates as seed for deterministic randomness
        let seed = UInt64(cell.col * 73856093) ^ UInt64(cell.row * 19349663)
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        // Main block color
        let mainGrey = greyShades[Int(rng.next() % UInt64(greyShades.count))]
        let mainAlpha = CGFloat(rng.next() % 31 + 50) / 100.0 // 0.5 to 0.8
        
        // Get world position for this cell
        let worldPos = tableGrid.gridToWorld(col: cell.col, row: cell.row)
        
        // Create main scorch block sprite
        let scorchSprite = SKSpriteNode(color: UIColor(white: mainGrey, alpha: mainAlpha), 
                                       size: CGSize(width: blockSize, height: blockSize))
        scorchSprite.position = worldPos
        scorchSprite.zPosition = 22 // Just above felt
        scorchSprite.name = "scorch_\(cell.col)_\(cell.row)"
        container.addChild(scorchSprite)
        
        // Add neighbor sprites (60% chance)
        if rng.next() % 100 > 40 {
            let neighborCount = Int(rng.next() % 3 + 2) // 2-4 neighbors
            let gridOffsets: [(Int, Int)] = [
                (-1, 0), (1, 0),   // Left, right
                (0, 1), (0, -1),   // Up, down
                (-1, 1), (1, 1),   // Diagonals
                (-1, -1), (1, -1)
            ]
            
            for i in 0..<min(neighborCount, gridOffsets.count) {
                let offset = gridOffsets[Int(rng.next() % UInt64(gridOffsets.count))]
                let neighborCol = cell.col + offset.0
                let neighborRow = cell.row + offset.1
                
                // Bounds check
                guard neighborRow >= 0 && neighborRow < tableGrid.rows &&
                      neighborCol >= 0 && neighborCol < tableGrid.cols else {
                    continue
                }
                
                // Only scorch felt cells
                guard tableGrid.grid[neighborRow][neighborCol] == .felt else {
                    continue
                }
                
                let neighborGrey = greyShades[Int(rng.next() % UInt64(greyShades.count))]
                let neighborAlpha = CGFloat(rng.next() % 21 + 20) / 100.0 // 0.2 to 0.4
                
                let neighborWorldPos = tableGrid.gridToWorld(col: neighborCol, row: neighborRow)
                let neighborSprite = SKSpriteNode(color: UIColor(white: neighborGrey, alpha: neighborAlpha),
                                                  size: CGSize(width: blockSize, height: blockSize))
                neighborSprite.position = neighborWorldPos
                neighborSprite.zPosition = 22
                neighborSprite.name = "scorch_neighbor_\(cell.col)_\(cell.row)_\(i)"
                container.addChild(neighborSprite)
            }
        }
    }
    
    /// Update the scorch texture if needed (call this once per frame, not per ball!)
    /// With sprite-based scorching, this method is now a no-op
    func updateScorchTexture(scene: SKScene) {
        // No-op: We use individual sprites now, no texture updates needed
    }
    
    // MARK: - Burn Overlay Methods (for temporary burn effects)
    
    /// Ensure the single overlay sprite exists and is sized to felt
    private func ensureBurnOverlaySprite(in scene: SKScene) {
        guard burnOverlaySprite == nil else { return }
        let size = tableGrid.feltRect.size
        let sprite = SKSpriteNode(color: .clear, size: size)
        sprite.position = CGPoint(x: tableGrid.feltRect.midX, y: tableGrid.feltRect.midY)
        sprite.zPosition = 999
        sprite.name = "burnOverlay"
        sprite.texture?.filteringMode = .nearest
        scene.addChild(sprite)
        burnOverlaySprite = sprite
        burnOverlayImage = nil
        burnOverlayNeedsRedraw = true
    }

    /// Render queued burns into the overlay texture and animate
    private func renderBurnOverlayIfNeeded(scene: SKScene) {
        ensureBurnOverlaySprite(in: scene)
        guard let sprite = burnOverlaySprite else { return }
        guard !burnAnimationQueue.isEmpty else { return }

        // Create or update overlay image by drawing circles
        let size = tableGrid.feltRect.size
        let renderer = UIGraphicsImageRenderer(size: size)
        // Start from previous overlay to accumulate
        let baseImage = burnOverlayImage
        let newImage = renderer.image { ctx in
            let cg = ctx.cgContext
            // Draw previous overlay content
            if let base = baseImage?.cgImage { cg.draw(base, in: CGRect(origin: .zero, size: size)) }
            // Draw new queued burns
            for burn in burnAnimationQueue {
                // Convert world to texture space (points)
                let x = burn.position.x - tableGrid.feltRect.minX
                let y = burn.position.y - tableGrid.feltRect.minY
                // CoreGraphics y is flipped vs SpriteKit texture; our overlay sprite is not flipped when applied,
                // so draw using flipped transform to match SpriteKit coordinates
                cg.saveGState()
                cg.translateBy(x: 0, y: size.height)
                cg.scaleBy(x: 1, y: -1)
                let burnColor = UIColor(white: burn.grey, alpha: burn.alpha)
                cg.setFillColor(burnColor.cgColor)
                let rect = CGRect(x: x - burn.radius, y: y - burn.radius, width: burn.radius * 2, height: burn.radius * 2)
                cg.fillEllipse(in: rect)
                cg.restoreGState()
            }
        }
        burnOverlayImage = newImage
        sprite.texture = SKTexture(image: newImage)
        sprite.texture?.filteringMode = .nearest

        // Animate the overlay for a scorch effect: quick appear, slight scale, then fade
        let appear = SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.03, duration: 0.12)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        scaleDown.timingMode = .easeIn
        let fade = SKAction.fadeAlpha(to: 0.0, duration: 0.35)
        let group = SKAction.group([SKAction.sequence([scaleUp, scaleDown]), fade])
        sprite.removeAllActions()
        sprite.alpha = 0.0
        sprite.run(SKAction.sequence([appear, group]))

        // Clear queue after rendering
        burnAnimationQueue.removeAll()
    }
}

// MARK: - Seeded Random Number Generator
/// Deterministic RNG for consistent scorch patterns
private struct SeededRandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }
    
    mutating func next() -> UInt64 {
        // LCG algorithm
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
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
        
        // ✅ UNIFIED GRID SYSTEM: Create TableGrid for O(1) spatial queries
        let tableGrid = TableGrid(
            tableWidth: alignedTableWidth,
            tableHeight: alignedTableHeight,
            tableCenter: tableCenter,
            feltWidth: feltWidth,
            feltHeight: feltHeight,
            cornerRadius: cornerRadius,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            feltColor: feltColor
        )
        
        // ✅ GRID-BASED FELT MANAGER: No more block mode switching!
        let feltManager = FeltManager(
            tableGrid: tableGrid,
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
        print("🎯 Grid: \(tableGrid.cols)×\(tableGrid.rows) unified spatial system for O(1) queries")
        print("📊 TOTAL: ~\(allNodes.count) nodes (\(physicsNodes.count) physics)")
        print("   feltRect: \(feltRect) holeRadius: \(holeRadius)")
        
        return BlockTableResult(
            container: container,
            allNodes: allNodes,
            physicsNodes: physicsNodes,
            feltRect: feltRect,
            pocketCenters: allPocketCenters,
            pocketRadius: holeRadius,
            feltManager: feltManager,
            tableGrid: tableGrid
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

