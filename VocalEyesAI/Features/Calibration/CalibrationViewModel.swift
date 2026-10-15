import Foundation
import Observation

@MainActor
@Observable
final class CalibrationViewModel {
    enum Phase: Equatable {
        case ready
        case countingDown
        case capturing
        case waitingForNext
        case preview
    }

    private let plan: CalibrationPlan
    private let captureService: any CalibrationCapturing
    private let previewService: any EyeTrackingStreaming
    private let profileStore: any CalibrationProfileStoring
    private let announcer: any SpeechAnnouncing

    private(set) var phase: Phase = .ready
    private(set) var stepIndex = 0
    private(set) var countdownValue: Int?
    private(set) var statusMessage = ""
    private(set) var captures: [CalibrationCapture] = []
    private(set) var previewX = 0.0
    private(set) var previewY = 0.0
    private(set) var previewTarget: CalibrationTarget = .center
    private var captureTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var smoothedPreviewX = 0.0
    private var smoothedPreviewY = 0.0
    private var pendingPreviewTarget: CalibrationTarget?
    private var pendingPreviewTargetCount = 0
    private var previewSupportsDiagonals = false

    let captureStartDelay: TimeInterval = 0.5
    let captureEndDelayBeforeDone: TimeInterval = 0.2
    let previewRadius = 0.85

    init(
        plan: CalibrationPlan = .testing,
        captureService: any CalibrationCapturing = MockCalibrationCaptureService(),
        previewService: any EyeTrackingStreaming = MockEyeTrackingStreamService(),
        profileStore: any CalibrationProfileStoring = UserDefaultsCalibrationProfileStore(),
        announcer: (any SpeechAnnouncing)? = nil
    ) {
        self.plan = plan
        self.captureService = captureService
        self.previewService = previewService
        self.profileStore = profileStore
        self.announcer = announcer ?? SilentSpeechAnnouncer()
        statusMessage = currentTarget.instruction
    }

    var currentTarget: CalibrationTarget {
        plan.steps[stepIndex]
    }

    var progressText: String {
        "Step \(stepIndex + 1) of \(plan.steps.count)"
    }

    var progress: Double {
        Double(stepIndex) / Double(max(plan.steps.count - 1, 1))
    }

    var capturedSampleCount: Int {
        captures.reduce(0) { $0 + $1.validSampleCount }
    }

    var captureSummary: String {
        let suffix = captures.count == 1 ? "" : "s"
        return "\(captures.count) capture\(suffix), \(capturedSampleCount) valid samples"
    }

    var primaryButtonTitle: String {
        switch phase {
        case .ready:
            "GO"
        case .waitingForNext:
            isLastStep ? "PREVIEW" : "NEXT"
        case .preview:
            "ENTER COMMUNICATION"
        case .countingDown, .capturing:
            "WAIT"
        }
    }

    var canStartOrAdvance: Bool {
        phase == .ready || phase == .waitingForNext || phase == .preview
    }

    var canRepeatCurrentStep: Bool {
        currentTarget != .center && phase == .waitingForNext
    }

    func primaryAction() {
        switch phase {
        case .ready:
            beginCapture()
        case .waitingForNext:
            if isLastStep {
                resetPreview()
                phase = .preview
                statusMessage = "Preview active. Look at the screen targets."
                announcer.announce("Preview.")
                startPreviewTracking()
            } else {
                stepIndex += 1
                phase = .ready
                statusMessage = currentTarget.instruction
                announcer.announce(currentTarget.instruction)
            }
        case .preview, .countingDown, .capturing:
            break
        }
    }

    func repeatCurrentStep() {
        guard canRepeatCurrentStep else {
            return
        }

        phase = .ready
        statusMessage = currentTarget.instruction
        announcer.announce("Repeat step. \(currentTarget.instruction)")
    }

    func updatePreview(x: Double, y: Double) {
        let smoothingFactor = 0.16
        smoothedPreviewX += (x - smoothedPreviewX) * smoothingFactor
        smoothedPreviewY += (y - smoothedPreviewY) * smoothingFactor

        let distance = hypot(smoothedPreviewX, smoothedPreviewY)
        let scale = distance > previewRadius ? previewRadius / distance : 1
        let clampedX = smoothedPreviewX * scale
        let clampedY = smoothedPreviewY * scale
        let candidateTarget = target(for: clampedX, y: clampedY)

        previewX = clampedX
        previewY = clampedY

        guard candidateTarget != previewTarget else {
            pendingPreviewTarget = nil
            pendingPreviewTargetCount = 0
            return
        }

        if pendingPreviewTarget == candidateTarget {
            pendingPreviewTargetCount += 1
        } else {
            pendingPreviewTarget = candidateTarget
            pendingPreviewTargetCount = 1
        }

        guard pendingPreviewTargetCount >= 5 else {
            return
        }

        previewTarget = candidateTarget
        pendingPreviewTarget = nil
        pendingPreviewTargetCount = 0
    }

    func resetPreview() {
        smoothedPreviewX = 0
        smoothedPreviewY = 0
        pendingPreviewTarget = nil
        pendingPreviewTargetCount = 0
        previewSupportsDiagonals = false
        previewX = 0
        previewY = 0
        previewTarget = .center
    }

    func stopPreviewTracking() {
        previewTask?.cancel()
        previewTask = nil
        previewService.stopPreviewStream()
    }

    func reset() {
        captureTask?.cancel()
        stopPreviewTracking()
        captureTask = nil
        phase = .ready
        stepIndex = 0
        countdownValue = nil
        statusMessage = currentTarget.instruction
        captures = []
        resetPreview()
    }

    func profileWasSaved() -> Bool {
        !captures.isEmpty && captures.count == plan.steps.count
    }

    private func startPreviewTracking() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            guard let self,
                  let profile = profileStore.load() else {
                return
            }

            let mapper = CalibrationPreviewMapper(profile: profile)
            previewSupportsDiagonals = profile.captures.contains {
                switch $0.target {
                case .upperLeft, .upperRight, .lowerLeft, .lowerRight:
                    true
                default:
                    false
                }
            }

            do {
                let stream = try await previewService.startPreviewStream()

                for await sample in stream {
                    guard !Task.isCancelled, phase == .preview else {
                        break
                    }

                    let mappedSample = mapper.map(sample)
                    updatePreview(x: mappedSample.x, y: mappedSample.y)
                }
            } catch {
                guard phase == .preview else {
                    return
                }

                statusMessage = "Preview unavailable. Please recalibrate."
            }
        }
    }

    private var isLastStep: Bool {
        stepIndex == plan.steps.count - 1
    }

    private func target(for x: Double, y: Double) -> CalibrationTarget {
        let threshold = 0.24
        let hasHorizontalMovement = abs(x) >= threshold
        let hasVerticalMovement = abs(y) >= threshold

        switch (hasHorizontalMovement, hasVerticalMovement) {
        case (false, false):
            return .center
        case (true, false):
            return x < 0 ? .left : .right
        case (false, true):
            return y < 0 ? .up : .down
        case (true, true):
            guard previewSupportsDiagonals else {
                return abs(x) >= abs(y)
                    ? (x < 0 ? .left : .right)
                    : (y < 0 ? .up : .down)
            }

            switch (x < 0, y < 0) {
            case (true, true): return .upperLeft
            case (false, true): return .upperRight
            case (true, false): return .lowerLeft
            case (false, false): return .lowerRight
            }
        }
    }

    private func beginCapture() {
        guard phase == .ready else {
            return
        }

        phase = .countingDown
        statusMessage = "Ready."
        countdownValue = nil

        captureTask = Task { [weak self] in
            guard let self else {
                return
            }

            await announcer.announceAndWait("Ready.")
            try? await Task.sleep(nanoseconds: UInt64(captureStartDelay * 1_000_000_000))

            guard phase == .countingDown else {
                return
            }

            do {
                let captureSession = try await captureService.startCapture(
                    target: currentTarget
                )

                phase = .capturing
                statusMessage = "Capturing gaze samples."

                for value in stride(from: 3, through: 1, by: -1) {
                    countdownValue = value
                    await announcer.announceAndWait(String(value))
                    try? await Task.sleep(nanoseconds: 350_000_000)

                    guard phase == .capturing else {
                        return
                    }
                }

                countdownValue = nil
                let capture = try await captureSession.finish()
                try? await Task.sleep(
                    nanoseconds: UInt64(captureEndDelayBeforeDone * 1_000_000_000)
                )
                await announcer.announceAndWait("Done.")

                captures.append(capture)
                phase = .waitingForNext
                statusMessage = isLastStep
                    ? "Calibration complete."
                    : "Capture complete. Press NEXT when ready."
                saveProfileIfComplete()
            } catch {
                phase = .ready
                statusMessage = "Capture failed. Please try again."
            }
        }
    }

    private func saveProfileIfComplete() {
        guard isLastStep, captures.count == plan.steps.count else {
            return
        }

        let profile = CalibrationProfile(
            createdAt: Date(),
            captures: captures,
            previewRadius: previewRadius
        )
        profileStore.save(profile)
    }
}
