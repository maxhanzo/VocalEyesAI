import AVFAudio

@MainActor
final class OfflineSpeechAnnouncer: NSObject, SpeechAnnouncing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completions: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ text: String) {
        synthesizer.speak(makeUtterance(text))
    }

    func announceAndWait(_ text: String) async {
        let utterance = makeUtterance(text)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            completions[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        resumeCompletion(for: utterance)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        resumeCompletion(for: utterance)
    }

    private func makeUtterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.35
        return utterance
    }

    private func resumeCompletion(for utterance: AVSpeechUtterance) {
        completions.removeValue(forKey: ObjectIdentifier(utterance))?.resume()
    }
}
