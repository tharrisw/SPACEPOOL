import Foundation
import CoreGraphics

// MARK: - CueBallController default setters (no-op fallbacks)
extension CueBallController {
    @objc func setLinearDamping(_ value: CGFloat) { }
    @objc func setAngularDamping(_ value: CGFloat) { }
    @objc func setTableFriction(_ value: CGFloat) { }
    @objc func setWallFriction(_ value: CGFloat) { }
    @objc func setRestitution(_ value: CGFloat) { }
    @objc func setSpinTransfer(_ value: CGFloat) { }
    @objc func setStopSpeedThreshold(_ value: CGFloat) { }
    @objc func setShotChargeTime(_ value: CGFloat) { }
    @objc func setPowerCurve(_ value: CGFloat) { }
}
