import SwiftUI

/// A view that displays a two column reaction picker with 6 emoji to choose from.
/// Tapping on one of the emoji will react to the supplied message.
struct ReactionPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var matrix: MatrixController
    
    let message: Message
    let room: Room
    
    var body: some View {
        ScrollView {
            // displays a two column reaction picker with 6 emoji to choose from
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                ForEach(["👍", "👎", "😄", "😭", "❤️", "🤯"], id: \.self) { reaction in
                    Button { react(with: reaction) } label: {
                        Text(reaction)
                            .font(.system(size: 21))
                    }
                }
            }
            
            Divider()
                .opacity(0)
            
            MessageComposer(room: room, messageToReplyTo: message) {
                dismiss()
            }
            .multilineTextAlignment(.center)
        }
    }
    
    /// Reacts to the message and dismisses the sheet.
    func react(with reaction: String) {
        matrix.sendReaction(reaction, to: message, in: room)
        dismiss()
    }
}

struct Previews_ReactionPicker_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        let message = matrix.dataController.message(id: "0199-!test0:example.org")!
        ReactionPicker(message: message, room: message.room!)
    }
}
