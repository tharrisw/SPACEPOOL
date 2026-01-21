// BallSpriteGenerator.swift
// Generates sprite textures for 8-ball (and other numbered balls) with white spots in different positions

import UIKit
import SpriteKit

final class BallSpriteGenerator {
    
    /// Represents all possible positions for the white spot on a 5x5 block ball
    /// Includes center positions, edge positions, and hidden state
    enum SpotPosition: CaseIterable {
        // Center positions (8 cardinal/diagonal directions)
        case centerRight        // (1, 0)
        case centerTopRight     // (1, 1)
        case centerTop          // (0, 1)
        case centerTopLeft      // (-1, 1)
        case centerLeft         // (-1, 0)
        case centerBottomLeft   // (-1, -1)
        case centerBottom       // (0, -1)
        case centerBottomRight  // (1, -1)
        
        // Edge positions (spot is at the horizon/edge of the ball)
        // These appear when the spot is "rolling away" but still partially visible
        case edgeRight          // (2, 0) - far right edge
        case edgeTopRight       // (2, 1) - upper right edge
        case edgeTop            // (1, 2) or (0, 2) - top edge
        case edgeTopLeft        // (-1, 2) or (-2, 1) - upper left edge
        case edgeLeft           // (-2, 0) - far left edge
        case edgeBottomLeft     // (-2, -1) - lower left edge
        case edgeBottom         // (0, -2) or (1, -2) - bottom edge
        case edgeBottomRight    // (1, -2) or (2, -1) - lower right edge
        
        case hidden             // Spot on back side - all black
        
        /// Returns the grid coordinates for this spot position
        /// Grid center is (0, 0), with x/y ranging from -2 to +2
        var gridCoordinates: (x: CGFloat, y: CGFloat)? {
            switch self {
            // Center positions (clearly visible, spot fully on front hemisphere)
            case .centerRight:       return (1, 0)
            case .centerTopRight:    return (1, 1)
            case .centerTop:         return (0, 1)
            case .centerTopLeft:     return (-1, 1)
            case .centerLeft:        return (-1, 0)
            case .centerBottomLeft:  return (-1, -1)
            case .centerBottom:      return (0, -1)
            case .centerBottomRight: return (1, -1)
            
            // Edge positions (spot at horizon, partially visible/rolling away)
            case .edgeRight:         return (2, 0)
            case .edgeTopRight:      return (2, 1)
            case .edgeTop:           return (0, 2)
            case .edgeTopLeft:       return (-2, 1)
            case .edgeLeft:          return (-2, 0)
            case .edgeBottomLeft:    return (-2, -1)
            case .edgeBottom:        return (0, -2)
            case .edgeBottomRight:   return (2, -1)
            
            case .hidden:            return nil  // No spot visible
            }
        }
    }
    
    private let gridSize: Int = 5
    private let blockSize: CGFloat = 5.0
    
    /// Generate a ball sprite texture with the white spot/stripe at the specified position
    /// - Parameters:
    ///   - fillColor: The base color of the ball (e.g., black for 8-ball, white for 11-ball)
    ///   - spotPosition: Where the white spot/stripe should appear
    ///   - shape: The shape of the ball (circle, square, diamond, etc.)
    ///   - isStriped: If true, draws a horizontal stripe instead of a single spot
    ///   - stripeColor: The color of the stripe (only used if isStriped = true)
    ///   - rotationX: X-axis rotation in radians (for 3D stripe rendering)
    ///   - rotationY: Y-axis rotation in radians (for 3D stripe rendering)
    /// - Returns: An SKTexture with the rendered ball
    func generateTexture(fillColor: SKColor, spotPosition: SpotPosition, shape: BlockBall.Shape = .circle, isStriped: Bool = false, stripeColor: SKColor = .white, rotationX: CGFloat = 0, rotationY: CGFloat = 0) -> SKTexture {
        let size = CGSize(width: CGFloat(gridSize) * blockSize, height: CGFloat(gridSize) * blockSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Get spot coordinates (if visible)
            let spotCoords = spotPosition.gridCoordinates
            
            // Helper to check if a block should be included based on shape
            func shouldIncludeBlock(cx: CGFloat, cy: CGFloat) -> Bool {
                let half = CGFloat(gridSize - 1) / 2
                let ballRadius = (CGFloat(gridSize) * blockSize) / 2
                
                switch shape {
                case .circle:
                    let centerDist = hypot(cx * blockSize, cy * blockSize)
                    return centerDist <= (ballRadius - blockSize / 2)
                case .square:
                    return true
                case .diamond:
                    return abs(cx) + abs(cy) <= half
                case .triangle:
                    return cy >= -abs(cx)
                case .hexagon:
                    let a = abs(Int(cx))
                    let b = abs(Int(cy))
                    return (a + b) <= Int(half)
                }
            }
            
            // Helper to check if a block should be part of the stripe using PROPER 3D rotation
            func isStripeBlock3D(cx: CGFloat, cy: CGFloat) -> Bool {
                // The stripe is a band around the equator at y=0 in the ball's local 3D space
                // We need to:
                // 1. Convert this 2D pixel position to a 3D point on the sphere
                // 2. Apply the ball's 3D rotation (inverse)
                // 3. Check if the rotated point is near the equator (y ≈ 0)
                
                // Normalize block coordinates to -1...1 range
                let half = CGFloat(gridSize - 1) / 2
                let nx = cx / half  // -1 to 1
                let ny = cy / half  // -1 to 1
                
                // Calculate z coordinate (depth into/out of screen)
                // For a sphere: x² + y² + z² = 1
                let r2 = nx * nx + ny * ny
                if r2 > 1.0 {
                    // Outside the sphere projection
                    return false
                }
                let nz = sqrt(1.0 - r2)  // Assume front hemisphere (z > 0 faces camera)
                
                // Now we have a 3D point (nx, ny, nz) on the sphere surface
                // Apply INVERSE rotation to see where this point maps in the ball's local coords
                
                // Rotate around Y axis (inverse = negative angle)
                let cosY = cos(-rotationY)
                let sinY = sin(-rotationY)
                var x1 = nx * cosY + nz * sinY
                let z1 = -nx * sinY + nz * cosY
                
                // Rotate around X axis (inverse = negative angle)
                let cosX = cos(-rotationX)
                let sinX = sin(-rotationX)
                let y1 = ny * cosX - z1 * sinX
                // let z2 = ny * sinX + z1 * cosX  // Don't need final z
                
                // In the ball's local coordinate system, the stripe is at y ≈ 0
                // Check if this point is within the stripe band
                let stripeHalfWidth: CGFloat = 0.2  // About 1 block in normalized coords
                return abs(y1) < stripeHalfWidth
            }
            
            // Helper to check if a block should be the white spot using PROPER 3D rotation
            func isSpotBlock3D(cx: CGFloat, cy: CGFloat) -> Bool {
                // The spot is initially at position (1, 0, 0) in the ball's local 3D space (right side)
                // We need to:
                // 1. Convert this 2D pixel position to a 3D point on the sphere
                // 2. Apply the ball's 3D rotation (inverse)
                // 3. Check if the rotated point is near the spot's original position
                
                // Normalize block coordinates to -1...1 range
                let half = CGFloat(gridSize - 1) / 2
                let nx = cx / half  // -1 to 1
                let ny = cy / half  // -1 to 1
                
                // Calculate z coordinate (depth into/out of screen)
                // For a sphere: x² + y² + z² = 1
                let r2 = nx * nx + ny * ny
                if r2 > 1.0 {
                    // Outside the sphere projection
                    return false
                }
                let nz = sqrt(1.0 - r2)  // Assume front hemisphere (z > 0 faces camera)
                
                // Now we have a 3D point (nx, ny, nz) on the sphere surface
                // Apply INVERSE rotation to see where this point maps in the ball's local coords
                
                // Rotate around Y axis (inverse = negative angle)
                let cosY = cos(-rotationY)
                let sinY = sin(-rotationY)
                let x1 = nx * cosY + nz * sinY
                let z1 = -nx * sinY + nz * cosY
                
                // Rotate around X axis (inverse = negative angle)
                let cosX = cos(-rotationX)
                let sinX = sin(-rotationX)
                let y1 = ny * cosX - z1 * sinX
                let z2 = ny * sinX + z1 * cosX
                
                // In the ball's local coordinate system, the spot is at (1, 0, 0)
                // Check if this point is near that location
                // Use a distance threshold to define the "spot area"
                let spotX: CGFloat = 1.0
                let spotY: CGFloat = 0.0
                let spotZ: CGFloat = 0.0
                
                let dx = x1 - spotX
                let dy = y1 - spotY
                let dz = z2 - spotZ
                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                
                // Spot radius in normalized 3D space (covers about 1 block)
                let spotRadius: CGFloat = 0.35
                return distance < spotRadius
            }
            
            // Draw all blocks
            let half = CGFloat(gridSize - 1) / 2
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let cx = CGFloat(col) - half
                    let cy = CGFloat(row) - half
                    
                    if shouldIncludeBlock(cx: cx, cy: cy) {
                        let blockColor: SKColor
                        
                        if isStriped {
                            // For striped balls: use 3D projection to determine if in stripe
                            if isStripeBlock3D(cx: cx, cy: cy) {
                                blockColor = stripeColor
                            } else {
                                blockColor = fillColor
                            }
                        } else {
                            // For solid balls: check if this is the spot block
                            let isSpotBlock: Bool
                            if let (spotX, spotY) = spotCoords {
                                isSpotBlock = (cx == spotX && cy == spotY)
                            } else {
                                isSpotBlock = false  // Hidden - no spot
                            }
                            blockColor = isSpotBlock ? SKColor.white : fillColor
                        }
                        
                        // Convert to UIKit coordinates (top-left origin)
                        let px = CGFloat(col) * blockSize
                        let py = size.height - CGFloat(row + 1) * blockSize
                        let rect = CGRect(x: px, y: py, width: blockSize, height: blockSize)
                        
                        ctx.setFillColor(blockColor.cgColor)
                        ctx.fill(rect)
                    }
                }
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
    
    /// Generate all 17 sprite textures for a ball (8 center + 8 edge + 1 hidden)
    /// - Parameters:
    ///   - fillColor: The base color of the ball
    ///   - shape: The shape of the ball
    ///   - isStriped: If true, generates striped ball textures instead of spotted
    ///   - stripeColor: The color of the stripe (only used if isStriped = true)
    /// - Returns: Dictionary mapping spot position to texture
    func generateAllTextures(fillColor: SKColor, shape: BlockBall.Shape = .circle, isStriped: Bool = false, stripeColor: SKColor = .white) -> [SpotPosition: SKTexture] {
        var textures: [SpotPosition: SKTexture] = [:]
        
        for position in SpotPosition.allCases {
            textures[position] = generateTexture(fillColor: fillColor, spotPosition: position, shape: shape, isStriped: isStriped, stripeColor: stripeColor)
        }
        
        return textures
    }
    
    /// Convenience method to generate textures for standard ball types
    static func generateFor8Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: .black, shape: shape, isStriped: false)
    }
    
    static func generateFor2Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: .blue, shape: shape, isStriped: false)
    }
    
    static func generateFor3Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: .red, shape: shape, isStriped: false)
    }
    
    static func generateFor4Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: .purple, shape: shape, isStriped: false)
    }
    
    static func generateFor5Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: .orange, shape: shape, isStriped: false)
    }
    
    static func generateFor11Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        // 11-ball is white with a red stripe
        return generator.generateAllTextures(fillColor: .white, shape: shape, isStriped: true, stripeColor: .red)
    }
    
    static func generateFor9Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        // 9-ball is yellow with a white stripe
        return generator.generateAllTextures(fillColor: .yellow, shape: shape, isStriped: true, stripeColor: .white)
    }
    
    static func generateFor10Ball(shape: BlockBall.Shape = .circle) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        // 10-ball is blue with a white stripe
        return generator.generateAllTextures(fillColor: .blue, shape: shape, isStriped: true, stripeColor: .white)
    }
}

// MARK: - Example Usage Extension for BlockBall
extension BlockBall {
    
    /// Update the ball sprite to show a specific spot position (useful for debugging)
    func updateSpotPosition(_ position: BallSpriteGenerator.SpotPosition) {
        let textures: [BallSpriteGenerator.SpotPosition: SKTexture]
        
        switch ballKind {
        case .eight:
            textures = BallSpriteGenerator.generateFor8Ball(shape: shape)
        case .two:
            textures = BallSpriteGenerator.generateFor2Ball(shape: shape)
        case .three:
            textures = BallSpriteGenerator.generateFor3Ball(shape: shape)
        case .four:
            textures = BallSpriteGenerator.generateFor4Ball(shape: shape)
        case .five:
            textures = BallSpriteGenerator.generateFor5Ball(shape: shape)
        case .eleven:
            textures = BallSpriteGenerator.generateFor11Ball(shape: shape)
        default:
            return  // Only numbered balls have spots/stripes
        }
        
        if let ballSprite = visualContainer.children.first(where: { $0.name == "ballSprite" }) as? SKSpriteNode,
           let newTexture = textures[position] {
            ballSprite.texture = newTexture
        }
    }
}
