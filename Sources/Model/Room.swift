import Matrix
import CoreData

extension Room {
    /// A list formatter that's used to generate a room name from (some of) the members of the room.
    static let nameFormatter = ListFormatter()
    
    /// Whether or not there are any older messages for the room available on the server.
    #warning("Checking whether a previous batch exists doesn't appear to be the correct method.")
    var hasMoreMessages: Bool { previousBatch != nil }
    
    /// A request that will fetch all of the messages belonging to this room.
    var messagesRequest: NSFetchRequest<Message> {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "room == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: true)]
        return request
    }
    
    /// The last message in the room.
    var lastMessage: Message? {
        // create a request for one item, ignoring redacted messages and sorted by date descending
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "room == %@", self),
            NSPredicate(format: "redactions.@count == 0")
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: false)]
        request.fetchLimit = 1
        
        // return the item from the request
        return try? managedObjectContext?.fetch(request).first
    }
    
    /// The number of members in the room.
    var memberCount: Int {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "ANY rooms == %@", self)
        return (try? managedObjectContext?.count(for: request)) ?? 0
    }
    
    /// Generate a name from the members in this room ignoring the user passed in.
    func generateName(for userID: String?) -> String {
        // create a request for up to 5 users excluding the current user
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "ANY rooms == %@", self),
            NSPredicate(format: "id != %@", userID ?? "")
        ])
        request.fetchLimit = 5
        
        // fetch the names of the members
        let fetchedMembers = (try? managedObjectContext?.fetch(request)) ?? []
        let names = fetchedMembers.compactMap { $0.displayName ?? $0.id }
        
        guard !names.isEmpty else {
            return NSLocalizedString("Empty Room", comment: "There is no-one else in the room")
        }
        
        // generate a room name using a list formatter
        guard let generatedName = Room.nameFormatter.string(from: names), !generatedName.isEmpty else {
            return NSLocalizedString("Unknown Room", comment: "A room name could not be generated")
        }
        
        return generatedName
    }
    
    /// Deletes all of the messages belonging to the room. In turn, the deletion will cascade
    /// down to any edits, reactions and redactions in the room. This function uses a batch
    /// delete request so won't have a visible effect until the managed object context is saved.
    func deleteAllMessages() {
        let request: NSFetchRequest<NSFetchRequestResult> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "room == %@", self)
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        _ = try? managedObjectContext?.execute(batchDeleteRequest)
    }
}
