import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Face ID / Touch ID / passcode gate for opening the app (privacy).
public enum AppLockManager {
    /// Whether the device can do biometric/passcode auth at all.
    public static var available: Bool {
        #if canImport(LocalAuthentication)
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        #else
        return false
        #endif
    }

    public static func authenticate(reason: String = "Разблокируйте bitaps VPN",
                                    completion: @escaping (Bool) -> Void) {
        #if canImport(LocalAuthentication)
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            completion(true)   // no auth available → don't lock the user out
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
        #else
        completion(true)
        #endif
    }
}
