import Foundation

/// An obervable class to hold all transactions associated with a specific room.
class TransactionStore: ObservableObject {
    /// All of the message transactions contained within this store.
    @Published var messages: [MessageTransaction] = []
    
    /// Add a new `MessageTransaction` to this store.
    func add(_ message: MessageTransaction) {
        messages.append(message)
    }
    
    /// Remove the transaction with the specified transaction ID.
    func removeTransaction(with id: String) {
        messages.removeAll { $0.id == id }
    }
    
    /// Remove the specified transaction.
    func remove(_ transaction: MessageTransaction) {
        removeTransaction(with: transaction.id)
    }
}
