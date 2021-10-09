import SwiftUI
import FlickTypeKit

/// A view that displays a text field to send messages from.
struct MessageComposer: View {
    @AppStorage("flickTypeMode") private var flickTypeMode: FlickType.Mode = .off
    
    @EnvironmentObject private var matrix: MatrixController
    
    let room: Room
    @State private var message = ""
    @State private var shouldClearMessage = false
    
    var body: some View {
        switch flickTypeMode {
        case .ask, .always:
            FlickTypeTextEditor("Message", text: $message, mode: flickTypeMode, onCommit: send)
        case .off:
            TextField("Message", text: $message)
                .submitLabel(.send)
                .onSubmit(send)
                .onChange(of: shouldClearMessage, perform: clearMessage)
        }
    }
    
    func send() {
        guard !message.isEmpty else { return }
        
        matrix.sendMessage(message, in: room)
        
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
