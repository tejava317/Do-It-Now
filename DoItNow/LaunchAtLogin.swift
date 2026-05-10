import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            switch (enabled, SMAppService.mainApp.status) {
            case (true, .enabled), (false, .notRegistered), (false, .notFound):
                return
            case (true, _):
                try SMAppService.mainApp.register()
            case (false, _):
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin error: \(error)")
        }
    }
}
