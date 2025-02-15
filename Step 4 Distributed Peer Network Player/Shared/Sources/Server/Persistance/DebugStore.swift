import EventSourcing
import Foundation

public final class DebugStore: EventStore, Sendable {
    
    private let persistence: MemoryPersistence
    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder: JSONEncoder = JSONEncoder()
    
    public func persistEvent<Event: Sendable & Codable>(_ event: Event, id: String) async throws {
        let data = try encoder.encode(event)
        try await self.persistence.addEvent(data, id: id)
    }
    
    public func eventsFor<Event: Sendable & Codable>(id: String) async -> [Event] {
        await self.persistence.eventsFor(id: id).compactMap(decoder.decode)
    }
    
    public init(persistence: MemoryPersistence = .shared) {
        self.persistence = persistence
    }
}


extension JSONDecoder {
    func decode<T: Decodable>(_ data: Data) -> T? {
        try? self.decode(T.self, from: data)
    }
}
