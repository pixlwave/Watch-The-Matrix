import SwiftUI

/// A view that displays a two column reaction picker with 6 emoji to choose from.
/// Tapping on one of the emoji will react to the supplied message.
struct ReactionPicker: View {
    @EnvironmentObject var matrix: MatrixController
    @Binding var message: Message?
    
    var body: some View {
        // displays a two column reaction picker with 6 emoji to choose from
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                Button { react(with: reaction) } label: {
                    Text(reaction)
                        .font(.system(size: 21))
                }
            }
        }
    }
    
    /// Reacts to the message and dismisses the sheet.
    func react(with reaction: String) {
        if let message = message, let room = message.room {
            matrix.sendReaction(reaction, to: message, in: room)
        }
        
        // dismiss the sheet
        message = nil
    }
}
