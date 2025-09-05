import Foundation

/// Centralized logging utility with configurable levels
enum Logger {
    enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Current minimum log level - set to .info for release builds
    #if DEBUG
    static var minimumLevel: Level = .debug
    #else
    static var minimumLevel: Level = .info
    #endif
    
    /// Log a message if its level meets or exceeds the minimum level
    static func log(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        if level >= minimumLevel {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let prefix: String
            
            switch level {
            case .debug:
                prefix = "🔍 DEBUG"
            case .info:
                prefix = "ℹ️ INFO"
            case .warning:
                prefix = "⚠️ WARNING"
            case .error:
                prefix = "❌ ERROR"
            }
            
            let output = "[\(prefix)] [\(fileName):\(line)] \(message)"
            print(output)
        }
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}
