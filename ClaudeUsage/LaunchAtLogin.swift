import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for launch-at-login.
///
/// Note: registration is reliable only when the app lives in a stable location
/// (ideally `/Applications`). Running from DerivedData registers a transient
/// path that may break on rebuild.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin error: \(error.localizedDescription)")
        }
    }
}
