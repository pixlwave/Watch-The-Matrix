import SwiftUI

/// A view that displays a local echo for an outgoing message along with
/// any errors that may have occured.
struct MessageTransactionView: View {
    @ObservedObject var transaction: MessageTransaction
    
    var body: some View {
        HStack {
            MessageBubble(text: transaction.message, color: .accentColor)
                .foregroundColor(transaction.isDelivered ? .primary : .secondary)
            
            if transaction.error != nil {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
            }
        }
    }
}
