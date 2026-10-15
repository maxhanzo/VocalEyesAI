import Foundation
import Observation

@MainActor
@Observable
final class CommunicationModel {
    enum Phase: Equatable {
        case idle
        case selectingLetter
        case awaitingConfirmation
        case composingWord
        case sentenceReady
    }

    private let board: BeckerBoard
    private let wordPredictor: any WordPredicting

    private(set) var phase: Phase = .idle
    private(set) var selectedBlock: BeckerBoard.BlockPosition?
    private(set) var selectedLetter: Character?
    private(set) var confirmedText = ""
    private(set) var currentWord = ""
    private(set) var predictions: [String] = []
    private(set) var lastMessage = "Ready for the first block."

    init(
        board: BeckerBoard = .standard,
        wordPredictor: any WordPredicting = LocalWordPredictor()
    ) {
        self.board = board
        self.wordPredictor = wordPredictor
    }

    func block(at position: BeckerBoard.BlockPosition) -> BeckerBoard.Block? {
        board.blocks[position]
    }

    func handle(_ signal: UserSignal) {
        switch signal {
        case .gaze(let movement):
            handleGaze(movement)
        case .confirm:
            confirmLetter()
        case .reject:
            rejectCurrentSelection()
        case .commitWord:
            commitPredictedWord()
        case .finishSentence:
            finishSentence()
        }
    }

    func reset() {
        phase = .idle
        selectedBlock = nil
        selectedLetter = nil
        confirmedText = ""
        currentWord = ""
        predictions = []
        lastMessage = "Ready for the first block."
    }

    private func handleGaze(_ movement: EyeMovement) {
        switch phase {
        case .idle, .composingWord:
            guard let block = board.block(for: movement) else {
                lastMessage = "Choose one of the six board blocks."
                return
            }

            selectedBlock = block
            selectedLetter = nil
            phase = .selectingLetter
            lastMessage = "Block selected. Choose a letter direction."

        case .selectingLetter:
            guard let block = selectedBlock,
                  let letter = board.letter(in: block, for: movement) else {
                lastMessage = "Choose a valid letter direction."
                return
            }

            selectedLetter = letter
            phase = .awaitingConfirmation
            lastMessage = "Letter (letter) selected. Confirm or reject it."

        case .awaitingConfirmation:
            lastMessage = "Confirm or reject the selected letter first."

        case .sentenceReady:
            lastMessage = "Start a new session to continue."
        }
    }

    private func confirmLetter() {
        guard let selectedLetter else {
            lastMessage = "There is no letter to confirm."
            return
        }

        currentWord.append(selectedLetter)
        self.selectedLetter = nil
        selectedBlock = nil
        phase = .composingWord
        lastMessage = "Letter confirmed. Continue or commit the predicted word."
        refreshPredictions()
    }

    private func rejectCurrentSelection() {
        guard phase == .awaitingConfirmation else {
            guard !currentWord.isEmpty else {
                lastMessage = "There is no selection to reject."
                return
            }

            currentWord.removeLast()
            refreshPredictions()
            lastMessage = "Last letter removed."
            return
        }

        selectedLetter = nil
        selectedBlock = nil
        phase = currentWord.isEmpty ? .idle : .composingWord
        lastMessage = "Letter rejected."
    }

    private func commitPredictedWord() {
        guard !currentWord.isEmpty else {
            lastMessage = "There is no word to commit."
            return
        }

        let committedWord = predictions.first ?? currentWord
        confirmedText += committedWord + " "
        currentWord = ""
        predictions = []
        phase = .idle
        lastMessage = "Word committed. Ready for the next word."
    }

    private func finishSentence() {
        guard !confirmedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastMessage = "There is no sentence to finish."
            return
        }

        phase = .sentenceReady
        lastMessage = "Sentence ready for speech output."
    }

    private func refreshPredictions() {
        let prefix = currentWord

        Task {
            let newPredictions = await wordPredictor.predictions(for: prefix)
            guard currentWord == prefix else {
                return
            }
            predictions = newPredictions
        }
    }
}
