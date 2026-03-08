import Foundation

actor PollIntervalRecorder {
    private var values: [Duration] = []

    func append(_ value: Duration) {
        values.append(value)
    }

    func firstValue() -> Duration? {
        values.first
    }
}
