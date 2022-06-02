/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View representing a single cell in the game of tic-tac-fish. A game consists of nine such cells.
*/

import SwiftUI
import TicTacFishShared

struct GameFieldView: View {
    
    @StateObject private var model: GameViewModel

    let position: Int
    let action: (Int) async throws -> Void
    
    init(position: Int, model: GameViewModel, action: @escaping (Int) async throws -> Void) {
        self._model = .init(wrappedValue: model)
        self.position = position
        self.action = action
    }
    
    var body: some View {
        if let move = model.gameState.at(position: position) {
            let highlightColor = model.gameState.isWinningField(position) ?
            Color.green : Color.white
            
            Text("\(move.character)")
                .padding(4)
                .font(.system(size: 60))
                .background(highlightColor)
        } else {
            Button("◻︎") {
                Task { @MainActor in
                    try await action(position)
                }
            }
            .disabled(model.isGameDisabled)
            .padding(4)
            .font(.system(size: 60))
            
        }
    }
}
