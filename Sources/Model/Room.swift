import Matrix
import CoreData

extension Room {
    var hasMoreMessages: Bool { previousBatch != nil }
    
    var messagesRequest: NSFetchRequest<Message> {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "room == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: true)]
        return request
    }
    
    var lastMessageRequest: NSFetchRequest<Message> {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "room == %@", self),
            NSPredicate(format: "redactions.@count == 0")
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.date, ascending: false)]
        request.fetchLimit = 1
        return request
    }
    
    var memberCount: Int {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "ANY rooms == %@", self)
        return (try? managedObjectContext?.count(for: request)) ?? 0
    }
    
    func generateName(for userID: String?) -> String {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "ANY rooms == %@", self),
            NSPredicate(format: "id != %@", userID ?? "")
        ])
        request.fetchLimit = 5
        
        let fetchedMembers = (try? managedObjectContext?.fetch(request)) ?? []
        return fetchedMembers.compactMap { $0.displayName ?? $0.id }.joined(separator: ", ")
    }
}
