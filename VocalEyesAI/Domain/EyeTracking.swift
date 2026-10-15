import Foundation

struct EyeTrackingSample: Sendable {
    let x: Double
    let y: Double
}

struct CalibrationPreviewMapper: Sendable {
    private let center: CalibrationCapture?
    private let left: CalibrationCapture?
    private let right: CalibrationCapture?
    private let up: CalibrationCapture?
    private let down: CalibrationCapture?
    private let previewRadius: Double

    init(profile: CalibrationProfile) {
        let capturesByTarget = Dictionary(grouping: profile.captures, by: \.target)
        center = capturesByTarget[.center]?.average
        left = capturesByTarget[.left]?.average
        right = capturesByTarget[.right]?.average
        up = capturesByTarget[.up]?.average
        down = capturesByTarget[.down]?.average
        previewRadius = profile.previewRadius
    }

    func map(_ sample: EyeTrackingSample) -> EyeTrackingSample {
        guard let center else {
            return EyeTrackingSample(x: 0, y: 0)
        }

        let mappedX = mapAxis(
            value: sample.x,
            center: center.meanX,
            negativeTarget: left?.meanX,
            positiveTarget: right?.meanX,
            negativeScreenValue: -0.55,
            positiveScreenValue: 0.55
        )

        let mappedY = mapAxis(
            value: sample.y,
            center: center.meanY,
            negativeTarget: up?.meanY,
            positiveTarget: down?.meanY,
            negativeScreenValue: -0.55,
            positiveScreenValue: 0.55
        )

        let distance = hypot(mappedX, mappedY)
        let scale = distance > previewRadius ? previewRadius / distance : 1

        return EyeTrackingSample(
            x: mappedX * scale,
            y: mappedY * scale
        )
    }

    private func mapAxis(
        value: Double,
        center: Double,
        negativeTarget: Double?,
        positiveTarget: Double?,
        negativeScreenValue: Double,
        positiveScreenValue: Double
    ) -> Double {
        let delta = value - center
        let negativeDistance = negativeTarget.map { $0 - center }
        let positiveDistance = positiveTarget.map { $0 - center }

        if let negativeDistance, abs(negativeDistance) > 0.001,
           negativeDistance * delta >= 0 {
            return (delta / negativeDistance) * negativeScreenValue
        }

        if let positiveDistance, abs(positiveDistance) > 0.001,
           positiveDistance * delta >= 0 {
            return (delta / positiveDistance) * positiveScreenValue
        }

        return 0
    }
}

private extension Array where Element == CalibrationCapture {
    var average: CalibrationCapture? {
        guard let first = first else {
            return nil
        }

        let totalSamples = reduce(0) { $0 + $1.validSampleCount }
        let weight = Double(Swift.max(totalSamples, 1))

        return CalibrationCapture(
            target: first.target,
            validSampleCount: totalSamples,
            meanX: reduce(0) { partialResult, capture in
                partialResult + capture.meanX * Double(capture.validSampleCount)
            } / weight,
            meanY: reduce(0) { partialResult, capture in
                partialResult + capture.meanY * Double(capture.validSampleCount)
            } / weight,
            dispersion: reduce(0) { partialResult, capture in
                partialResult + capture.dispersion * Double(capture.validSampleCount)
            } / weight
        )
    }
}
