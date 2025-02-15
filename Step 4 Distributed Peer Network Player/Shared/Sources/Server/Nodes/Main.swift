import ServiceLifecycle
import DistributedCluster
import Hummingbird

struct Main: Service {
    
    var endpoint: Cluster.Endpoint { self.system.cluster.endpoint }
    let system: ClusterSystem
    
    init(endpoint: Cluster.Endpoint) async {
        self.system = await ClusterSystem("main") {
            $0.endpoint = .init(host: "127.0.0.1", port: 2550)
            $0.discovery = .clusterd
            $0.logging.logLevel = .info
            $0.installPlugins()
        }
    }
    
    func run() async throws {
        let api = Api(actorSystem: self.system)
        let router = Router()
        try api.registerHandlers(on: router)
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(
                    system.cluster.node.host,
                    port: 8080
                ),
                serverName: system.name
            )
        )
        let lobby = try await system.singleton.host(name: "matchmaking_lobby") { actorSystem in
            GameLobby(actorSystem: actorSystem)
        }
        try await app.run()
    }
}
