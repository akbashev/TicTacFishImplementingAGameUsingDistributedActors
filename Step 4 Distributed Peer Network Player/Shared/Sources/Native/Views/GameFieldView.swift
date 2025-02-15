/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Naive implementation of a receptionist which just keeps broadcasting about all checked-in actors. Good enough for demo purposes.
*/

import SwiftUI
import Client
import ViewModel

struct GameFieldView: View {
    
    @State private var model: GameSessionViewModel

    let position: Int
    let action: (Int) async throws -> Void
    
    init(
        position: Int,
        model: GameSessionViewModel,
        action: @escaping (Int) async throws -> Void
    ) {
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
