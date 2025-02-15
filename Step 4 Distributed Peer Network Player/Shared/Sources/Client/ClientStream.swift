/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 */

import Types
import Distributed
import OpenAPIRuntime
import AsyncAlgorithms

public actor ClientStream<Input, Output>
    where Input: Codable & Sendable,
          Output: Codable & Sendable {
    
    var handler: (any ClientStreamHandler)?
    let tryToConnectTo: (AsyncStream<Input>) async throws -> AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, Output>
    let sendHeartbeat: (AsyncStream<Input>.Continuation) -> ()
    let heartbeatSequence: AsyncTimerSequence<ContinuousClock>
    
    var output: (AsyncStream<Input>.Continuation)?
    var messageListener: Task<Void, any Error>?
    var heartbeatSequencer: Task<Void, any Error>?
    private var connectionTask: Task<Void, any Error>?
    public var isConnecting: Bool { self.connectionTask != nil }

    public init(
        handler: any ClientStreamHandler,
        heartbeatInterval: Duration = .seconds(15),
        tryToConnectTo: @Sendable @escaping (AsyncStream<Input>) async throws -> AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, Output>,
        sendHeartbeat: @Sendable @escaping (AsyncStream<Input>.Continuation) -> ()
    ) {
        self.handler = handler
        self.tryToConnectTo = tryToConnectTo
        self.sendHeartbeat = sendHeartbeat
        self.heartbeatSequence = AsyncTimerSequence(
            interval: heartbeatInterval,
            clock: .continuous
        )
    }

    public nonisolated func connect() {
        Task {
            try await self.tryToConnect()
        }
    }
    
    private func tryToConnect() async throws {
        guard self.messageListener == nil, self.connectionTask == nil else { return }
        self.connectionTask = Task {
            defer { self.connectionTask = nil }
            let (stream, continuation) = AsyncStream<Input>.makeStream()
            continuation.onTermination = { termination in
                self.disconnect()
            }
            /// It is important to note that URLSession will return the stream only after at least some bytes of the body have been received (see [comment](https://github.com/apple/swift-openapi-urlsession/blob/main/Tests/OpenAPIURLSessionTests/URLSessionBidirectionalStreamingTests/URLSessionBidirectionalStreamingTests.swift#L193-L206)).
            /// Workaround for now is to send a `connecting` or some other kind of heartbeat message first.
            self.heartbeat(output: continuation)
            self.output = continuation
            do {
                let response = try await self.tryToConnectTo(stream)
                self.listenForMessagesFrom(input: response)
            } catch {
                self.disconnect()
            }
        }
    }

    private func heartbeat(output: AsyncStream<Input>.Continuation) {
        self.sendHeartbeat(output)
        self.heartbeatSequencer = Task {
            for await _ in heartbeatSequence { sendHeartbeat(output) }
        }
    }
    
    private func listenForMessagesFrom(
        input: AsyncThrowingMapSequence<JSONLinesDeserializationSequence<HTTPBody>, Output>
    ) {
        self.messageListener = Task {
            defer { self.disconnect() }
            for try await message in input {
                guard !Task.isCancelled else { return }
                try await self.handler?.handle(message, from: self)
            }
        }
    }
    
    public nonisolated func disconnect() {
        Task { await self.removeAll() }
    }
    
    private func removeAll() {
        self.connectionTask?.cancel()
        self.connectionTask = .none
        self.output = nil
        self.heartbeatSequencer?.cancel()
        self.heartbeatSequencer = .none
        self.messageListener?.cancel()
        self.messageListener = .none
    }
    
    public nonisolated func sendMessage(_ message: Input) {
        Task { await self.send(input: message)}
    }
    
    private func send(input: Input) {
        self.output?.yield(input)
    }
    
    deinit {
        self.output = nil
        self.heartbeatSequencer?.cancel()
        self.heartbeatSequencer = .none
        self.messageListener?.cancel()
        self.messageListener = .none
        self.handler = nil
    }
}

public protocol ClientStreamHandler: Sendable {
    func handle<Input, Output>(_ output: Output, from connection: ClientStream<Input, Output>) async throws
}
