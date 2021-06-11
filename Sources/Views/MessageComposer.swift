import SwiftUI
import FlickTypeKit

/// A view that displays a text field to send messages from.
struct MessageComposer: View {
    @EnvironmentObject private var matrix: MatrixController
    
    let room: Room
    @State private var message = ""
    
    var body: some View {
        FlickTypeTextEditor(title: "Message", text: $message, onCommit: send)
    }
    
    func send() {
        guard !message.isEmpty else { return }
        
        matrix.sendMessage(message, in: room)
        message = ""
    }
}
