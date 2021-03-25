import Matrix
import CoreData

extension Message {
    var reactionsRequest: NSFetchRequest<Reaction> {
        let request: NSFetchRequest<Reaction> = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reaction.key, ascending: true)]
        return request
    }
    
    var lastEditRequest: NSFetchRequest<Edit> {
        let request: NSFetchRequest<Edit> = Edit.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Edit.date, ascending: false)]
        request.fetchLimit = 1
        return request
    }
    
    var redactionsRequest: NSFetchRequest<Redaction> {
        let request: NSFetchRequest<Redaction> = Redaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        return request
    }
    
    var isRedacted: Bool {
        // check if there is at least 1 redaction
        return (try? managedObjectContext?.count(for: redactionsRequest)) ?? 0 > 0
    }
}
