import Foundation

/// An obervable class to hold all transactions associated with a specific room.
class TransactionStore: ObservableObject {
    /// All of the message transactions contained within this store.
    @Published var messages: [MessageTransaction] = []
    
    /// Add a new `MessageTransaction` to this store.
    func add(_ message: MessageTransaction) {
        messages.append(message)
    }
    
    /// Remove the transaction that corresponds to the remote echo `Message`.
    func remove(_ message: Message) {
        messages.removeAll { $0.eventID == message.id }
    }
}
