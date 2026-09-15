import AppKit

@MainActor
final class MenuBarService {
    static let shared = MenuBarService()

    private var statusItem: NSStatusItem?

    private init() {}

    func setEnabled(_ enabled: Bool) {
        if enabled, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "f.circle.fill", accessibilityDescription: "App for Facebook")
            item.button?.target = self
            item.button?.action = #selector(showApp)
            statusItem = item
        } else if !enabled, let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func showApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
}
