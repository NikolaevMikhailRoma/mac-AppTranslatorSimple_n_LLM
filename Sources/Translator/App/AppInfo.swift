import Foundation

/// The app's name as the bundle states it (from app.json), so menus and buttons follow a rename.
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "AppTranslatorSimple"
