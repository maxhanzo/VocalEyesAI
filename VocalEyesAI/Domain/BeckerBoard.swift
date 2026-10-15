import Foundation

struct BeckerBoard: Sendable {
    struct Block: Identifiable, Sendable {
        let id: BlockPosition
        let letters: [Character]
    }

    enum BlockPosition: String, CaseIterable, Identifiable, Sendable {
        case upperLeft
        case upperMiddle
        case upperRight
        case lowerLeft
        case lowerMiddle
        case lowerRight

        var id: String { rawValue }
    }

    let blocks: [BlockPosition: Block]

    static let standard = BeckerBoard(
        blocks: [
            .upperLeft: Block(id: .upperLeft, letters: Array("ABCD")),
            .upperMiddle: Block(id: .upperMiddle, letters: Array("EFGH")),
            .upperRight: Block(id: .upperRight, letters: Array("IJKL")),
            .lowerLeft: Block(id: .lowerLeft, letters: Array("MNOP")),
            .lowerMiddle: Block(id: .lowerMiddle, letters: Array("QRST")),
            .lowerRight: Block(id: .lowerRight, letters: Array("UVWXYZ"))
        ]
    )

    func block(for movement: EyeMovement) -> BlockPosition? {
        switch movement {
        case .upperLeft: .upperLeft
        case .upperMiddle: .upperMiddle
        case .upperRight: .upperRight
        case .lowerLeft: .lowerLeft
        case .lowerMiddle: .lowerMiddle
        case .lowerRight: .lowerRight
        default: nil
        }
    }

    func letter(in block: BlockPosition, for movement: EyeMovement) -> Character? {
        guard let letters = blocks[block]?.letters else {
            return nil
        }

        let index: Int?
        switch movement {
        case .up: index = 0
        case .down: index = 1
        case .left: index = 2
        case .right: index = 3
        case .lowerLeft where letters.count > 4: index = 4
        case .lowerRight where letters.count > 5: index = 5
        default: index = nil
        }

        guard let index, letters.indices.contains(index) else {
            return nil
        }

        return letters[index]
    }
}
