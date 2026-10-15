import Foundation

enum EyeMovement: CaseIterable, Hashable, Sendable {
    case up
    case down
    case left
    case right
    case upperLeft
    case upperMiddle
    case upperRight
    case lowerLeft
    case lowerMiddle
    case lowerRight
    case neutral
}

enum UserSignal: Hashable, Sendable {
    case gaze(EyeMovement)
    case confirm
    case reject
    case commitWord
    case finishSentence
}
