/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 */

import OpenAPIRuntime
import OpenAPIHummingbird
import Hummingbird
import Types
import struct Foundation.UUID
import DistributedCluster
import VirtualActors
import Client

struct Api: APIProtocol {
    
    let actorSystem: ClusterSystem
    
    enum Error: Swift.Error {
        case parsingError
        case unsupportedType
    }
    
    func connectToLobby(_ input: Operations.ConnectToLobby.Input) async throws -> Operations.ConnectToLobby.Output {
        let (outputStream, outputContinuation) = AsyncStream<LobbyMessage>.makeStream()
        let player = try Player(input)
        let networkPlayer: NetworkPlayer = try await self.actorSystem.virtualActors.getActor(
            identifiedBy: .init(rawValue: player.playerId),
            dependency: player
        )
        try await networkPlayer.connect(
            to: ServerStream(
                actorSystem: actorSystem,
                input: input.stream,
                output: outputContinuation,
                handler: networkPlayer
            )
        )
        let responseBody: Operations.ConnectToLobby.Output.Ok.Body = .applicationJsonl(
            .init(outputStream.asEncodedJSONLines(), length: .unknown, iterationBehavior: .single)
        )
        return .ok(.init(body: responseBody))
    }
    
    func joinGameSession(_ input: Operations.JoinGameSession.Input) async throws -> Operations.JoinGameSession.Output {
        let (outputStream, outputContinuation) = AsyncStream<SessionMessage>.makeStream()
        let player = try Player(input)
        let networkPlayer: NetworkPlayer = try await self.actorSystem.virtualActors.getActor(
            identifiedBy: .init(
                rawValue: player.playerId
            ),
            dependency: player
        )
        try await networkPlayer.connect(
            to: ServerStream(
                actorSystem: actorSystem,
                input: input.stream,
                output: outputContinuation,
                handler: networkPlayer
            )
        )
        let responseBody: Operations.JoinGameSession.Output.Ok.Body = .applicationJsonl(
            .init(outputStream.asEncodedJSONLines(), length: .unknown, iterationBehavior: .single)
        )
        return .ok(.init(body: responseBody))
    }
    
    init(
        actorSystem: ClusterSystem
    ) {
        self.actorSystem = actorSystem
    }
}

extension Operations.ConnectToLobby.Input {
    var stream: AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, PlayerLobbyMessage> {
        switch self.body {
        case .applicationJsonl(let body):
          body.asDecodedJSONLines(
            of: PlayerLobbyMessage.self
          )
        }
    }
}

extension Operations.JoinGameSession.Input {
    var stream: AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, PlayerSessionMessage> {
        switch self.body {
        case .applicationJsonl(let body):
          body.asDecodedJSONLines(
            of: PlayerSessionMessage.self
          )
        }
    }
}

extension Player {
    init(_ input: Operations.ConnectToLobby.Input) throws {
        let playerId: PlayerIdentity = input.headers.playerId
        let playerName = input.headers.playerName
        guard let playerTeam = Team(rawValue: input.headers.playerTeam) else {
            throw Api.Error.parsingError
        }
        self.init(
            playerId: playerId,
            name: playerName,
            team: playerTeam
        )
    }
    
    init(_ input: Operations.JoinGameSession.Input) throws {
        let playerId: PlayerIdentity = input.headers.playerId
        let playerName = input.headers.playerName
        guard let playerTeam = Team(rawValue: input.headers.playerTeam) else {
            throw Api.Error.parsingError
        }
        self.init(
            playerId: playerId,
            name: playerName,
            team: playerTeam
        )
    }
}
