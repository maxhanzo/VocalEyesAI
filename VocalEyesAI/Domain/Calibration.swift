import Foundation

enum CalibrationTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case center
    case left
    case right
    case up
    case down
    case upperLeft
    case upperRight
    case lowerLeft
    case lowerRight

    var id: String { rawValue }

    static let screenLayout: [CalibrationTarget] = [
        .upperLeft, .up, .upperRight,
        .left, .center, .right,
        .lowerLeft, .down, .lowerRight
    ]

    var instruction: String {
        switch self {
        case .center: "Please look at the center of the screen."
        case .left: "Please look to the left."
        case .right: "Please look to the right."
        case .up: "Please look up."
        case .down: "Please look down."
        case .upperLeft: "Please look upper left."
        case .upperRight: "Please look upper right."
        case .lowerLeft: "Please look lower left."
        case .lowerRight: "Please look lower right."
        }
    }

    var symbolName: String {
        switch self {
        case .center: "plus"
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .upperLeft: "arrow.up.left"
        case .upperRight: "arrow.up.right"
        case .lowerLeft: "arrow.down.left"
        case .lowerRight: "arrow.down.right"
        }
    }
}

struct CalibrationPlan: Sendable {
    let steps: [CalibrationTarget]

    static let standard = CalibrationPlan(steps: [
        .center,
        .left, .left,
        .right, .right,
        .up, .up,
        .down, .down,
        .upperLeft, .upperLeft,
        .upperRight, .upperRight,
        .lowerLeft, .lowerLeft,
        .lowerRight, .lowerRight
    ])

    static let testing = CalibrationPlan(steps: [
        .center,
        .up, .up,
        .down, .down,
        .left, .left,
        .right, .right
    ])
}

struct CalibrationCapture: Codable, Sendable {
    let target: CalibrationTarget
    let validSampleCount: Int
    let meanX: Double
    let meanY: Double
    let dispersion: Double
}

struct CalibrationProfile: Codable, Sendable {
    let createdAt: Date
    let captures: [CalibrationCapture]
    let previewRadius: Double
}
