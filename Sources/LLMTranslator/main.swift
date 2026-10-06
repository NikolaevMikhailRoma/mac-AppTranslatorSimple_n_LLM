import AppKit

// Menu bar only: no Dock icon, no windows until a translation is shown.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
