import AppKit

struct WindowFrameStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(frame: NSRect, for accountID: UUID) {
        defaults.set(NSStringFromRect(frame), forKey: key(for: accountID))
    }

    func restoreFrame(for accountID: UUID, on screens: [NSScreen]) -> NSRect? {
        guard let saved = defaults.string(forKey: key(for: accountID)) else { return nil }
        let frame = NSRectFromString(saved)
        guard frame.width > 500, frame.height > 400 else { return nil }
        guard !screens.isEmpty else { return frame }

        if screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            return frame
        }

        let visible = screens[0].visibleFrame
        let size = NSSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func key(for accountID: UUID) -> String {
        "facebook.window.\(accountID.uuidString)"
    }
}

