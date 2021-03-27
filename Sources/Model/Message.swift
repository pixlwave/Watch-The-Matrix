import Matrix
import CoreData

extension Message {
    private var reactionsRequest: NSFetchRequest<Reaction> {
        let request: NSFetchRequest<Reaction> = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reaction.date, ascending: true)]
        return request
    }
    
    var reactionsViewModel: [(key: String, count: Int)] {
        // get all unique reaction keys
        let reactions = (try? managedObjectContext?.fetch(reactionsRequest)) ?? []
        let keys = NSOrderedSet(array: reactions.compactMap { $0.key })
        
        // return as an array of tuples containing each key and it's count
        return keys.compactMap {
            let key = $0 as! String
            let count = reactions.filter { $0.key == key }.count
            
            return (key: key, count: count)
        }
    }
    
    var lastEdit: Edit? {
        let request: NSFetchRequest<Edit> = Edit.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Edit.date, ascending: false)]
        request.fetchLimit = 1
        
        return try? managedObjectContext?.fetch(request).first
    }
    
    private var redactionsRequest: NSFetchRequest<Redaction> {
        let request: NSFetchRequest<Redaction> = Redaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        return request
    }
    
    var isRedacted: Bool {
        // check if there is at least 1 redaction
        return (try? managedObjectContext?.count(for: redactionsRequest)) ?? 0 > 0
    }
}
