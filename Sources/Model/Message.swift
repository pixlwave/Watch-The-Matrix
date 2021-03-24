import Matrix
import CoreData

extension Message {
    var reactionsRequest: NSFetchRequest<Reaction> {
        let request: NSFetchRequest<Reaction> = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "message == %@", self)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reaction.key, ascending: true)]
        return request
    }
    
    convenience init?(roomEvent: RoomEvent, context: NSManagedObjectContext) {
        guard let body = roomEvent.content.body else { return nil }
        
        self.init(context: context)
        self.body = body
        self.id = roomEvent.eventID
        self.sender = Member(userID: roomEvent.sender, context: context);   #warning("placeholder")
        self.date = roomEvent.date
    }
}
