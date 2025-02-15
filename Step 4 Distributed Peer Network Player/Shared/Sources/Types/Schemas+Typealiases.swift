public typealias PlayerLobbyMessage = Components.Schemas.PlayerLobbyMessage
public typealias LobbyMessage = Components.Schemas.LobbyMessage
public typealias PlayerSessionMessage = Components.Schemas.PlayerSessionMessage
public typealias SessionMessage = Components.Schemas.SessionMessage
public typealias PlayerStatusUpdate = Components.Schemas.PlayerStatusUpdate
public typealias SessionStatusUpdate = Components.Schemas.SessionStatusUpdate
public typealias Player = Components.Schemas.Player
public typealias Team = Components.Schemas.Team
public typealias GameMove = Components.Schemas.GameMove
public typealias GameState = Components.Schemas.GameState
/// Result of a game round; A game can end in a draw or win of a specific player.
public typealias GameResult = Components.Schemas.GameResult.ResultPayload
public typealias LobbyState = Components.Schemas.LobbyState
public typealias Win = Components.Schemas.Win
public typealias Draw = Components.Schemas.Draw

extension Player: Identifiable {
    public var id: String { self.playerId }
}

extension GameState: Identifiable {
    public var id: String { self.sessionId }
}
