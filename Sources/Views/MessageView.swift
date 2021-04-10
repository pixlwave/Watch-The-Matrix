import SwiftUI
import Matrix

/// A view that displays the contents of a message and it's sender, along with
/// any reactions and an indication of whether the message has been edited.
struct MessageView: View {
    @ObservedObject var message: Message
    @ObservedObject private var sender: Member    // observe the sender for updates to their display name
    
    let showSender: Bool
    
    init?(message: Message, showSender: Bool) {
        #warning("Can this init be made non-optional?")
        guard let sender = message.sender else { return nil }
        
        _message = ObservedObject(wrappedValue: message)
        _sender = ObservedObject(wrappedValue: sender)
        self.showSender = showSender
    }
    
    var body: some View {
        // get the most recent edit and any reactions to the message
        let lastEdit = message.lastEdit
        let reactions = message.reactionsViewModel
        
        VStack(alignment: .leading) {
            Text(lastEdit?.body ?? message.body ?? "")
            
            // show an indication that a message has been edited
            if lastEdit != nil {
                Text("Edited")
                    .font(.footnote)
            }
            
            if showSender {
                // show the sender's name or id if requested
                Text(sender.displayName ?? sender.id ?? "")
                    .font(.footnote)
                    .foregroundColor(Color.primary.opacity(0.667))
                    .accessibilitySortPriority(1)
            }
            
            if !reactions.isEmpty {
                // a horizontally scrolling list of any reactions to the message
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0..<reactions.count, id: \.self) { index in
                            HStack {
                                Text(reactions[index].key)
                                Text(String(reactions[index].count))
                                    .font(.footnote)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(Capsule().foregroundColor(.black))
                            .accessibilityElement(children: .combine);      #warning("This accessibility element isn't surfaced.")
                        }
                    }
                }
            }
        }
        .id(message.id)     // give the view it's message's id for programatic scrolling
        .accessibilityElement(children: .combine)
    }
}
