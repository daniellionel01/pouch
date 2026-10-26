import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp`, the macOS 13+ way to add an
/// app to Login Items without a helper app. macOS owns the state, and the
/// user can change it in System Settings, so we always read it back from
/// there instead of storing our own copy.
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    /// The user has to allow Pouch in System Settings → General → Login Items.
    static var needsApproval: Bool { status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
