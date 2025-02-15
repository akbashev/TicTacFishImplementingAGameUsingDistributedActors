/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Player network actor implementations for the game.
*/

import Distributed
import DistributedCluster
import NaiveLogging
import Types
import VirtualActors
import Client

typealias MyPlayer = NetworkPlayer
typealias OpponentPlayer = NetworkPlayer

// ======= ------------------------------------------------------------------------------------------------------------
// - MARK: Local Networking Player

/// A player implementation that can handle remote "your move now" calls.
///
/// Since we're playing with an actual human here, the make move is delegated to the UI where the move will be made,
/// once the human player makes a decision, a reply is sent to the `makeMove()` call.
public distributed actor NetworkPlayer {
  
    public typealias ActorSystem = ClusterSystem

    let info: Player
    var lobby: GameLobby?
    var session: GameSession?
    var lobbyConnection: ServerStream<PlayerLobbyMessage, LobbyMessage>?
    var gameSessionConnection: ServerStream<PlayerSessionMessage, SessionMessage>?

    public init(
        actorSystem: ActorSystem,
        player: Player
    ) {
        self.actorSystem = actorSystem
        self.info = player
    }

    distributed public func joinLobby(_ lobby: GameLobby) async throws {
        try await lobby.join(player: self)
        self.lobby = lobby
        let lobbyInfo = try await lobby.getCurrentInfo()
        self.sendMessage(LobbyMessage(message: .LobbyState(lobbyInfo)))
    }
    
    distributed public func setUserReady() async throws {
        try await self.lobby?.setReady(player: self)
    }
    
    distributed public func leaveLobby() async throws {
        try await self.lobby?.disconnect(player: self)
        self.lobby = .none
    }

    public distributed func makeMove(_ move: GameMove) async throws {
        try await self.session?.playerMoved(self, move: move)
    }
    
    public distributed func sessionStarted(_ session: GameSession) async throws {
        let game = try await session.getCurrentInfo()
        self.session = session
        self.sendMessage(LobbyMessage(message: .SessionStatusUpdate(.init(_type: .started, game: game))))
    }
    
    public distributed func sessionFinished(_ session: GameSession) async throws {
        let game = try await session.getCurrentInfo()
        self.session = .none
        self.sendMessage(LobbyMessage(message: .SessionStatusUpdate(.init(_type: .finished, game: game))))
    }

    public distributed func opponentMoved(_ move: GameMove) {
        self.sendMessage(SessionMessage(message: .GameMove(move)))
    }
    
    public distributed func playerChangedStatus(_ status: PlayerStatusUpdate) {
        self.sendMessage(LobbyMessage(message: .PlayerStatusUpdate(status)))
    }
    
    public distributed func getInfo() -> Player {
        self.info
    }
    
    private func sendMessage(_ message: LobbyMessage) {
        Task {
            try await self.lobbyConnection?.sendMessage(message)
        }
    }
    
    private func sendMessage(_ message: SessionMessage) {
        Task {
            try await self.gameSessionConnection?.sendMessage(message)
        }
    }
}

extension NetworkPlayer: ServerStreamHandler {
    
    distributed public func handle<Input, Output>(
        _ input: Input,
        from connection: ServerStream<Input, Output>
    ) async throws {
        switch input {
        case let message as PlayerLobbyMessage:
            switch message.message {
            case .PlayerStatusUpdate(let statusMessage):
                switch statusMessage.status {
                case .connect:
                    let lobby = try await {
                        if let lobby = self.lobby { return lobby }
                        return try await self.actorSystem.singleton.host(name: "matchmaking_lobby") { actorSystem in
                            GameLobby(actorSystem: actorSystem)
                        }
                    }()
                    try await self.joinLobby(lobby)
                case .ready:
                    try await self.setUserReady()
                case .disconnect:
                    try await self.leaveLobby()
                }
            case .Heartbeat:
                // Skipping cause StreamConnection handles it
                ()
            }
        case let message as PlayerSessionMessage:
            switch message.message {
            case .GameMove(let gameMove):
                try await self.makeMove(gameMove)
            case .Heartbeat:
                // Skipping cause StreamConnection handles it
                ()
            }
        default:
            break
        }
    }
    
    distributed public func disconnect<Input, Output>(from connection: ServerStream<Input, Output>) {
        switch connection {
        case _ as ServerStream<PlayerLobbyMessage, LobbyMessage> where self.lobbyConnection != nil:
            Task { try await self.leaveLobby() }
            self.lobbyConnection = .none
        case _ as ServerStream<PlayerSessionMessage, SessionMessage> where self.gameSessionConnection != nil:
            self.gameSessionConnection = .none
        default:
            break
        }
    }
    
    distributed public func connect<Input, Output>(to connection: ServerStream<Input, Output>) {
        switch connection {
        case let connection as ServerStream<PlayerLobbyMessage, LobbyMessage> where self.lobbyConnection == nil:
            self.lobbyConnection = connection
        case let connection as ServerStream<PlayerSessionMessage, SessionMessage> where self.gameSessionConnection == nil:
            self.gameSessionConnection = connection
        default:
            break
        }
    }
}

extension NetworkPlayer: VirtualActor {
    public static func spawn(on system: DistributedCluster.ClusterSystem, dependency: any Sendable & Codable) async throws -> NetworkPlayer {
        /// A bit of boilerplate to check type until (associated type error)[https://github.com/swiftlang/swift/issues/74769] is fixed
        guard let player = dependency as? Player else { throw VirtualActorError.spawnDependencyTypeMismatch }
        return NetworkPlayer(actorSystem: system, player: player)
    }
}
