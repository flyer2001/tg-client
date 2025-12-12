import Foundation

/// Thread-safe boolean флаг для async тестов (Swift 6 concurrency)
actor BoolFlag {
    private var value = false

    func set(_ newValue: Bool) {
        value = newValue
    }

    func get() -> Bool {
        value
    }
}
