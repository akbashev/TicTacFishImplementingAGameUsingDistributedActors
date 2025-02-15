import ServiceLifecycle
import DistributedCluster
import Hummingbird
import VirtualActors

struct Players: Service {
    
    var endpoint: Cluster.Endpoint { self.system.cluster.endpoint }
    let system: ClusterSystem
    let node: VirtualNode

    init(endpoint: Cluster.Endpoint) async {
        (self.system, self.node) = await ClusterSystem.startVirtualNode(named: "players-\(endpoint.description)") {
            $0.endpoint = endpoint
            $0.discovery = .clusterd
            $0.logging.logLevel = .info
            $0.installPlugins()
        }
    }
    
    func run() async throws {
        try await self.node.run()
    }
}
