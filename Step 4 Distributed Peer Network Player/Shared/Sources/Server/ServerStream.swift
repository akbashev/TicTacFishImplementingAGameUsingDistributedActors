/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 */

import Types
import Distributed
import DistributedCluster
import OpenAPIRuntime
import AsyncAlgorithms

distributed public actor ServerStream<Input, Output>
    where Input: Codable & Sendable,
          Output: Codable & Sendable {
    
    public typealias ActorSystem = ClusterSystem
    
    var handler: (any ServerStreamHandler)?
    var lastMessageDate: ContinuousClock.Instant
    var messageListener: Task<Void, any Error>?
    var heartbeatListener: Task<Void, any Error>?

    let output: AsyncStream<Output>.Continuation
    let heartbeatSequence: AsyncTimerSequence<ContinuousClock>
    let heartbeatInterval: Duration
    
    public init(
        actorSystem: ActorSystem,
        input: AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, Input>,
        output: AsyncStream<Output>.Continuation,
        handler: any ServerStreamHandler,
        heartbeatInterval: Duration = .seconds(30)
    ) async throws {
        self.actorSystem = actorSystem
        self.output = output
        self.handler = handler
        self.heartbeatSequence = AsyncTimerSequence(
         interval: heartbeatInterval,
         clock: .continuous
       )
        self.heartbeatInterval = heartbeatInterval
        self.lastMessageDate = .now
        self.listenForMessagesFrom(input: input)
        self.heartbeat()
    }
    
    distributed public func sendMessage(_ message: Output) {
        self.output.yield(message)
    }

    private func heartbeat() {
        self.heartbeatListener = Task {
            for await interval in heartbeatSequence {
                let elapsedTime = interval.duration(to: lastMessageDate)
                if elapsedTime > self.heartbeatInterval {
                    self.disconnect()
                }
            }
        }
    }
    
    private func listenForMessagesFrom(
        input: AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, Input>
    ) {
        self.messageListener = Task {
            defer { self.disconnect() }
            for try await message in input {
                guard !Task.isCancelled else { disconnect(); return }
                self.lastMessageDate = .now
                try await self.handler?.handle(message, from: self)
            }
        }
    }
    
    private func disconnect() {
        Task {
            self.heartbeatListener?.cancel()
            self.heartbeatListener = .none
            self.messageListener?.cancel()
            self.messageListener = .none
            try? await self.handler?.disconnect(from: self)
            self.handler = .none
        }
    }
    
    deinit {
        self.heartbeatListener?.cancel()
        self.heartbeatListener = .none
        self.messageListener?.cancel()
        self.messageListener = .none
    }
}

public protocol ServerStreamHandler: Sendable {
    func handle<Input: Codable & Sendable, Output>(_ input: Input, from connection: ServerStream<Input, Output>) async throws
    func disconnect<Input, Output>(from: ServerStream<Input, Output>) async throws
    func connect<Input, Output>(to connection: ServerStream<Input, Output>) async throws
}
