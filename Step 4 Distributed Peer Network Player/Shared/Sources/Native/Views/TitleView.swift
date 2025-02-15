/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View showing the "Tic Tac Fish" game title bar along with basic information about the game.
*/

import SwiftUI
import Client
import Types

struct TitleView: View {
    
    let selectedTeam: Team
    let mode: GameMode?
    
    var body: some View {
        titleText.fontWeight(.bold)
            .font(.largeTitle)
        
        switch mode {
        case .offline: Text("Playing offline\n")
        case .localNetwork: Text("Playing on local network\n")
        case .internet, .peerNetwork: Text("Playing online\n")
        case .none: Text("\n")
        }
    }
    
    var titleText: Text {
        switch selectedTeam {
        case .fish:
            return Text("Tic Tac Fish \(Team.fish.emojiArray.first!)")
        case .rodents:
            return Text("Tic Tac Rodent \(Team.rodents.emojiArray.first!)")
        }
    }
}

struct TitleView_Previews: PreviewProvider {
    static var previews: some View {
        TitleView(selectedTeam: .fish, mode: .offline)
    }
}
