import SwiftUI
import Matrix

/// A view that displays the contents of a message and it's sender, along with
/// any reactions and an indication of whether the message has been edited.
struct MessageView: View {
    @ObservedObject var message: Message
    @ObservedObject private var sender: Member    // observe the sender for updates to their display name
    
    let showSender: Bool
    let bubbleColor: Color
    let isCurrentUser: Bool
    
    init?(message: Message, showSender: Bool, isCurrentUser: Bool) {
        #warning("Can this init be made non-optional?")
        guard let sender = message.sender else { return nil }
        
        _message = ObservedObject(wrappedValue: message)
        _sender = ObservedObject(wrappedValue: sender)
        self.showSender = showSender
        self.bubbleColor = isCurrentUser ? .accentColor : Color(.darkGray)
        self.isCurrentUser = isCurrentUser
    }
    
    var body: some View {
        // get the most recent edit and any reactions to the message
        let lastEdit = message.lastEdit
        let reactions = message.reactionsViewModel
        let alignment: HorizontalAlignment = isCurrentUser ? .trailing : .leading
        
        VStack(alignment: alignment, spacing: 2) {
            if showSender {
                // show the sender's name or id if requested
                Text(sender.displayName ?? sender.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
                    .padding(.horizontal, 4)    // match the indentation of the message text
            }
            
            MessageAligner(isCurrentUser: isCurrentUser) {
                if message.type == .image && message.mediaURL != nil {
                    ImageBubble(message: message)
                } else {
                    MessageBubble(text: lastEdit?.body ?? message.body ?? "",
                                  footnote: lastEdit.map { _ in "Edited" },     // indicate that the message has been edited
                                  color: bubbleColor,
                                  alignment: alignment)
                }
            }
            
            if !reactions.isEmpty {
                ReactionsView(reactions: reactions, alignment: alignment)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MessageView_Previews: PreviewProvider {
    static let matrix = MatrixController.preview
    
    static var previews: some View {
        ScrollView {
            VStack {
                MessageView(message: matrix.dataController.message(id: "0199-!test0:example.org")!,
                            showSender: true,
                            isCurrentUser: false)
                MessageView(message: matrix.dataController.message(id: "0199-!test0:example.org")!,
                            showSender: true,
                            isCurrentUser: true)
            }
        }
    }
}
