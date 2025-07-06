import SwiftUI

/// A view that displays a text field to send messages from.
struct MessageComposer: View {
    @Environment(MatrixController.self) private var matrix
    
    let room: Room
    var messageToReplyTo: Message?
    var completion: (() -> Void)?
    
    @State private var message = ""
    
    var placeholder: LocalizedStringKey {
        messageToReplyTo == nil ? "Message" : "Reply"
    }
    
    var body: some View {
        TextField(placeholder, text: $message)
            .submitLabel(.send)
            .onSubmit(send)
    }
    
    func send() {
        guard !message.isEmpty else { return }
        
        matrix.sendMessage(message, in: room, asReplyTo: messageToReplyTo)
        completion?()
        
        message = ""
    }
}
