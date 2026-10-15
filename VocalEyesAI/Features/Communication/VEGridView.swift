import SwiftUI

struct VEGridView: View {
    let model: CommunicationModel
    let onOpenCalibration: () -> Void
    private let board = BeckerBoard.standard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    communicationHeader
                    boardView
                    predictionView
                    simulatorControls
                }
                .padding()
                .frame(maxWidth: 1_000)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Vocal Eyes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Calibration", systemImage: "scope") {
                        onOpenCalibration()
                    }
                }
            }
        }
    }

    private var communicationHeader: some View {
        VStack(spacing: 8) {
            Text(model.confirmedText.isEmpty ? " " : model.confirmedText)
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(model.lastMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var boardView: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            ForEach(BeckerBoard.BlockPosition.allCases) { position in
                blockView(for: position)
            }
        }
    }

    private func blockView(for position: BeckerBoard.BlockPosition) -> some View {
        let isSelected = model.selectedBlock == position
        let letters = board.blocks[position]?.letters ?? []

        return VStack(spacing: 12) {
            Text(position.title)
                .font(.headline)

            Text(String(letters))
                .font(.title3.monospaced())
                .minimumScaleFactor(0.7)

            if isSelected {
                Text("Selected")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
    }

    private var predictionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current word")
                .font(.headline)

            Text(model.currentWord.isEmpty ? "—" : model.currentWord)
                .font(.largeTitle.monospaced())

            if !model.predictions.isEmpty {
                Text("Predictions: \(model.predictions.joined(separator: ", "))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var simulatorControls: some View {
        VStack(spacing: 12) {
            Text("Simulator")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                movementButton("↖", .upperLeft)
                movementButton("↑", .upperMiddle)
                movementButton("↗", .upperRight)
            }

            HStack {
                movementButton("←", .lowerLeft)
                movementButton("↓", .lowerMiddle)
                movementButton("→", .lowerRight)
            }

            HStack {
                movementButton("Up", .up)
                movementButton("Down", .down)
                movementButton("Left", .left)
                movementButton("Right", .right)
            }

            HStack {
                Button("Confirm") {
                    model.handle(.confirm)
                }
                .buttonStyle(.borderedProminent)

                Button("Reject / Delete") {
                    model.handle(.reject)
                }
                .buttonStyle(.bordered)

                Button("Commit Word") {
                    model.handle(.commitWord)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Finish Sentence") {
                    model.handle(.finishSentence)
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    model.reset()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func movementButton(_ title: String, _ movement: EyeMovement) -> some View {
        Button(title) {
            model.handle(.gaze(movement))
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}

private extension BeckerBoard.BlockPosition {
    var title: String {
        switch self {
        case .upperLeft: "Upper Left"
        case .upperMiddle: "Upper Middle"
        case .upperRight: "Upper Right"
        case .lowerLeft: "Lower Left"
        case .lowerMiddle: "Lower Middle"
        case .lowerRight: "Lower Right"
        }
    }
}

#Preview {
    VEGridView(
        model: CommunicationModel(),
        onOpenCalibration: {}
    )
}
