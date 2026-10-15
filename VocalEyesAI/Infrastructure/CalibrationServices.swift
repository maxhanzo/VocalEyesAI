import Foundation

protocol CalibrationCaptureSession: Sendable {
    func finish() async throws -> CalibrationCapture
}

protocol CalibrationCapturing: Sendable {
    func startCapture(
        target: CalibrationTarget
    ) async throws -> any CalibrationCaptureSession
}

protocol EyeTrackingStreaming: Sendable {
    func startPreviewStream() async throws -> AsyncStream<EyeTrackingSample>
    func stopPreviewStream()
}

struct MockEyeTrackingStreamService: EyeTrackingStreaming {
    func startPreviewStream() async throws -> AsyncStream<EyeTrackingSample> {
        AsyncStream { continuation in
            continuation.yield(EyeTrackingSample(x: 0, y: 0))
        }
    }

    func stopPreviewStream() {}
}

struct MockCalibrationCaptureService: CalibrationCapturing {
    func startCapture(
        target: CalibrationTarget
    ) async throws -> any CalibrationCaptureSession {
        MockCalibrationCaptureSession(target: target)
    }
}

struct MockCalibrationCaptureSession: CalibrationCaptureSession {
    let target: CalibrationTarget

    func finish() async throws -> CalibrationCapture {
        CalibrationCapture(
            target: target,
            validSampleCount: 30,
            meanX: 0,
            meanY: 0,
            dispersion: 0.05
        )
    }
}

protocol CalibrationProfileStoring: Sendable {
    func load() -> CalibrationProfile?
    func save(_ profile: CalibrationProfile)
    func remove()
}

struct UserDefaultsCalibrationProfileStore: CalibrationProfileStoring {
    private let defaults: UserDefaults
    private let key = "calibration.profile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CalibrationProfile? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(CalibrationProfile.self, from: data)
    }

    func save(_ profile: CalibrationProfile) {
        guard let data = try? JSONEncoder().encode(profile) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    func remove() {
        defaults.removeObject(forKey: key)
    }
}

@MainActor
protocol SpeechAnnouncing {
    func announce(_ text: String)
    func announceAndWait(_ text: String) async
}

struct SilentSpeechAnnouncer: SpeechAnnouncing {
    func announce(_ text: String) {}

    func announceAndWait(_ text: String) async {}
}
