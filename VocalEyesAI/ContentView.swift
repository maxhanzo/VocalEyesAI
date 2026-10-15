import SwiftUI

struct ContentView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        Group {
            switch coordinator.route {
            case .calibration:
                CalibrationView(
                    viewModel: coordinator.calibrationViewModel,
                    onCalibrationFinished: coordinator.enterCommunication
                )

            case .communication:
                VEGridView(
                    model: coordinator.communicationModel,
                    onOpenCalibration: coordinator.resetCalibration
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
