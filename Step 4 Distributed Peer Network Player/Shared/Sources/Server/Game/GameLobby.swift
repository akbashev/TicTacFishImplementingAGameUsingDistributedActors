/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 */

import Distributed
import DistributedCluster
import Types

distributed public actor GameLobby: ClusterSingleton {
    
    public typealias ActorSystem = ClusterSystem
    
    /// In progress sessions
    var gameSessions: Set<GameSession> = []
    /// Completed sessions
    var completedSessions: [GameState] = []
    /// Players waiting for a game session
    var waitingPlayers: Set<NetworkPlayer> = []
    /// Ready to play players
    var readyPlayers: Set<NetworkPlayer> = []
    
    var findOpponentTasks: [PlayerIdentity: Task<Void, any Swift.Error>] = [:]
    
    enum PlayerStatusChanged: Codable, Sendable {
        case joined
        case ready
        case disconnected
    }
    
    enum SessionStatusChanged: Codable, Sendable {
        case started
        case finished
    }

    /// A new player joined the lobby and we should find an opponent for it
    distributed func join(player: NetworkPlayer) {
        guard !self.waitingPlayers.contains(player) else { return }
        self.update(.joined, for: player)
        self.notifyPlayerUpdate(.joined, from: player)
    }
    
    distributed func setReady(player: NetworkPlayer) async throws {
        guard !self.readyPlayers.contains(player) else { return }
        self.update(.ready, for: player)
        self.notifyPlayerUpdate(.ready, from: player)
        try await self.findOpponent(for: player, info: player.getInfo())
    }
    
    private func findOpponent(for player: NetworkPlayer, info: Player) {
        self.findOpponentTasks[info.playerId] = Task {
            defer { self.findOpponentTasks.removeValue(forKey: info.playerId) }
            guard let opponent = await self.getOpponentPlayer(info.team) else {
                try await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self.findOpponentTasks.removeValue(forKey: info.playerId)
                return self.findOpponent(for: player, info: info)
            }
            let gameSession = try await GameSession(
                actorSystem: self.actorSystem,
                lobby: self,
                playerOne: player,
                playerTwo: opponent
            )
            self.gameSessions.insert(gameSession)
            try await player.sessionStarted(gameSession)
            try await opponent.sessionStarted(gameSession)
        }
    }
    
    private func getOpponentPlayer(_ team: Team) async -> NetworkPlayer? {
        let readyPlayers: [NetworkPlayer] = await withTaskGroup(
            of: NetworkPlayer?.self,
            returning: [NetworkPlayer].self
        ) { [readyPlayers] group in
            for player in readyPlayers {
                group.addTask {
                    guard let info = try? await player.getInfo(), info.team != team else { return nil }
                    return player
                }
            }
            return await group.reduce(into: [NetworkPlayer]()) { part, next in
                if let next { part.append(next) }
            }
        }
        return readyPlayers.randomElement()
    }
    
    /// As a session completes, remove it from the active game sessions
    distributed func sessionCompleted(_ session: GameSession) async throws {
        self.gameSessions.remove(session)
        let info = try await session.getCurrentInfo()
        self.completedSessions.append(info)
        let sessionPlayers = try await session.players
        guard
            let playerOne = sessionPlayers.first,
            let playerTwo = sessionPlayers.last
        else {
            return
        }
        try await playerOne.sessionFinished(session)
        try await playerTwo.sessionFinished(session)
        self.waitingPlayers.insert(playerOne)
        self.waitingPlayers.insert(playerTwo)
        self.notifyPlayerUpdate(.joined, from: playerOne)
        self.notifyPlayerUpdate(.joined, from: playerTwo)
    }
    
    distributed func disconnect(player: NetworkPlayer) {
        self.update(.disconnected, for: player)
        self.notifyPlayerUpdate(.disconnected, from: player)
    }
    
    distributed func getCurrentInfo() async -> LobbyState {
        let waitingPlayers: [Player] = await withTaskGroup(
            of: Player?.self,
            returning: [Player].self
        ) { [waitingPlayers] group in
            for player in waitingPlayers {
                group.addTask { try? await player.getInfo() }
            }
            return await group.reduce(into: [Player]()) { part, next in
                if let next { part.append(next) }
            }
        }
        let readyPlayers: [Player] = await withTaskGroup(
            of: Player?.self,
            returning: [Player].self
        ) { [readyPlayers] group in
            for player in readyPlayers {
                group.addTask { try? await player.getInfo() }
            }
            return await group.reduce(into: [Player]()) { part, next in
                if let next { part.append(next) }
            }
        }
        return .init(
            waitingPlayers: waitingPlayers,
            readyPlayers: readyPlayers,
            completedSessions: self.completedSessions
        )
    }
    
    // Fire and forget
    private func notifyPlayerUpdate(_ update: PlayerStatusChanged, from player: NetworkPlayer) {
        Task {
            let playerInfo = try await player.getInfo()
            let players = self.waitingPlayers.union(self.readyPlayers)
            for otherPlayer in players where otherPlayer != player {
                let status: PlayerStatusUpdate.StatusPayload = switch update {
                case .joined: .connect
                case .ready: .ready
                case .disconnected: .disconnect
                }
                try await otherPlayer.playerChangedStatus(
                    .init(
                        player: playerInfo,
                        status: status
                    )
                )
            }
        }
    }
    
    // Fire and forget
    private func notifySessionUpdate(_ update: SessionStatusChanged, from session: GameSession) {
        Task {
            let sessionPlayers = try await session.players
            guard
                let playerOne = sessionPlayers.first,
                let playerTwo = sessionPlayers.last
            else {
                return
            }
            let players = self.waitingPlayers.union(self.readyPlayers)
            for otherPlayer in players where (otherPlayer != playerOne && otherPlayer != playerTwo) {
                switch update {
                case .started:
                    try await otherPlayer.sessionStarted(session)
                case .finished:
                    try await otherPlayer.sessionFinished(session)
                }
            }
        }
    }
    
    private func update(
        _ update: PlayerStatusChanged,
        for player: NetworkPlayer
    ) {
        self.waitingPlayers.remove(player)
        self.readyPlayers.remove(player)
        switch update {
        case .joined:
            self.waitingPlayers.insert(player)
            self.cancelMatchmaking(for: player)
        case .ready:
            self.readyPlayers.insert(player)
        case .disconnected:
            self.cancelMatchmaking(for: player)
        }
    }
    
    private func cancelMatchmaking(for player: NetworkPlayer) {
        Task {
            let playerId = try await player.getInfo().playerId
            self.findOpponentTasks[playerId]?.cancel()
            self.findOpponentTasks[playerId] = .none
        }
    }
    
    distributed func run() async throws {
        try await self.actorSystem.terminated
    }
}
