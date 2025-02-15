//
//  Server.swift
//  TicTacFishPackage
//
//  Created by Jaleel Akbashev on 26.01.25.
//

import Distributed
import DistributedCluster
import Hummingbird
import OpenAPIRuntime
import OpenAPIHummingbird
import VirtualActors
import ServiceLifecycle
import EventSourcing

@main
struct App {
    static func main() async throws {
        let localhost = "127.0.0.1"
        let port = 2550
        let daemon = Daemon()
        let main = await Main(
            endpoint: .init(
                host: localhost,
                port: port
            )
        )
        let players = await Players(
            endpoint: .init(
                host: localhost,
                port: port + 2
            )
        )
        let services: [Service] = [daemon, main, players]
        return await withDiscardingTaskGroup { group in
            for service in services {
                group.addTask {
                    try? await service.run()
                }
            }
        }
    }
}

extension ClusterSystemSettings {
    mutating func installPlugins() {
        let plugins: [any Plugin] = [
            ClusterSingletonPlugin(),
            ClusterVirtualActorsPlugin(),
            ClusterJournalPlugin { _ in DebugStore() }
        ]
        for plugin in plugins { self += plugin }
    }
}

