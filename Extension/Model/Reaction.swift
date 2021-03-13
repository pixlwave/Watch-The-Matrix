import Matrix
import CoreData

extension Reaction {
    convenience init?(roomEvent: RoomEvent, context: NSManagedObjectContext) {
        guard
            let relationship = roomEvent.content.relationship,
            let key = relationship.key,
            let messageID = relationship.eventID
        else { return nil }
        
        self.init(context: context)
        self.key = key
        self.id = roomEvent.eventID
        self.messageID = messageID
        self.sender = Member(userID: roomEvent.sender, context: context);   #warning("placeholder")
        self.date = roomEvent.date
    }
}
