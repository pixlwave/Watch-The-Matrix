import SwiftUI
import FlickTypeKit

/// A view that displays a text field to send messages from.
struct MessageComposer: View {
    @AppStorage("flickTypeMode") private var flickTypeMode: FlickType.Mode = .off
    
    @EnvironmentObject private var matrix: MatrixController
    
    let room: Room
    var messageToReplyTo: Message? = nil
    var completion: (() -> Void)? = nil
    
    @State private var message = ""
    @State private var shouldClearMessage = false
    
    var placeholder: LocalizedStringKey {
        messageToReplyTo == nil ? "Message" : "Reply"
    }
    
    var body: some View {
        // FlickType fails when presented from a sheet so disable it for replies
        if flickTypeMode == .off || messageToReplyTo != nil {
            TextField(placeholder, text: $message)
                .submitLabel(.send)
                .onSubmit(send)
                .onChange(of: shouldClearMessage, perform: clearMessage)
        } else {
            FlickTypeTextEditor(placeholder, text: $message, mode: flickTypeMode, onCommit: send)
        }
    }
    
    func send() {
        guard !message.isEmpty else { return }
        
        matrix.sendMessage(message, in: room, asReplyTo: messageToReplyTo)
        completion?()
        
        // workaround for onSubmit in watchOS 8 which fails
        // to clear the message when updated directly here.
        shouldClearMessage = true
    }
    
    func clearMessage(_ shouldClear: Bool) {
        guard shouldClear else { return }
        
        shouldClearMessage = false
        message = ""
    }
}
