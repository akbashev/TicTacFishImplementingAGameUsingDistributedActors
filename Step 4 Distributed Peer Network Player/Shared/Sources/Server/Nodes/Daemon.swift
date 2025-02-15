import DistributedCluster
import ServiceLifecycle

struct Daemon: Service {
    func run() async throws {
        let daemon = await ClusterSystem.startClusterDaemon {
            $0.installPlugins()
            $0.logging.logLevel = .info
        }
        try await daemon.terminated
    }
}
