import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Provides a safe initializer for SF Symbols that fall back when a symbol
/// isn't available on the running OS/version. Use `Image(compatibleSystemName:..., fallback: ...)`
/// to avoid runtime warnings like "No symbol named 'heart.pulse' found in system symbol set".
extension Image {
    init(compatibleSystemName name: String, fallback: String = "questionmark.circle") {
        #if os(iOS) || os(tvOS) || targetEnvironment(simulator)
        // On platforms that provide UIImage, attempt to create it first.
        if let _ = UIImage(systemName: name) {
            self = Image(systemName: name)
        } else if let _ = UIImage(systemName: fallback) {
            self = Image(systemName: fallback)
        } else {
            self = Image(systemName: "questionmark.circle")
        }
        #else
        // Fallback for other platforms
        self = Image(systemName: fallback)
        #endif
    }
}
