import Foundation
import Observation

@MainActor
@Observable
final class AppCoordinator {
    enum Route: Equatable {
        case calibration
        case communication
    }

    private let profileStore: any CalibrationProfileStoring
    private let eyeTrackingService: CameraCalibrationCaptureService

    private(set) var route: Route
    let calibrationViewModel: CalibrationViewModel
    let communicationModel: CommunicationModel

    init(
        profileStore: any CalibrationProfileStoring = UserDefaultsCalibrationProfileStore()
    ) {
        self.profileStore = profileStore
        self.eyeTrackingService = CameraCalibrationCaptureService()
        self.route = profileStore.load() == nil ? .calibration : .communication
        self.calibrationViewModel = CalibrationViewModel(
            captureService: eyeTrackingService,
            previewService: eyeTrackingService,
            profileStore: profileStore,
            announcer: OfflineSpeechAnnouncer()
        )
        self.communicationModel = CommunicationModel()
    }

    func enterCommunication() {
        calibrationViewModel.stopPreviewTracking()

        guard profileStore.load() != nil else {
            return
        }

        route = .communication
    }

    func showCalibration() {
        route = .calibration
    }

    func resetCalibration() {
        profileStore.remove()
        calibrationViewModel.reset()
        route = .calibration
    }
}
