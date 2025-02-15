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
struct LobbyView: View {
    
    @State private var model: LobbyViewModel

    var player: Player { self.model.player }
    
    init(
        player: Player,
        client: Client
    ) {
        self.model = .init(
            player: player,
            client: client
        )
    }
        
    var body: some View {
        VStack {
            TitleView(
                selectedTeam: player.team,
                mode: .peerNetwork
            )
            
            if self.model.isReady {
                Text("Search for opponent")
                ThreeDotsLoadingIndicatorView()
                Button("Cancel") {
                    self.model.setReady(false)
                }
            } else {
                Button("Ready!") {
                    self.model.setReady(true)
                }
            }
            matchMakingView()
        }
        .onAppear {
            self.model.connect()
        }
        .onDisappear {
            self.model.disconnect()
        }
        .navigate(
            using: $model.currentGame,
            destination: makeGameSessionView
        )
    }
}

// - MARK: Additional Views

extension LobbyView {
    
    struct TitleText {
        
        let mode: GameMode
        
        var body: some View {
            VStack {
                Text("Matchmaking")
            }.padding(3)
        }
    }
    
    @ViewBuilder
    func matchMakingView() -> some View {
        HStack {
            Group {
                teamColumn(.fish)
                completedSessions()
                teamColumn(.rodents)
            }
            .background(Color.orange.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
        }
        .padding(8)
    }
    
    func makeGameSessionView(state: GameState) -> some View {
        GameView(
            player: self.player,
            state: state,
            client: model.client
        )
    }
    
    @ViewBuilder
    func teamColumn(_ team: Team) -> some View {
        VStack(spacing: 0) {
            Text(team.emoji)
                .font(.headline)
                .padding(8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    let readyPlayersByTeam = self.model.readyPlayersByTeam[team] ?? []
                    let waitingPlayersByTeam = self.model.waitingPlayersByTeam[team] ?? []

                    ForEach(readyPlayersByTeam) { player in
                        let winCount: Int = self.model.numberOfWins[player.playerId] ?? 0
                        Text(player.name + " (\(winCount))" + " ✅")
                    }
                    ForEach(waitingPlayersByTeam) { player in
                        let winCount: Int = self.model.numberOfWins[player.playerId] ?? 0
                        Text(player.name + " (\(winCount))")
                    }
                    .padding(8)
                }
            }
        }
    }
    
    @ViewBuilder
    func completedSessions() -> some View {
        VStack(spacing: 0) {
            VStack {
                Text("\(Team.fish.emoji):\(self.model.winCount[.fish] ?? 0)")
                Text(" ⚔️ ")
                Text("\(Team.rodents.emoji):\(self.model.winCount[.rodents] ?? 0)")
            }
            .padding(8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.model.state.completedSessions) { session in
                        if let result = session.result?.result {
                            switch result {
                            case .Win(let win):
                                Text("\(win.player.team.emoji): \(win.player.name) won")
                            case .Draw:
                                Text("Draw")
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

extension Team {
    var emoji: String {
        switch self {
        case .fish: "🐟"
        case .rodents: "🐹"
        }
    }
}

struct ThreeDotsLoadingIndicatorView: View {
    @State private var isAnimating = false
    var color: Color = .orange
    var hidesWhenStopped: Bool = true
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(isAnimating ? 0.5 : 1)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .opacity(hidesWhenStopped && !isAnimating ? 0 : 1)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}
