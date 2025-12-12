import Foundation

/// Thread-safe счётчик для async тестов (Swift 6 concurrency)
actor CallCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func get() -> Int {
        count
    }
}
