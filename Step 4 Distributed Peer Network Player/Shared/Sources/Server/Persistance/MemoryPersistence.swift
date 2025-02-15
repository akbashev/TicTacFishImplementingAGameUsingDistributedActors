import Foundation

public actor MemoryPersistence {
    
    public static let shared = MemoryPersistence()
    
    public enum PersistenceError: Error {
        case documentNotFound
        case documentAlreadyExists
    }
    
    public var documents: [String: Data] = [:]
    public var events: [String: [Data]] = [:]
    
    public func getDocument(id: String) throws -> Data {
        guard let document = self.documents[id] else {
            throw PersistenceError.documentNotFound
        }
        return document
    }
    
    public func getAllDocuments() -> [Data] {
        self.documents.values.map { $0 }
    }
    
    public func saveDocument(_ document: Data, id: String) throws {
        guard self.documents[id] == nil else {
            throw PersistenceError.documentAlreadyExists
        }
        self.documents[id] = document
    }
    
    public func addEvent(_ event: Data, id: String) throws {
        self.events[id, default: []].append(event)
    }
    
    public func eventsFor(id: String) -> [Data] {
        self.events[id] ?? []
    }
}
