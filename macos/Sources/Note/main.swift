import AppKit

// Menu bar only - no Dock icon, no main window, matching the Windows build's tray behaviour.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let delegate = AppDelegate()
application.delegate = delegate
application.run()
