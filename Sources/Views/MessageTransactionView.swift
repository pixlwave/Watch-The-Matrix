import SwiftUI

/// A view that displays a local echo for an outgoing message along with
/// any errors that may have occurred.
struct MessageTransactionView: View {
    @EnvironmentObject var matrix: MatrixController
    @ObservedObject var transaction: MessageTransaction
    
    @State private var isPresentingError = false
    
    var body: some View {
        HStack {
            MessageBubble(text: transaction.originalMessage, color: .accentColor)
                .foregroundColor(transaction.isDelivered ? .primary : .secondary)
            
            if transaction.error != nil {
                Button { isPresentingError = true } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert(isPresented: $isPresentingError) {
            Alert(title: Text("Failed to Send"),
                  primaryButton: .default(Text("Retry"), action: retry),
                  secondaryButton: .destructive(Text("Discard"), action: discard))
        }
    }
    
    /// Attempts to retry sending a failed transaction.
    func retry() {
        matrix.retryTransaction(transaction)
    }
    
    /// Removes the unsent message from the transaction store.
    func discard() {
        TransactionManager.shared.remove(transaction)
    }
}

#Preview {
    let transaction = MessageTransaction(id: "1", message: "Hello, World!", roomID: "!1:example.com")
    MessageTransactionView(transaction: transaction)
}
