import SwiftUI

struct CalibrationView: View {
    let viewModel: CalibrationViewModel
    let onCalibrationFinished: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                compactHeader
                targetGrid
                calibrationControls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(
                maxWidth: 1_000,
                maxHeight: geometry.size.height,
                alignment: .top
            )
            .frame(maxWidth: .infinity)
        }
        .background(.background)
    }

    private var compactHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibration")
                    .font(.title2.bold())

                Text(viewModel.statusMessage)
                    .font(.callout)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.progressText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(viewModel.captureSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: viewModel.progress)
                    .frame(width: 180)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private var targetGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            ForEach(CalibrationTarget.screenLayout) { target in
                targetView(for: target)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxHeight: .infinity)
    }

    private func targetView(for target: CalibrationTarget) -> some View {
        let highlightedTarget = viewModel.phase == .preview
            ? viewModel.previewTarget
            : viewModel.currentTarget
        let isCurrent = target == highlightedTarget
        let symbolSize: CGFloat = target == .center ? 30 : 26

        return Image(systemName: target.symbolName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 52)
            .background(
                isCurrent ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
            }
            .accessibilityLabel(target.instruction)
    }

    private var calibrationControls: some View {
        HStack(spacing: 12) {
            if let countdownValue = viewModel.countdownValue {
                Text(String(countdownValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }

            if viewModel.currentTarget != .center {
                Button("Repeat Step") {
                    viewModel.repeatCurrentStep()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canRepeatCurrentStep)
            }

            Button(viewModel.primaryButtonTitle) {
                if viewModel.phase == .preview {
                    onCalibrationFinished()
                } else {
                    viewModel.primaryAction()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartOrAdvance)
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CalibrationView(
        viewModel: CalibrationViewModel(),
        onCalibrationFinished: {}
    )
}
