/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View representing a game of tic-tac-fish. Includes information which mode we're playing in, and a game field representation.
*/

import SwiftUI
import Client
import Types
import ViewModel

/// In this game mode, we discover opposing players on the local network, and initiate a game with them.
///
/// Note that no real protections are implemented against starting games with already in-game players,
///
struct GameView: View {
    
    @State private var model: GameSessionViewModel
    
    public let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var player: Player {
        self.model.player
    }
    
    init(
        player: Player,
        state: GameState,
        client: Client
    ) {
        self.model = .init(
            player: player,
            state: state,
            client: client
        )
    }
    
    var body: some View {
        TitleView(
            selectedTeam: self.player.team,
            mode: .peerNetwork
        )
        .onAppear {
            self.model.connect()
        }
        .onDisappear {
            self.model.disconnect()
        }
        
        HStack {
            VStack {
                Text("My Player")
                Text("\(String(describing: self.player.name))")
                    .fontWeight(.light)
            }
            VStack {
                Text("Opponent")
                Text(String(describing: self.model.opponent.name))
                    .fontWeight(.light)
            }
        }
        
        Spacer()
        
        LazyVGrid(columns: self.columns) {
            ForEach(GameState.availablePositions, id: \.self) { position in
                GameFieldView(position: position, model: model) { position in
                    _ = model.makeMove(at: position)
                }
            }
        }
        
        gameResultRowView()
        
        Spacer()
    }
    
}

// - MARK: Additional Views

extension GameView {
    
    struct TitleText {
        
        let mode: GameMode
        
        var body: some View {
            VStack {
                Text("Tic Tac Fish 🐟")
                    .bold()
                    .font(.title)
                switch mode {
                case .offline:
                    Text("Playing offline")
                case .localNetwork:
                    Text("Playing over LocalNetwork")
                case .internet, .peerNetwork:
                    Text("Playing Online")
                }
            }.padding(3)
        }
    }
    
    @ViewBuilder
    func gameResultRowView() -> some View {
        switch model.gameResult {
        case .Win(let result):
            if result.player.playerId == self.player.id {
                Text("You win!")
            } else {
                Text("Opponent won!")
            }
        case .Draw:
            Text("Game ended in a Draw!")
        case .none:
            Text("")
        }
    }
}
