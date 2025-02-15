/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Player local actor implementations for the game.
 */
import Foundation
import OpenAPIRuntime
import Types
import Client

@MainActor
@Observable
public class LobbyViewModel {
    
    public enum Error: Swift.Error {
        case connectionError
    }
    
    public let client: Client
    public let player: Player
    public private(set) var isReady: Bool = false
    public var state: LobbyState
    public var currentGame: GameState?
    public var winCount: [Team: Int] {
        self.state.completedSessions.reduce(into: [Team: Int]()) {
            switch $1.result?.result {
            case .Win(let win):
                $0[win.player.team, default: 0] += 1
            default:
                break
            }
        }
    }
    
    public var readyPlayersByTeam: [Team: [Player]] {
        self.state
            .readyPlayers
            .reduce(into: [Team: [Player]]()) {
                $0[$1.team, default: []].append($1)
            }
    }
    
    public var waitingPlayersByTeam: [Team: [Player]] {
        self.state
            .waitingPlayers
            .reduce(into: [Team: [Player]]()) {
                $0[$1.team, default: []].append($1)
            }
    }
    
    public var numberOfWins: [PlayerIdentity: Int] {
        self.state.completedSessions.reduce(into: [PlayerIdentity: Int]()) {
            switch $1.result?.result {
            case .Win(let win):
                $0[win.player.playerId, default: 0] += 1
            default:
                break
            }
        }
    }
    
    var connection: ClientStream<PlayerLobbyMessage, LobbyMessage>!
    
    public init(
        player: Player,
        client: Client
    ) {
        self.player = player
        self.client = client
        self.state = .init(
            waitingPlayers: [],
            readyPlayers: [],
            completedSessions: []
        )
        self.connection = ClientStream<PlayerLobbyMessage, LobbyMessage>(
            handler: self,
            tryToConnectTo: { stream in
                let response = try await client.connectToLobby(
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
                    of: LobbyMessage.self
                )
            },
            sendHeartbeat: { $0.yield(.init(message: .Heartbeat(.init()))) }
        )
    }
    
    public func setReady(_ ready: Bool) {
        self.isReady = ready
        let status: PlayerStatusUpdate.StatusPayload = if ready { .ready } else { .connect }
        self.connection.sendMessage(.init(message: .PlayerStatusUpdate(.init(player: self.player, status: status))))
        self.updateStateFor(
            player: self.player,
            status: status
        )
    }
    
    public func connect() {
        self.connection.connect()
        let status: PlayerStatusUpdate.StatusPayload = .connect
        self.connection.sendMessage(.init(message: .PlayerStatusUpdate(.init(player: self.player, status: status))))
        self.updateStateFor(
            player: self.player,
            status: status
        )
    }
    
    public func disconnect() {
        self.isReady = false
        let status: PlayerStatusUpdate.StatusPayload = .disconnect
        self.connection.sendMessage(.init(message: .PlayerStatusUpdate(.init(player: self.player, status: .disconnect))))
        self.connection.disconnect()
        self.updateStateFor(
            player: self.player,
            status: status
        )
    }
    
    func updateStateFor(player: Player, status: PlayerStatusUpdate.StatusPayload) {
        self.state.waitingPlayers.removeAll(where: { $0.playerId == player.playerId })
        self.state.readyPlayers.removeAll(where: { $0.playerId == player.playerId })
        switch status {
        case .connect:
            self.state.waitingPlayers.append(player)
        case .ready:
            self.state.readyPlayers.append(player)
        case .disconnect:
            ()
        }
    }
}

extension LobbyViewModel: ClientStreamHandler {
    public func handle<Input, Output>(_ output: Output, from connection: ClientStream<Input, Output>) async throws {
        switch output {
        case let message as LobbyMessage:
            switch message.message {
            case .PlayerStatusUpdate(let playerUpdate):
                self.updateStateFor(
                    player: playerUpdate.player,
                    status: playerUpdate.status
                )
            case .SessionStatusUpdate(let sessionUpdate):
                let playerOne = sessionUpdate.game.playerOne
                let playerTwo = sessionUpdate.game.playerTwo
                switch sessionUpdate._type {
                case .started:
                    if playerOne.playerId == self.player.playerId || playerTwo.playerId == self.player.playerId {
                        self.currentGame = sessionUpdate.game
                    }
                case .finished:
                    if playerOne.playerId == self.player.playerId || playerTwo.playerId == self.player.playerId {
                        self.currentGame = .none
                    }
                }
            case .LobbyState(let lobby):
                self.state = lobby
            }
        default:
            ()
        }
    }
}
