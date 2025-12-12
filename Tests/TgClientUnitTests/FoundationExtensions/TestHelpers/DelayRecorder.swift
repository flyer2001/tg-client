import Foundation

/// Thread-safe запись задержек для async тестов (Swift 6 concurrency)
actor DelayRecorder {
    private var delays: [Duration] = []

    func record(_ delay: Duration) {
        delays.append(delay)
    }

    func getAll() -> [Duration] {
        delays
    }

    func count() -> Int {
        delays.count
    }
}
