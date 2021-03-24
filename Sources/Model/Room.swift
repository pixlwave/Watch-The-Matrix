import Matrix
import CoreData

extension Room {
    var hasMoreMessages: Bool { previousBatch != nil }
    
    var allMessages: [Message] {
        messages?.allObjects as? [Message] ?? []
    }
    
    var messagesRequest: NSFetchRequest<Message> {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "room == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: true)]
        return request
    }
    
    var lastMessageRequest: NSFetchRequest<Message> {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "room == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: false)]
        request.fetchLimit = 1
        return request
    }
    
    var allMembers: [Member] {
        members?.allObjects as? [Member] ?? []
    }
    
    func generateName(for userID: String?) -> String {
        allMembers.filter { $0.id != userID }.compactMap { $0.displayName ?? $0.id }.joined(separator: ", ")
    }
}
