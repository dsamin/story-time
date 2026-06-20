import Foundation

/// A deterministic, framework-free narrator for tests and for the Linux build of the
/// loop. It records everything spoken and synchronously fires word/finish callbacks so
/// the session logic can be exercised without any audio framework.
public final class MockNarrator: Narrator {
    public private(set) var spoken: [Utterance] = []
    public private(set) var wordCallbacks: [Int] = []
    public private(set) var stopCount = 0
    /// When true, `speak` walks every word index through `onWord` then calls `onFinish`.
    public var autoComplete: Bool

    public init(autoComplete: Bool = true) {
        self.autoComplete = autoComplete
    }

    public var lastSpokenText: String? { spoken.last?.text }

    public func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?) {
        spoken.append(utterance)
        if autoComplete {
            for i in utterance.words.indices {
                wordCallbacks.append(i)
                onWord?(i)
            }
            onFinish?()
        }
    }

    public func stop() { stopCount += 1 }

    public func reset() {
        spoken.removeAll()
        wordCallbacks.removeAll()
        stopCount = 0
    }
}
