import Foundation
import CoreData
import Matrix

class DataController {
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    init(inMemory: Bool = false) {
        guard
            let modelURL = Bundle.main.url(forResource: "Matrix", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Unable to find Core Data Model") }
        
        container = NSPersistentContainer(name: "Matrix", managedObjectModel: managedObjectModel)
        #warning("This works for properties, but may not be suitable for relationships.")
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error { fatalError("Core Data container error: \(error)") }
        }
    }
    
    func count<T>(for request: NSFetchRequest<T>) -> Int {
        (try? viewContext.count(for: request)) ?? 0
    }
    
    
    // MARK: Create Objects
    func createRoom(id: String, joinedRoom: JoinedRooms) -> Room {
        let room = Room(context: viewContext)
        room.id = id
        
        process(events: joinedRoom.timeline.events, in: room)
        room.previousBatch = joinedRoom.timeline.previousBatch
        
        return room
    }
    
    func createMessage(id: String) -> Message? {
        let message = Message(context: viewContext)
        message.id = id
        
        return message
    }
    
    /// Creates a message from a Matrix `RoomEvent`. If the message already exists
    /// this method will overwrite it's properties to match the `RoomEvent`.
    func createMessage(roomEvent: RoomEvent) -> Message? {
        guard let body = roomEvent.content.body else { return nil }
        
        let message = Message(context: viewContext)
        message.body = body
        message.id = roomEvent.eventID
        message.sender = user(id: roomEvent.sender) ?? createUser(id: roomEvent.sender)
        message.date = roomEvent.date
        
        return message
    }
    
    func createUser(id: String) -> User {
        let user = User(context: viewContext)
        user.id = id
        return user
    }
    
    /// Creates a user from a Matrix `StateEvent`. If the user already exists
    /// this method will overwrite it's properties to match the `StateEvent`.
    func createUser(event: RoomEvent) -> User? {
        guard let userID = event.stateKey else { return nil }
        
        let user = User(context: viewContext)
        
        user.id = userID
        user.displayName = event.content.displayName
        
        if let urlString = event.content.avatarURL, var components = URLComponents(string: urlString) {
            components.scheme = "https"
            user.avatarURL = components.url
        } else {
            user.avatarURL = nil
        }
        
        return user
    }
    
    func createReaction(roomEvent: RoomEvent) -> Reaction? {
        guard
            let relationship = roomEvent.content.relationship,
            let key = relationship.key,
            let messageID = relationship.eventID
        else { return nil }
        
        let reaction = Reaction(context: viewContext)
        reaction.key = key
        reaction.id = roomEvent.eventID
        reaction.message = message(id: messageID) ?? createMessage(id: messageID)
        reaction.sender = user(id: roomEvent.sender) ?? createUser(id: roomEvent.sender)
        reaction.date = roomEvent.date
        
        return reaction
    }
    
    func createEdit(roomEvent: RoomEvent) -> Edit? {
        guard
            let relationship = roomEvent.content.relationship,
            let body = roomEvent.content.newContent?.body,
            let messageID = relationship.eventID
        else { return nil }
        
        let edit = Edit(context: viewContext)
        edit.body = body
        edit.id = roomEvent.eventID
        edit.date = roomEvent.date
        edit.message = message(id: messageID) ?? createMessage(id: messageID)
        
        return edit
    }
    
    func createRedaction(roomEvent: RoomEvent) -> Redaction? {
        guard
            let messageID = roomEvent.redacts
        else { return nil }
        
        let redaction = Redaction(context: viewContext)
        redaction.id = roomEvent.eventID
        redaction.date = roomEvent.date
        redaction.sender = user(id: roomEvent.sender) ?? createUser(id: roomEvent.sender)
        redaction.message = message(id: messageID) ?? createMessage(id: messageID)
        
        return redaction
    }
    
    
    // MARK: Process Responses
    func process(events: [RoomEvent], in room: Room) {
        let messageEvents = events
            .filter { $0.type == "m.room.message" }
        
        let messages = messageEvents
            .filter { $0.content.relationship?.type != .replace }
            .compactMap { createMessage(roomEvent: $0) }
        
        // edits
        _ = messageEvents
            .filter { $0.content.relationship?.type == .replace }
            .compactMap { createEdit(roomEvent: $0) }
        
        // reactions
        _ = events
            .filter { $0.type == "m.reaction" }
            .compactMap { createReaction(roomEvent: $0) }
        
        // redactions
        _ = events
            .filter { $0.type == "m.room.redaction" }
            .compactMap { createRedaction(roomEvent: $0) }
        
        room.addToMessages(NSSet(array: messages))
    }
    
    
    // MARK: Get Objects
    func room(id: String) -> Room? {
        let request: NSFetchRequest<Room> = Room.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    func message(id: String) -> Message? {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    func user(id: String) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    func save() {
        guard container.viewContext.hasChanges else { return }
        try? container.viewContext.save()
    }
}
