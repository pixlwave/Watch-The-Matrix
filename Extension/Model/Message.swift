import Matrix
import CoreData

extension Message {
    convenience init?(roomEvent: RoomEvent, context: NSManagedObjectContext) {
        guard let body = roomEvent.content.body else { return nil }
        
        self.init(context: context)
        self.body = body
        self.id = roomEvent.eventID
        self.sender = Member(userID: roomEvent.sender, context: context);   #warning("placeholder")
        self.date = Date(timeIntervalSince1970: roomEvent.timestamp / 1000)
    }
}
