import Foundation
import os

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Coppola.Lionomic"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
