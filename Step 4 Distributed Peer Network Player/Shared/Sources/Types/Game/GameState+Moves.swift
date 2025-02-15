/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Types which are used to model the game state.
*/
public extension GameMove {
  var character: String {
    self.team.select(self.teamCharacterId)
  }
}

/// Represents the state of a tic-tac-fish game, including all the moves currently made and the player identities.
public extension GameState {
    
    static let availablePositions = (0..<9).map { $0 }
    static let winPatterns: Set<Set<Int>> = [
        // row wins
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        // column wins
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        // cross wins
        /* \ */ [0, 4, 8],
        /* / */ [6, 4, 2]
    ]

    
    // - MARK: Making and inspecting moves
    
    mutating func mark(_ move: GameMove) throws {
        guard self.availablePositions.contains(move.position) else {
            throw IllegalMoveError(move: move)
        }
        
        self.moves.append(move)
        self.currentPlayerId = move.playerId != playerOne.playerId ? playerOne.playerId : playerTwo.playerId
        self.result = self.checkWin().flatMap { .init(result: $0) }
    }
    
    func at(position: Int) -> GameMove? {
        moves.first(where: { $0.position == position })
    }
    
    var availablePositions: [Int] {
        let positions = self.moves.map { $0.position }
        return Self.availablePositions.filter { !positions.contains($0) }
    }
    
    var movesMade: Int {
        self.moves.count
    }

    // - MARK: End game conditions
    
    private func checkWin() -> GameResult? {
        // did player 1 win?
        if checkWin(of: self.playerOne.playerId) {
            return .init(.Win(.init(player: playerOne)))
        }
        
        // did player 2 win?
        if checkWin(of: playerTwo.playerId) {
            return .init(.Win(.init(player: playerTwo)))
        }
        
        // was it a draw?
        if self.availablePositions.count == 0 {
            return .init(.Draw(.init()))
        }
        
        // game isn't complete yet
        return nil
    }
    
    func isWinningField(_ position: Int) -> Bool {
        guard checkWin() != nil else {
            return false
        }
        
        for pattern in Self.winPatterns {
            guard pattern.contains(position) else {
                // this position cannot be part of this winning pattern
                continue
            }
            
            assert(pattern.count == 3) // guarantees that the !-unwraps below are safe
            guard let move1 = at(position: pattern.first!) else {
                continue
            }
            guard let move2 = at(position: pattern.dropFirst(1).first!) else {
                continue
            }
            guard move1.playerId == move2.playerId else {
                continue
            }
            guard let move3 = at(position: pattern.dropFirst(2).first!) else {
                continue
            }
            
            if move2.playerId == move3.playerId {
                // yes, this position was part of this pattern, and this pattern has won
                return true
            } // else, this position is
        }
        
        return false
    }
    
    func checkWin(of playerId: PlayerIdentity) -> Bool {
        let moves = Set(self.moves.map { $0 })
        let playerMoves = Set(moves.filter { $0.playerId == playerId })
        let playerPositions = playerMoves.map(\.position)
        
        for pattern in Self.winPatterns where pattern.isSubset(of: playerPositions) {
            return true
        }
        
        return false
    }
    
}
/// Thrown when an illegal move was attempted, e.g. storing a move in a field that already has a move assigned to it.
public struct IllegalMoveError: Error {
    let move: GameMove
}
