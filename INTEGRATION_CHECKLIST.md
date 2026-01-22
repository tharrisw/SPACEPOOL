# Integration Checklist

Use this checklist to integrate the grid-based table system into your project.

## ✅ Pre-Integration Checklist

- [ ] **Back up your project** (commit to git or create archive)
- [ ] **Review changes** in the architecture comparison document
- [ ] **Understand the grid system** basics from visual reference

## ✅ File Integration Checklist

### Core Files (Required)
- [ ] **Add** `TableGrid.swift` to your Xcode project
  - Location: Main target
  - Compile sources: YES
  
- [ ] **Update** `BlockTableBuilder.swift`
  - ⚠️ This file has been modified - replace with new version
  - Changes: FeltManager simplified, TableGrid integration
  
- [ ] **Update** `BallDamageSystem.swift`
  - ⚠️ This file has been modified - replace with new version
  - Changes: Grid-only explosions, removed block animation code
  
- [ ] **Update** `BlockBall.swift`
  - ⚠️ This file has been modified - replace with new version
  - Changes: Grid-based pocket detection
  
- [ ] **Update** `StarfieldScene+TableDrawing.swift`
  - ⚠️ This file has been modified - replace with new version
  - Changes: Stores tableGrid reference

### Documentation Files (Optional but Recommended)
- [ ] **Add** `GRID_OPTIMIZATION_SUMMARY.md` - Technical overview
- [ ] **Add** `ARCHITECTURE_COMPARISON.md` - Before/after comparison
- [ ] **Add** `MIGRATION_GUIDE.md` - This integration guide
- [ ] **Add** `GRID_VISUAL_REFERENCE.md` - Detailed grid documentation
- [ ] **Add** `COMPILATION_ERRORS_FIXED.md` - Fix documentation

### Test Files (Optional)
- [ ] **Add** `TableGridTests.swift` to test target
  - Uncomment `@testable import SpacePool` line
  - Update module name if needed

## ✅ Code Changes Checklist

### In StarfieldScene Main Class
- [ ] **Add property**: `var tableGrid: TableGrid?`
  - Location: Near `feltManager` and other table properties
  
```swift
// Find this section in your StarfieldScene:
var feltManager: FeltManager?
var tableGrid: TableGrid?  // ← ADD THIS LINE
var blockFeltRect: CGRect?
```

### Build and Compile
- [ ] **Clean build folder** (⌘⇧K)
- [ ] **Build project** (⌘B)
- [ ] **Resolve any remaining errors**
  - Most common: Missing tableGrid property declaration
  - See troubleshooting section in MIGRATION_GUIDE.md

## ✅ Testing Checklist

### Basic Functionality
- [ ] **Launch app** - Table renders correctly
- [ ] **Shoot cue ball** - Physics work normally
- [ ] **Sink into pocket** - Ball detection works
- [ ] **Hit 11-ball** - Explosion creates hole instantly
- [ ] **Multiple explosions** - Holes accumulate correctly
- [ ] **Roll over hole** - Ball sinks into explosion holes

### Performance Testing
- [ ] **Enable FPS display** in Xcode (Debug → View Debugging)
- [ ] **Trigger multiple explosions** rapidly
- [ ] **Verify smooth frame rate** (should stay at 60 FPS)
- [ ] **Check console logs** for grid statistics
- [ ] **Profile with Instruments** (⌘I) - Optional but recommended

### Visual Quality
- [ ] **Explosions look good** - Ragged holes, debris particles
- [ ] **No visual glitches** - Texture updates correctly
- [ ] **Table colors correct** - Felt and rails match theme
- [ ] **Pockets visible** - Original pockets still work

## ✅ Optional Enhancements

### Debug Visualization (Recommended during testing)
- [ ] Add grid debug visualization to StarfieldScene
```swift
#if DEBUG
func toggleGridDebugView() {
    if let existingDebug = childNode(withName: "GridDebug") {
        existingDebug.removeFromParent()
    } else if let grid = tableGrid {
        let debugViz = grid.createDebugVisualization()
        addChild(debugViz)
    }
}
#endif
```

### Performance Monitoring
- [ ] Add grid statistics printing
- [ ] Monitor explosion timings
- [ ] Track destroyed cell count

### Future Features (After stable integration)
- [ ] AI pathfinding using grid
- [ ] Line-of-sight checks
- [ ] Zone-based effects
- [ ] Procedural table generation

## ✅ Cleanup Checklist

### Remove Old Debug Code
Search for and remove references to:
- [ ] `switchToBlockMode` - No longer exists
- [ ] `switchBackToTextureMode` - No longer exists
- [ ] `individualBlocks` - No longer used
- [ ] `isTextureMode` - No longer needed

### Update Comments
- [ ] Remove comments about "hybrid mode"
- [ ] Remove comments about "block mode switching"
- [ ] Add comments about grid-based system

### Documentation Updates
- [ ] Update README if it mentions table architecture
- [ ] Update any design documents
- [ ] Add grid system to architecture documentation

## ✅ Rollback Plan (If Needed)

If you encounter issues and need to revert:
- [ ] **Restore backup** of original files
- [ ] **Remove TableGrid.swift** from project
- [ ] **Remove tableGrid property** from StarfieldScene
- [ ] **Clean and rebuild** project

The old system was fully functional, so rollback is safe.

## ✅ Success Criteria

You'll know integration is successful when:

**Performance**
- ✅ Explosions are noticeably faster (5-9x)
- ✅ Frame rate stays at 60 FPS during chaos
- ✅ No lag when triggering multiple explosions

**Functionality**
- ✅ All ball types work correctly
- ✅ Pocket detection works (original + explosion holes)
- ✅ Multiple explosions accumulate properly
- ✅ No crashes or errors in console

**Visual Quality**
- ✅ Table looks identical to before
- ✅ Explosions create ragged, natural-looking holes
- ✅ Debris particles look good
- ✅ No visual glitches or artifacts

**Code Quality**
- ✅ No compile errors or warnings
- ✅ Console logs are clean
- ✅ Debug messages make sense
- ✅ Code is easier to understand

## 🎉 Completion

Once all checkboxes are complete:
1. Commit your changes to version control
2. Test thoroughly with various game scenarios
3. Consider profiling with Instruments for metrics
4. Enjoy your faster, cleaner table system!

---

**Need Help?**
- Check `MIGRATION_GUIDE.md` for detailed troubleshooting
- Review `COMPILATION_ERRORS_FIXED.md` for common issues
- See `GRID_VISUAL_REFERENCE.md` for how the system works
- Read `ARCHITECTURE_COMPARISON.md` to understand the changes

**Have Questions?**
The grid system is designed to be simple and robust. Most integration issues are related to:
1. Missing tableGrid property declaration
2. Files not added to build target
3. Old debug code still referencing removed methods

Check the troubleshooting section for solutions to these common issues.
