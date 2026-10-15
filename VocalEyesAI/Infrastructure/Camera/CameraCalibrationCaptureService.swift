import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import Vision

enum CameraCaptureError: Error {
    case permissionDenied
    case cameraUnavailable
    case configurationFailed
    case captureAlreadyRunning
    case noValidSamples
}

final class CameraCalibrationCaptureService: NSObject, CalibrationCapturing, EyeTrackingStreaming, @unchecked Sendable {
    private let captureQueue = DispatchQueue(
        label: "com.uedasoft.vocaleyes.camera-capture",
        qos: .userInitiated
    )

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var activeCapture: ActiveCapture?
    private var previewContinuation: AsyncStream<EyeTrackingSample>.Continuation?

    func startCapture(
        target: CalibrationTarget
    ) async throws -> any CalibrationCaptureSession {
        try await requestCameraAccess()

        return try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                do {
                    try self.configureIfNeeded()

                    guard self.activeCapture == nil else {
                        throw CameraCaptureError.captureAlreadyRunning
                    }

                    self.activeCapture = ActiveCapture(target: target)
                    self.session.startRunning()

                    continuation.resume(
                        returning: CameraCalibrationCaptureSession(
                            service: self,
                            target: target
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func startPreviewStream() async throws -> AsyncStream<EyeTrackingSample> {
        try await requestCameraAccess()

        return try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                do {
                    try self.configureIfNeeded()

                    guard self.activeCapture == nil,
                          self.previewContinuation == nil else {
                        throw CameraCaptureError.captureAlreadyRunning
                    }

                    let stream = AsyncStream<EyeTrackingSample> { streamContinuation in
                        self.previewContinuation = streamContinuation
                        streamContinuation.onTermination = { @Sendable [weak self] _ in
                            self?.stopPreviewStream()
                        }
                    }

                    self.session.startRunning()
                    continuation.resume(returning: stream)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stopPreviewStream() {
        captureQueue.async {
            self.previewContinuation?.finish()
            self.previewContinuation = nil

            guard self.activeCapture == nil else {
                return
            }

            self.session.stopRunning()
        }
    }

    private func requestCameraAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return

        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }

            guard granted else {
                throw CameraCaptureError.permissionDenied
            }

        case .denied, .restricted:
            throw CameraCaptureError.permissionDenied

        @unknown default:
            throw CameraCaptureError.permissionDenied
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else {
            return
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw CameraCaptureError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)

        guard session.canAddInput(input) else {
            throw CameraCaptureError.configurationFailed
        }

        guard session.canAddOutput(videoOutput) else {
            throw CameraCaptureError.configurationFailed
        }

        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        session.addOutput(videoOutput)

        session.commitConfiguration()
        isConfigured = true
    }

    fileprivate func finishCapture(
        target: CalibrationTarget
    ) async throws -> CalibrationCapture {
        try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                guard let activeCapture = self.activeCapture,
                      activeCapture.target == target else {
                    continuation.resume(throwing: CameraCaptureError.captureAlreadyRunning)
                    return
                }

                self.activeCapture = nil
                self.session.stopRunning()

                guard !activeCapture.samples.isEmpty else {
                    continuation.resume(throwing: CameraCaptureError.noValidSamples)
                    return
                }

                let meanX = activeCapture.samples.map(\.x).reduce(0, +)
                    / Double(activeCapture.samples.count)
                let meanY = activeCapture.samples.map(\.y).reduce(0, +)
                    / Double(activeCapture.samples.count)

                let dispersion = activeCapture.samples.reduce(0) { partialResult, sample in
                    let distance = hypot(sample.x - meanX, sample.y - meanY)
                    return partialResult + distance
                } / Double(activeCapture.samples.count)

                continuation.resume(
                    returning: CalibrationCapture(
                        target: target,
                        validSampleCount: activeCapture.samples.count,
                        meanX: meanX,
                        meanY: meanY,
                        dispersion: dispersion
                    )
                )
            }
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard activeCapture != nil || previewContinuation != nil,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .upMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first,
              let landmarks = observation.landmarks,
              let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return
        }

        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        guard let leftPoint = averagePoint(
                  from: leftPupil,
                  imageSize: imageSize
              ),
              let rightPoint = averagePoint(
                  from: rightPupil,
                  imageSize: imageSize
              ) else {
            return
        }

        let averagePoint = CGPoint(
            x: (leftPoint.x + rightPoint.x) / 2,
            y: (leftPoint.y + rightPoint.y) / 2
        )

        let normalizedPoint = CGPoint(
            x: (averagePoint.x / imageSize.width) * 2 - 1,
            y: 1 - (averagePoint.y / imageSize.height) * 2
        )

        let sample = EyeTrackingSample(
            x: normalizedPoint.x,
            y: normalizedPoint.y
        )

        if activeCapture != nil {
            activeCapture?.samples.append(normalizedPoint)
        } else {
            previewContinuation?.yield(sample)
        }
    }

    private func averagePoint(
        from region: VNFaceLandmarkRegion2D,
        imageSize: CGSize
    ) -> CGPoint? {
        guard region.pointCount > 0 else {
            return nil
        }

        let points = region.pointsInImage(imageSize: imageSize)
        guard !points.isEmpty else {
            return nil
        }

        let sum = points.reduce(CGPoint.zero) { partialResult, point in
            CGPoint(
                x: partialResult.x + point.x,
                y: partialResult.y + point.y
            )
        }

        return CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )
    }
}

extension CameraCalibrationCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
    }
}

private final class ActiveCapture {
    let target: CalibrationTarget
    var samples: [CGPoint] = []

    init(target: CalibrationTarget) {
        self.target = target
    }
}

private final class CameraCalibrationCaptureSession: CalibrationCaptureSession, @unchecked Sendable {
    private weak var service: CameraCalibrationCaptureService?
    private let target: CalibrationTarget

    init(service: CameraCalibrationCaptureService, target: CalibrationTarget) {
        self.service = service
        self.target = target
    }

    func finish() async throws -> CalibrationCapture {
        guard let service else {
            throw CameraCaptureError.configurationFailed
        }

        return try await service.finishCapture(target: target)
    }
}
