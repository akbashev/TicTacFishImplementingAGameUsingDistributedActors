/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 */


import Distributed
import DistributedCluster
import Types
import NaiveLogging
import Foundation
import VirtualActors
import EventSourcing

/// Keeps track of an active game between two players.
distributed public actor GameSession: EventSourced {
    
    public typealias ActorSystem = ClusterSystem
    
    enum Error: Swift.Error {
        case illegalMove
    }
    
    public enum Event: Codable, Sendable {
        case move(GameMove)
    }
    
    distributed public var persistenceID: EventSourcing.PersistenceID { self.sessionId }

    var sessionId: String {
        self.gameState.sessionId
    }
    let lobby: GameLobby
    let playerOne: NetworkPlayer
    let playerTwo: NetworkPlayer
    
    var gameState: GameState
    
    distributed var players: [NetworkPlayer] {
        [playerOne, playerTwo]
    }

    distributed public func playerMoved(_ player: NetworkPlayer, move: GameMove) async throws {
        let playerInfo = try await player.getInfo()
        guard playerInfo.playerId == self.gameState.currentPlayerId else {
            log("player", "Opponent made illegal move! \(move)")
            throw Error.illegalMove
        }
        try await self.emit(event: .move(move))
        let nextPlayer = player == self.playerOne ? self.playerTwo : self.playerOne
        try await nextPlayer.opponentMoved(move)
        // Notify if complete
        guard self.gameState.result != nil else { return }
        try await lobby.sessionCompleted(self)
    }
    
    distributed public func getCurrentInfo() async throws -> GameState {
        self.gameState
    }
    
    public func handleEvent(_ event: Event) {
        switch event {
        case .move(let move):
            try? self.gameState.mark(move)
        }
    }
    
    public init(
        actorSystem: ClusterSystem,
        lobby: GameLobby,
        sessionId: UUID,
        playerOne: NetworkPlayer,
        playerTwo: NetworkPlayer
    ) async throws {
        self.actorSystem = actorSystem
        self.lobby = lobby
        self.playerOne = playerOne
        self.playerTwo = playerTwo
        let playerOneInfo = try await playerOne.getInfo()
        let playerTwoInfo = try await playerTwo.getInfo()
        let currentPlayer = [playerOneInfo, playerTwoInfo].randomElement()!
        self.gameState = .init(
            sessionId: sessionId.uuidString,
            playerOne: playerOneInfo,
            playerTwo: playerTwoInfo,
            currentPlayerId: currentPlayer.playerId,
            moves: []
        )
    }
}
