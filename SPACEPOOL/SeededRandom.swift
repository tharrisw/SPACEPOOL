import Foundation

/// Linear Congruential Generator for seeded randomness with call counter
class SeededRandom {
    
    // MARK: - Constants
    
    private enum LCGParameters {
        static let multiplier: UInt64 = 6364136223846793005
        static let increment: UInt64 = 1442695040888963407
        static let goldenRatio: UInt64 = 0x9E3779B97F4A7C15
    }
    
    private enum PersistenceParameters {
        static let counterKey = "StarfieldRandomCounter"
        static let saveInterval: UInt64 = 100
        static let retransformInterval: UInt64 = 1000
    }
    
    // MARK: - Properties
    
    private let baseSeed: UInt64
    private var state: UInt64
    private var callCounter: UInt64
    
    // MARK: - Initialization
    
    init(seed: UInt64) {
        self.baseSeed = seed
        self.callCounter = Self.loadPersistedCounter()
        self.state = Self.transformSeed(baseSeed: seed, counter: self.callCounter)
    }
    
    // MARK: - Random Number Generation
    
    func next() -> UInt64 {
        incrementAndPersistCounter()
        retransformStateIfNeeded()
        
        // LCG parameters from Numerical Recipes
        state = state &* LCGParameters.multiplier &+ LCGParameters.increment
        return state
    }
    
    func nextDouble() -> Double {
        return Double(next()) / Double(UInt64.max)
    }
    
    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let normalizedValue = nextDouble()
        return scaleToRange(normalizedValue, range: range)
    }
    
    func nextInt(in range: ClosedRange<Int>) -> Int {
        let randomValue = next()
        return mapToIntRange(randomValue, range: range)
    }
    
    // MARK: - Helper Methods
    
    private func scaleToRange(_ normalizedValue: Double, range: ClosedRange<Double>) -> Double {
        let rangeSpan = range.upperBound - range.lowerBound
        return range.lowerBound + (normalizedValue * rangeSpan)
    }
    
    private func mapToIntRange(_ randomValue: UInt64, range: ClosedRange<Int>) -> Int {
        let span = calculateIntSpan(for: range)
        let offset = Int(randomValue % span)
        return range.lowerBound + offset
    }
    
    private func calculateIntSpan(for range: ClosedRange<Int>) -> UInt64 {
        return UInt64(range.upperBound - range.lowerBound + 1)
    }
    
    // MARK: - Counter Management
    
    private func incrementAndPersistCounter() {
        incrementCounter()
        persistCounterIfNeeded()
    }
    
    private func incrementCounter() {
        callCounter = callCounter &+ 1
    }
    
    private func persistCounterIfNeeded() {
        // Persist counter periodically to avoid too many writes
        if shouldPersistCounter() {
            persistCounter()
        }
    }
    
    private func shouldPersistCounter() -> Bool {
        return callCounter % PersistenceParameters.saveInterval == 0
    }
    
    private func retransformStateIfNeeded() {
        // Re-transform state periodically using the new counter value
        // This ensures the counter has a lasting effect on randomness
        if shouldRetransformState() {
            retransformState()
        }
    }
    
    private func shouldRetransformState() -> Bool {
        return callCounter % PersistenceParameters.retransformInterval == 0
    }
    
    private func retransformState() {
        state = Self.transformSeed(baseSeed: baseSeed, counter: callCounter)
    }
    
    func saveCounter() {
        persistCounter()
        print("📊 Final call counter saved: \(callCounter)")
    }
    
    // MARK: - Persistence
    
    private static func loadPersistedCounter() -> UInt64 {
        let defaults = UserDefaults.standard
        if let savedCounter = defaults.object(forKey: PersistenceParameters.counterKey) as? UInt64 {
            print("📊 Loaded call counter: \(savedCounter)")
            return savedCounter
        } else {
            print("📊 Starting new call counter at 0")
            return 0
        }
    }
    
    private func persistCounter() {
        let defaults = UserDefaults.standard
        defaults.set(callCounter, forKey: PersistenceParameters.counterKey)
    }
    
    // MARK: - Seed Transformation
    
    private static func transformSeed(baseSeed: UInt64, counter: UInt64) -> UInt64 {
        // Apply a transformation that combines the base seed with the counter
        // Using XOR and rotation to mix the bits thoroughly
        let rotated = rotateCounterBits(counter)
        let mixed = mixWithBaseSeed(baseSeed, rotated: rotated)
        let hashed = applyGoldenRatioHash(to: mixed)
        return finalMix(hashed)
    }
    
    private static func rotateCounterBits(_ counter: UInt64) -> UInt64 {
        return (counter &<< 32) | (counter &>> 32)
    }
    
    private static func mixWithBaseSeed(_ baseSeed: UInt64, rotated: UInt64) -> UInt64 {
        return baseSeed ^ rotated
    }
    
    private static func applyGoldenRatioHash(to value: UInt64) -> UInt64 {
        return value &* LCGParameters.goldenRatio
    }
    
    private static func finalMix(_ hashed: UInt64) -> UInt64 {
        return hashed ^ (hashed &>> 27)
    }
}
