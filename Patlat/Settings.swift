import Foundation

struct Settings {
    private static let soundKey = "soundEnabled"
    private static let hapticKey = "hapticEnabled"

    /// Uygulama ilk açıldığında varsayılan değerleri kaydeder.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            soundKey: true,
            hapticKey: true
        ])
    }

    static var isSoundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }

    static var isHapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: hapticKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: hapticKey) }
    }
}
//
//  Settings.swift
//  Patlat
//
//  Created by Oğuz KÖKÇE on 25.05.2025.
//

