/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The main view of the application from which the user can select a game mode, and team to play as.
*/

import SwiftUI
import Client
import Types

public struct MainMenuView: View {
    
    @AppStorage("playerId") private var id: PlayerIdentity = UUID().uuidString
    @AppStorage("playerName") private var name: String = ""
    @State private var selectedGameMode: GameMode?
    @State private var selectedTeam: Team = .fish
    let client: Client
    
    public init(client: Client) {
        self.client = client
    }

    public var body: some View {
        NavigationView {
            VStack {
                TitleView(selectedTeam: selectedTeam, mode: nil)
                Text("The distributed actor TicTacToe game!")
                    .font(.title2)
                
                Spacer()
                
                HStack {
                    Text("Name:")
                    TextField("Enter name", text: $name)
                }
                
                VStack {
                    Text("Select Team:")
                    Picker("Select Team:", selection: $selectedTeam) {
                        Text("Fish (\(Team.fish.emojiArray.joined(separator: "")))").tag(Team.fish)
                        Text("Rodents (\(Team.rodents.emojiArray.joined(separator: "")))").tag(Team.rodents)
                    }.pickerStyle(.segmented)
                }
                
                Spacer()
                VStack {
                    Button("Play with all your friends") {
                        selectedGameMode = .peerNetwork
                    }
                    .bold()
                    .disabled(self.name.isEmpty)
                    Text("(Peer to peer network)")
                        .fontWeight(.light)
                }

                // Other play modes here in the future...
                Spacer()
            }
            .padding(16)
            .navigate(
                using: $selectedGameMode,
                using: $selectedTeam,
                destination: makeLobbyView
            )
        }
    }
    
    func makeLobbyView(mode: GameMode, team: Team) -> some View {
        LobbyView(
            player: Player(
                playerId: self.id,
                name: self.name,
                team: team
            ),
            client: self.client
        )
    }
}

// - MARK: Navigation helpers

extension NavigationLink where Label == EmptyView {
    init?<Value1, Value2>(
        _ binding1: Binding<Value1?>,
        _ binding2: Binding<Value2>,
        @ViewBuilder destination: (Value1, Value2) -> Destination
    ) {
        guard let value1 = binding1.wrappedValue else {
            return nil
        }
        let value2 = binding2.wrappedValue

        let isActive = Binding(
            get: {
                true
            },
            set: { newValue in
                if !newValue {
                    binding1.wrappedValue = nil
                }
            }
        )

        self.init(
            destination: destination(value1, value2),
            isActive: isActive,
            label: EmptyView.init
        )
    }
}

extension View {
    @ViewBuilder
    func navigate<Value1, Value2, Destination: View>(
        using binding1: Binding<Value1?>,
        using binding2: Binding<Value2>,
        @ViewBuilder destination: (Value1, Value2) -> Destination
    ) -> some View {
        background(NavigationLink(binding1, binding2, destination: destination))
    }
}

extension NavigationLink where Label == EmptyView {
    init?<Value1>(
        _ binding1: Binding<Value1?>,
        @ViewBuilder destination: (Value1) -> Destination
    ) {
        guard let value1 = binding1.wrappedValue else {
            return nil
        }
        let isActive = Binding(
            get: {
                true
            },
            set: { newValue in
                if !newValue {
                    binding1.wrappedValue = nil
                }
            }
        )

        self.init(
            destination: destination(value1),
            isActive: isActive,
            label: EmptyView.init
        )
    }
}

extension View {
    @ViewBuilder
    func navigate<Value1, Destination: View>(
        using binding1: Binding<Value1?>,
        @ViewBuilder destination: (Value1) -> Destination
    ) -> some View {
        background(NavigationLink(binding1, destination: destination))
    }
}
