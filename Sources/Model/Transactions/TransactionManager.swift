import Foundation

/// A class that handles the creation of transactions when sending events.
class TransactionManager {
    /// The shared singleton manager object.
    static let shared = TransactionManager()
    
    /// A dictionary containing transaction stores, keyed by the room ID that they belong to.
    private var TransactionStores = [String: TransactionStore]()
    
    /// An integer representing the number of events that have been sent.
    /// This is used when generating a transaction ID.
    private var transactionNumber = UserDefaults.standard.integer(forKey: "transactionNumber") {
        didSet { UserDefaults.standard.set(transactionNumber, forKey: "transactionNumber") }
    }
    
    private init() { }
    
    /// Returns a `TransactionStore` for the requested room ID, creating it if necessary.
    func store(for roomID: String) -> TransactionStore {
        // ensure an array exists for the room
        if TransactionStores[roomID] == nil {
            TransactionStores[roomID] = TransactionStore()
        }
        
        return TransactionStores[roomID]!
    }
    
    /// Generates a new unique transaction ID for this device session.
    func generateTransactionID() -> String {
        #warning("MXTools uses a random prefix here instead of user defaults 🤔.")
        let id = String(transactionNumber, radix: 36)
        
        // Currently only used from the main thread, but potentially a good place try out actors when they land?
        transactionNumber &+= 1
        
        return id
    }
}
