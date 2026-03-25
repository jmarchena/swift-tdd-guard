import Foundation
import XCTest

/// Automatically registers the TDDGuardObserver when the test bundle loads.
///
/// To use auto-registration, add this to your test target's Info.plist:
///
/// ```
/// <key>NSPrincipalClass</key>
/// <string>TDDGuardReporter.TDDGuardAutoRegister</string>
/// ```
///
/// Or for Swift Package Manager test targets, create a file in your test target:
///
/// ```swift
/// import TDDGuardReporter
///
/// private let _register: Void = {
///     TDDGuardAutoRegister.register()
/// }()
/// ```
public final class TDDGuardAutoRegister: NSObject {
    private static var isRegistered = false

    override public init() {
        super.init()
        Self.register()
    }

    /// Manually register the TDD Guard test observer.
    public static func register() {
        guard !isRegistered else { return }
        isRegistered = true
        XCTestObservationCenter.shared.addTestObserver(TDDGuardObserver())
    }
}
