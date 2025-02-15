/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Player local actor implementations for the game.
 */
import Foundation
import OpenAPIRuntime
import Types
import NaiveLogging
import Client

@MainActor
@Observable
public class GameSessionViewModel {
    
    public enum Error: Swift.Error {
        case connectionError
    }
    
    let client: Client
    public let player: Player
    public var gameState: GameState
    public var gameResult: GameResult? { self.gameState.result?.result }
    public var waitingForOpponentMove: Bool {
        self.gameState.currentPlayerId == opponent.playerId
    }
    
    public var opponent: Player {
        switch self.gameState.playerOne.playerId {
        case player.playerId:
            self.gameState.playerTwo
        default:
            self.gameState.playerOne
        }
    }
    var connection: ClientStream<PlayerSessionMessage, SessionMessage>!
    
    public init(
        player: Player,
        state: GameState,
        client: Client
    ) {
        self.player = player
        self.gameState = state
        self.client = client
        self.connection = ClientStream<PlayerSessionMessage, SessionMessage>(
            handler: self,
            tryToConnectTo: { stream in
                let response = try await client.joinGameSession(
                    headers: .init(
                        playerId: player.playerId,
                        playerName: player.name,
                        playerTeam: player.team.rawValue
                    ),
                    body: .applicationJsonl(
                        .init(
                            stream.asEncodedJSONLines(),
                            length: .unknown,
                            iterationBehavior: .single
                        )
                    )
                )
                return try response.ok.body.applicationJsonl.asDecodedJSONLines(
                    of: SessionMessage.self
                )
            },
            sendHeartbeat: { $0.yield(.init(message: .Heartbeat(.init()))) }
        )
    }
    
    public func connect() {
        self.connection.connect()
    }
    
    public func disconnect() {
        self.connection.disconnect()
    }
    
    public func makeMove(at position: Int) {
        let move = GameMove(
            playerId: self.player.playerId,
            position: position,
            team: self.player.team,
            teamCharacterId: self.player.team.characterID(for: self.gameState.movesMade)
        )
        guard !gameState.moves.contains(move) else {
            log("game-model", "illegal player move, already selected position \(move.position)")
            return
        }
        
        do {
            try gameState.mark(move)
            // inform the opponent about this player's move
            self.connection.sendMessage(.init(message: .GameMove(move)))
        } catch {
            log("game-model", "Move failed, error: \(error)")
        }
    }
    
    private func markOpponentMove(_ move: GameMove) throws {
        log("model", "mark opponent move: \(move)")
        assert(move.playerId == opponent.playerId)
        
        try gameState.mark(move)
    }
    
    public var isGameDisabled: Bool {
        // the game field is disabled when:

        // we are waiting for the opponent's move
        waitingForOpponentMove ||
        // or when the game has concluded
        self.gameResult != nil
    }
}

extension GameSessionViewModel: ClientStreamHandler {
    public func handle<Input, Output>(_ output: Output, from connection: ClientStream<Input, Output>) async throws {
        switch output {
        case let message as SessionMessage:
            switch message.message {
            case .GameMove(let move):
                guard move.playerId != self.player.playerId else { return }
                try self.markOpponentMove(move)
            }
        default:
            ()
        }
    }
}
