import Foundation

struct Settings {
    static var isSoundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isSoundEnabled") }
    }
    static var isHapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isHapticEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isHapticEnabled") }
    }
}
//
//  Settings.swift
//  Patlat
//
//  Created by Oğuz KÖKÇE on 25.05.2025.
//

