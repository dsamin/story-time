import Foundation
import LearningKit

/// A fast, deterministic narrator used only under the `-uiTesting` launch flag. A headless
/// CI simulator has no audio output and `AVSpeechSynthesizer` completion timing there is
/// unreliable, so for UI tests we drive the same word/finish callbacks the real narrators
/// emit — just quickly and predictably. The real audio engine is covered by unit tests.
final class UITestNarrator: Narrator {
    private var generation = 0

    func speak(_ utterance: Utterance, onWord: ((Int) -> Void)?, onFinish: (() -> Void)?) {
        generation &+= 1
        let g = generation
        var delay = 0.0
        for i in utterance.words.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard self?.generation == g else { return }
                onWord?(i)
            }
            delay += 0.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.08) { [weak self] in
            guard self?.generation == g else { return }
            onFinish?()
        }
    }

    func stop() { generation &+= 1 }
}
