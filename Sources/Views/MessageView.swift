import SwiftUI
import Matrix

/// A view that displays the contents of a message and it's sender, along with
/// any reactions and an indication of whether the message has been edited.
struct MessageView: View {
    @ObservedObject var message: Message
    @ObservedObject private var sender: Member    // observe the sender for updates to their display name
    
    let showSender: Bool
    let bubbleColor: Color
    
    init?(message: Message, showSender: Bool, bubbleColor: Color) {
        #warning("Can this init be made non-optional?")
        guard let sender = message.sender else { return nil }
        
        _message = ObservedObject(wrappedValue: message)
        _sender = ObservedObject(wrappedValue: sender)
        self.showSender = showSender
        self.bubbleColor = bubbleColor
    }
    
    var body: some View {
        // get the most recent edit and any reactions to the message
        let lastEdit = message.lastEdit
        let reactions = message.reactionsViewModel
        
        VStack(alignment: .leading, spacing: 2) {
            if showSender {
                // show the sender's name or id if requested
                Text(sender.displayName ?? sender.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
                    .padding(.horizontal, 4)    // match the indentation of the message text
            }
            
            Text(lastEdit?.body ?? message.body ?? "")
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 6).foregroundColor(bubbleColor))
            
            // show an indication that a message has been edited
            if lastEdit != nil {
                Text("Edited")
                    .font(.footnote)
            }
            
            if !reactions.isEmpty {
                ReactionsView(reactions: reactions)
                    .padding(.top, 2)
            }
        }
        .id(message.id)     // give the view it's message's id for programatic scrolling
        .accessibilityElement(children: .combine)
    }
}

struct MessageView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        MessageView(message: matrix.dataController.message(id: "0199-!test0:example.org")!,
                    showSender: true,
                    bubbleColor: .accentColor)
    }
}
