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
            
            // Helper to convert 2D block coordinates to 3D point in ball's local coordinate system
            // Returns nil if the block is outside the sphere projection
            func project2DTo3D(cx: CGFloat, cy: CGFloat) -> (x: CGFloat, y: CGFloat, z: CGFloat)? {
                // Normalize block coordinates to -1...1 range
                let half = CGFloat(gridSize - 1) / 2
                let nx = cx / half  // -1 to 1
                let ny = cy / half  // -1 to 1
                
                // Calculate z coordinate (depth into/out of screen)
                // For a sphere: x² + y² + z² = 1
                let r2 = nx * nx + ny * ny
                if r2 > 1.0 {
                    // Outside the sphere projection
                    return nil
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
                
                return (x1, y1, z2)
            }
            
            // Helper to check if a block should be part of the stripe using PROPER 3D rotation
            func isStripeBlock3D(cx: CGFloat, cy: CGFloat) -> Bool {
                guard let point3D = project2DTo3D(cx: cx, cy: cy) else { return false }
                
                // In the ball's local coordinate system, the stripe is at y ≈ 0
                // Check if this point is within the stripe band
                let stripeHalfWidth: CGFloat = 0.2  // About 1 block in normalized coords
                return abs(point3D.y) < stripeHalfWidth
            }
            
            // Helper to check if a block should be the white spot using PROPER 3D rotation
            func isSpotBlock3D(cx: CGFloat, cy: CGFloat) -> Bool {
                guard let point3D = project2DTo3D(cx: cx, cy: cy) else { return false }
                
                // In the ball's local coordinate system, the spot is at (1, 0, 0)
                // Check if this point is near that location using distance threshold
                let spotX: CGFloat = 1.0
                let spotY: CGFloat = 0.0
                let spotZ: CGFloat = 0.0
                
                let dx = point3D.x - spotX
                let dy = point3D.y - spotY
                let dz = point3D.z - spotZ
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
                        // Determine block color based on stripe/spot logic
                        let blockColor: SKColor
                        if isStriped {
                            blockColor = isStripeBlock3D(cx: cx, cy: cy) ? stripeColor : fillColor
                        } else if let (spotX, spotY) = spotCoords, cx == spotX && cy == spotY {
                            blockColor = .white  // This is the spot block
                        } else {
                            blockColor = fillColor
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
    
    /// Generate textures for any ball type based on its visual properties
    /// - Parameters:
    ///   - fillColor: The base color of the ball
    ///   - shape: The shape of the ball
    ///   - isStriped: Whether the ball has a stripe instead of a spot
    ///   - stripeColor: The color of the stripe (only used if isStriped = true)
    ///   - spotColor: The color of the spot (defaults to white)
    /// - Returns: Dictionary mapping spot position to texture
    static func generate(fillColor: SKColor, 
                        shape: BlockBall.Shape = .circle, 
                        isStriped: Bool = false, 
                        stripeColor: SKColor = .white) -> [SpotPosition: SKTexture] {
        let generator = BallSpriteGenerator()
        return generator.generateAllTextures(fillColor: fillColor, shape: shape, isStriped: isStriped, stripeColor: stripeColor)
    }
}

// MARK: - Example Usage Extension for BlockBall
extension BlockBall {
    
    /// Shared color definitions for ball types (public for use in UI)
    public static let lightRed = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)  // Darker red, more saturated
    public static let darkRed = SKColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1.0)
    public static let darkGreen = SKColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
    public static let maroon = SKColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0)
    
    /// Returns the visual properties (color, stripe info) for this ball kind
    private var visualProperties: (fillColor: SKColor, isStriped: Bool, stripeColor: SKColor)? {
        switch ballKind {
        case .cue:
            return nil  // Cue ball has no spots/stripes
        case .one:
            return (.yellow, false, .white)
        case .two:
            return (.blue, false, .white)
        case .three:
            return (Self.lightRed, false, .white)
        case .four:
            return (.purple, false, .white)
        case .five:
            return (.orange, false, .white)
        case .six:
            return (Self.darkGreen, false, .white)
        case .seven:
            return (Self.darkRed, false, .white)
        case .eight:
            return (.black, false, .white)
        case .nine:
            return (.white, true, .yellow)  // White with yellow stripe
        case .ten:
            return (.white, true, .blue)  // White with blue stripe
        case .eleven:
            return (.white, true, Self.lightRed)  // White with light red stripe
        case .twelve:
            return (.white, true, .purple)  // White with purple stripe
        case .thirteen:
            return (.white, true, .orange)  // White with orange stripe
        case .fourteen:
            return (.white, true, Self.darkGreen)  // White with dark green stripe
        case .fifteen:
            return (.white, true, Self.maroon)  // White with maroon stripe
        }
    }
    
    /// Update the ball sprite to show a specific spot position (useful for debugging)
    func updateSpotPosition(_ position: BallSpriteGenerator.SpotPosition) {
        guard let properties = visualProperties else { return }
        
        let textures = BallSpriteGenerator.generate(
            fillColor: properties.fillColor,
            shape: shape,
            isStriped: properties.isStriped,
            stripeColor: properties.stripeColor
        )
        
        if let ballSprite = visualContainer.children.first(where: { $0.name == "ballSprite" }) as? SKSpriteNode,
           let newTexture = textures[position] {
            ballSprite.texture = newTexture
        }
    }
}
