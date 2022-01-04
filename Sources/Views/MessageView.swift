import SwiftUI
import Matrix

/// A view that displays the contents of a message and it's sender, along with
/// any reactions and an indication of whether the message has been edited.
struct MessageView: View {
    @EnvironmentObject private var matrix: MatrixController
    
    @ObservedObject var message: Message
    @ObservedObject private var sender: Member    // observe the sender for updates to their display name
    
    let showSender: Bool
    let bubbleColor: Color
    let alignment: HorizontalAlignment
    let isCurrentUser: Bool
    
    init?(message: Message, showSender: Bool, isCurrentUser: Bool) {
        #warning("Can this init be made non-optional?")
        guard let sender = message.sender else { return nil }
        
        _message = ObservedObject(wrappedValue: message)
        _sender = ObservedObject(wrappedValue: sender)
        self.showSender = showSender
        self.bubbleColor = isCurrentUser ? .accentColor : Color(.darkGray)
        self.alignment = isCurrentUser ? .trailing : .leading
        self.isCurrentUser = isCurrentUser
    }
    
    var senderName: some View {
        // show the sender's name or id if requested
        Text(sender.displayName ?? sender.id ?? "")
            .font(.footnote)
            .foregroundColor(.primary.opacity(0.667))
            .padding(.horizontal, 4)    // match the indentation of the message text
            .padding(.vertical, 2)
    }
    
    @ViewBuilder
    var header: some View {
        let insetEdge: Edge.Set = isCurrentUser ? .trailing : .leading
        let replyQuote = message.replyQuote
        
        VStack(alignment: alignment, spacing: 0) {
            replyQuote.map {
                MessageBubble(text: $0, color: .secondary.opacity(0.667), isReply: true)
                    .padding(.top, 8)
            }
            
            HStack(spacing: 0) {
                if showSender && alignment == .trailing {
                    senderName
                }
                
                replyQuote.map { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 4, height: 16)
                        .padding(insetEdge)
                        .padding(.vertical, 4)
                }

                if showSender && alignment == .leading {
                    senderName
                }
            }
        }
    }
    
    var body: some View {
        // get the most recent edit and any reactions to the message
        let lastEdit = message.lastEdit
        let reactions = message.aggregatedReactions(for: matrix.userID ?? "")
        
        VStack(alignment: alignment, spacing: 0) {
            header
            
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
                    .padding(.top, 4)
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
