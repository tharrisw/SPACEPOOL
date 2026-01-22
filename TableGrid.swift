//
//  TableGrid.swift
//  SpacePool
//
//  Created by Assistant on 1/21/26.
//
//  Unified grid-based spatial system for table representation
//  Replaces expensive geometric checks with O(1) lookups

import CoreGraphics
import SpriteKit

/// Unified grid system for efficient spatial queries on the pool table
final class TableGrid {
    
    // MARK: - Cell Types
    
    /// Represents the state/type of each grid cell
    enum CellType: UInt8 {
        case empty = 0       // Outside table bounds (off-table)
        case felt = 1        // Playable surface
        case rail = 2        // Bumper/cushion
        case pocket = 3      // Hole (original pocket)
        case destroyed = 4   // Felt destroyed by explosion
    }
    
    // MARK: - Properties
    
    let blockSize: CGFloat = 5.0
    private(set) var grid: [[CellType]]
    let cols: Int
    let rows: Int
    let origin: CGPoint  // Bottom-left corner of grid in world coordinates
    let feltColor: SKColor
    let feltRect: CGRect
    
    // MARK: - Initialization
    
    /// Initialize grid by analyzing table geometry
    init(
        tableWidth: CGFloat,
        tableHeight: CGFloat,
        tableCenter: CGPoint,
        feltWidth: CGFloat,
        feltHeight: CGFloat,
        cornerRadius: CGFloat,
        pocketCenters: [CGPoint],
        pocketRadius: CGFloat,
        feltColor: SKColor
    ) {
        // Calculate grid dimensions
        self.cols = Int(round(tableWidth / blockSize))
        self.rows = Int(round(tableHeight / blockSize))
        
        // Calculate origin (bottom-left)
        self.origin = CGPoint(
            x: tableCenter.x - (CGFloat(cols) * blockSize) / 2,
            y: tableCenter.y - (CGFloat(rows) * blockSize) / 2
        )
        
        self.feltColor = feltColor
        
        // Calculate felt rect
        self.feltRect = CGRect(
            x: tableCenter.x - feltWidth / 2,
            y: tableCenter.y - feltHeight / 2,
            width: feltWidth,
            height: feltHeight
        )
        
        // Initialize grid with empty cells
        self.grid = Array(repeating: Array(repeating: .empty, count: cols), count: rows)
        
        // Build grid by analyzing each cell
        buildGrid(
            tableWidth: tableWidth,
            tableHeight: tableHeight,
            tableCenter: tableCenter,
            feltWidth: feltWidth,
            feltHeight: feltHeight,
            cornerRadius: cornerRadius,
            pocketCenters: pocketCenters,
            pocketRadius: pocketRadius
        )
        
        print("🎯 TableGrid initialized: \(cols)×\(rows) cells (\(cols * rows) total)")
        print("   Origin: \(origin)")
        print("   Felt rect: \(feltRect)")
    }
    
    // MARK: - Grid Building
    
    private func buildGrid(
        tableWidth: CGFloat,
        tableHeight: CGFloat,
        tableCenter: CGPoint,
        feltWidth: CGFloat,
        feltHeight: CGFloat,
        cornerRadius: CGFloat,
        pocketCenters: [CGPoint],
        pocketRadius: CGFloat
    ) {
        // Helper: test if point is inside rounded-rectangle table shape
        func isInsideRoundedRect(worldPoint: CGPoint) -> Bool {
            let halfW = tableWidth / 2
            let halfH = tableHeight / 2
            let r = max(0, min(cornerRadius, min(halfW, halfH)))
            let dx = abs(worldPoint.x - tableCenter.x)
            let dy = abs(worldPoint.y - tableCenter.y)
            
            if dx > halfW || dy > halfH { return false }
            if dx <= halfW - r || dy <= halfH - r { return true }
            
            let cx = halfW - r
            let cy = halfH - r
            let lx = dx - cx
            let ly = dy - cy
            return (lx * lx + ly * ly) <= r * r
        }
        
        // Helper: test if point is in any pocket
        func isPocket(worldPoint: CGPoint) -> Bool {
            for center in pocketCenters {
                if hypot(worldPoint.x - center.x, worldPoint.y - center.y) <= pocketRadius {
                    return true
                }
            }
            return false
        }
        
        var feltCount = 0
        var railCount = 0
        var pocketCount = 0
        
        // Populate grid
        for row in 0..<rows {
            for col in 0..<cols {
                // Get world position for cell center
                let worldPoint = gridToWorld(col: col, row: row)
                
                // Check if inside table bounds
                guard isInsideRoundedRect(worldPoint: worldPoint) else {
                    grid[row][col] = .empty
                    continue
                }
                
                // Check if pocket
                if isPocket(worldPoint: worldPoint) {
                    grid[row][col] = .pocket
                    pocketCount += 1
                    continue
                }
                
                // Check if felt (inside felt rect)
                if feltRect.contains(worldPoint) {
                    grid[row][col] = .felt
                    feltCount += 1
                } else {
                    // Must be rail (inside table but outside felt)
                    grid[row][col] = .rail
                    railCount += 1
                }
            }
        }
        
        print("📊 Grid composition:")
        print("   Felt: \(feltCount) cells")
        print("   Rail: \(railCount) cells")
        print("   Pocket: \(pocketCount) cells")
        print("   Empty: \(cols * rows - feltCount - railCount - pocketCount) cells")
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert grid coordinates to world position (center of cell)
    func gridToWorld(col: Int, row: Int) -> CGPoint {
        return CGPoint(
            x: origin.x + (CGFloat(col) + 0.5) * blockSize,
            y: origin.y + (CGFloat(row) + 0.5) * blockSize
        )
    }
    
    /// Convert world position to grid coordinates
    func worldToGrid(point: CGPoint) -> (col: Int, row: Int) {
        let col = Int((point.x - origin.x) / blockSize)
        let row = Int((point.y - origin.y) / blockSize)
        return (col, row)
    }
    
    // MARK: - Cell Queries (O(1) lookups!)
    
    /// Get cell type at world position
    /// - Returns: Cell type, or .empty if out of bounds
    func cellType(at worldPoint: CGPoint) -> CellType {
        let (col, row) = worldToGrid(point: worldPoint)
        
        guard row >= 0, row < rows, col >= 0, col < cols else {
            return .empty
        }
        
        return grid[row][col]
    }
    
    /// Check if world position is on felt (and not destroyed)
    func isFelt(at worldPoint: CGPoint) -> Bool {
        return cellType(at: worldPoint) == .felt
    }
    
    /// Check if world position is pocket or destroyed felt
    func isHole(at worldPoint: CGPoint) -> Bool {
        let type = cellType(at: worldPoint)
        return type == .pocket || type == .destroyed
    }
    
    /// Check if world position is a rail
    func isRail(at worldPoint: CGPoint) -> Bool {
        return cellType(at: worldPoint) == .rail
    }
    
    // MARK: - Grid Modification
    
    /// Mark a single cell as destroyed
    func destroyCell(at worldPoint: CGPoint) {
        let (col, row) = worldToGrid(point: worldPoint)
        
        guard row >= 0, row < rows, col >= 0, col < cols else { return }
        
        // Only destroy felt cells
        if grid[row][col] == .felt {
            grid[row][col] = .destroyed
        }
    }
    
    /// Destroy cells in a radius with realistic jagged edges
    /// First 2/3 of radius is completely cleared, last 1/3 has directional jagged edges
    /// - Returns: Number of cells destroyed
    @discardableResult
    func destroyCellsInRadius(center: CGPoint, radius: CGFloat, raggedness: CGFloat = 0.3) -> Int {
        let (centerCol, centerRow) = worldToGrid(point: center)
        let radiusInBlocks = Int(ceil(radius / blockSize))
        
        var destroyedCount = 0
        
        // Calculate radii for different destruction zones
        let innerRadius = radius * 0.67  // First 2/3 completely cleared
        let outerRadius = radius           // Full explosion radius
        
        // Generate angular variation for jagged edges (using Perlin-like noise simulation)
        // Create 16 angular segments with random protrusion values
        let segmentCount = 16
        var angularVariations: [CGFloat] = []
        for i in 0..<segmentCount {
            // Each segment gets a random variation between -0.4 and +0.4
            let variation = CGFloat.random(in: -0.4...0.4)
            angularVariations.append(variation)
        }
        
        // Smooth the variations to create more natural-looking edges
        var smoothedVariations: [CGFloat] = []
        for i in 0..<segmentCount {
            let prev = angularVariations[(i - 1 + segmentCount) % segmentCount]
            let curr = angularVariations[i]
            let next = angularVariations[(i + 1) % segmentCount]
            // Average with neighbors for smoother transitions
            let smoothed = (prev + curr * 2 + next) / 4
            smoothedVariations.append(smoothed)
        }
        
        // Iterate over bounding box
        for dy in -radiusInBlocks...radiusInBlocks {
            for dx in -radiusInBlocks...radiusInBlocks {
                let col = centerCol + dx
                let row = centerRow + dy
                
                // Bounds check
                guard row >= 0, row < rows, col >= 0, col < cols else { continue }
                
                // Only destroy felt
                guard grid[row][col] == .felt else { continue }
                
                // Calculate distance and angle from center
                let cellWorld = gridToWorld(col: col, row: row)
                let deltaX = cellWorld.x - center.x
                let deltaY = cellWorld.y - center.y
                let distance = hypot(deltaX, deltaY)
                let angle = atan2(deltaY, deltaX)  // -π to π
                
                // Determine which angular segment this cell is in
                let normalizedAngle = (angle + .pi) / (2 * .pi)  // 0 to 1
                let segmentIndex = Int(normalizedAngle * CGFloat(segmentCount)) % segmentCount
                let angularVariation = smoothedVariations[segmentIndex]
                
                // Apply angular variation to the radius for this direction
                let effectiveOuterRadius = outerRadius * (1.0 + angularVariation)
                let effectiveInnerRadius = innerRadius * (1.0 + angularVariation * 0.5)  // Inner radius varies less
                
                // Determine if should destroy
                let shouldDestroy: Bool
                
                if distance <= effectiveInnerRadius {
                    // Inner 2/3: ALWAYS destroy (complete clearing)
                    shouldDestroy = true
                } else if distance <= effectiveOuterRadius {
                    // Outer 1/3: Jagged edge using gradient + noise
                    // Calculate how far into the jagged zone we are (0 = inner edge, 1 = outer edge)
                    let edgeProgress = (distance - effectiveInnerRadius) / (effectiveOuterRadius - effectiveInnerRadius)
                    
                    // Base destruction probability decreases linearly toward edge
                    let baseProbability = 1.0 - edgeProgress
                    
                    // Add fine-grain noise for irregular edge detail
                    // Use position-based pseudo-random for consistency
                    let noiseValue = fract(sin(CGFloat(col) * 12.9898 + CGFloat(row) * 78.233) * 43758.5453)
                    let noiseFactor = (noiseValue - 0.5) * raggedness * 2.0
                    
                    // Combine probability with noise
                    let finalProbability = baseProbability + noiseFactor
                    
                    // Additional check: Create more aggressive jagged spikes
                    // Some cells near the inner radius get extra chance to protrude outward
                    let spikeBonus: CGFloat
                    if edgeProgress < 0.3 && noiseValue > 0.7 {
                        // Near inner edge with high noise = spike out
                        spikeBonus = 0.4
                    } else if edgeProgress > 0.7 && noiseValue < 0.3 {
                        // Near outer edge with low noise = cut inward
                        spikeBonus = -0.4
                    } else {
                        spikeBonus = 0
                    }
                    
                    shouldDestroy = (finalProbability + spikeBonus) > 0.5
                } else {
                    // Beyond explosion radius: don't destroy
                    shouldDestroy = false
                }
                
                if shouldDestroy {
                    grid[row][col] = .destroyed
                    destroyedCount += 1
                }
            }
        }
        
        return destroyedCount
    }
    
    // Helper function for noise generation
    private func fract(_ value: CGFloat) -> CGFloat {
        return value - floor(value)
    }
    
    // MARK: - Texture Generation
    
    /// Generate a texture representing the current felt state
    func generateFeltTexture() -> SKTexture {
        let size = CGSize(
            width: CGFloat(cols) * blockSize,
            height: CGFloat(rows) * blockSize
        )
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(feltColor.cgColor)
            
            var drawnCount = 0
            
            for row in 0..<rows {
                for col in 0..<cols {
                    // Only draw felt cells (skip destroyed, pockets, rails, empty)
                    guard grid[row][col] == .felt else { continue }
                    
                    // Flip Y for UIGraphics coordinate system
                    let flippedRow = rows - 1 - row
                    
                    let rect = CGRect(
                        x: CGFloat(col) * blockSize,
                        y: CGFloat(flippedRow) * blockSize,
                        width: blockSize,
                        height: blockSize
                    )
                    ctx.fill(rect)
                    drawnCount += 1
                }
            }
            
            #if DEBUG
            if drawnCount < cols * rows / 2 {  // Log if significant destruction
                print("🎨 Generated felt texture: \(drawnCount) active cells")
            }
            #endif
        }
        
        return SKTexture(image: image)
    }
    
    /// Generate a texture for rails only
    func generateRailTexture(railColor: SKColor) -> SKTexture {
        let size = CGSize(
            width: CGFloat(cols) * blockSize,
            height: CGFloat(rows) * blockSize
        )
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(railColor.cgColor)
            
            for row in 0..<rows {
                for col in 0..<cols {
                    // Only draw rail cells
                    guard grid[row][col] == .rail else { continue }
                    
                    // Flip Y for UIGraphics coordinate system
                    let flippedRow = rows - 1 - row
                    
                    let rect = CGRect(
                        x: CGFloat(col) * blockSize,
                        y: CGFloat(flippedRow) * blockSize,
                        width: blockSize,
                        height: blockSize
                    )
                    ctx.fill(rect)
                }
            }
        }
        
        return SKTexture(image: image)
    }
    
    // MARK: - Debug Visualization
    
    #if DEBUG
    /// Create a debug visualization of the grid
    func createDebugVisualization() -> SKNode {
        let container = SKNode()
        container.name = "GridDebug"
        
        for row in 0..<rows {
            for col in 0..<cols {
                let cellType = grid[row][col]
                let color: SKColor
                
                switch cellType {
                case .empty:
                    continue  // Don't draw empty cells
                case .felt:
                    color = .green
                case .rail:
                    color = .brown
                case .pocket:
                    color = .black
                case .destroyed:
                    color = .red
                }
                
                let worldPos = gridToWorld(col: col, row: row)
                let rect = SKSpriteNode(color: color, size: CGSize(width: blockSize - 1, height: blockSize - 1))
                rect.position = worldPos
                rect.alpha = 0.3
                container.addChild(rect)
            }
        }
        
        return container
    }
    #endif
}
