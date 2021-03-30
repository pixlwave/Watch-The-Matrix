import Foundation
import CoreData
import Matrix

/// A class that handles persistence and updates to core data objects.
class DataController {
    /// The persistence container used to store any synced data.
    private let container: NSPersistentContainer
    
    /// The container's view context.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Initialises the data controller with the option of storing the database in memory.
    /// - Parameter inMemory: A boolean indicating whether or not to store the database in memory.
    ///                       If this value is false the database will be stored to disk at it's default location.
    init(inMemory: Bool = false) {
        guard
            let modelURL = Bundle.main.url(forResource: "Matrix", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Unable to find Core Data Model") }
        
        // create the persistent container and set the merge policy to allow for external property updates
        container = NSPersistentContainer(name: "Matrix", managedObjectModel: managedObjectModel)
        #warning("This works for properties, but may not be suitable for relationships.")
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        #if DEBUG
        // delete the database from disk when the app is launched with a specific argument
        if CommandLine.arguments.contains("--delete-persistent-store"), let url = container.persistentStoreDescriptions.first?.url {
            try! FileManager.default.removeItem(at: url)
        }
        #endif
        
        // finally load the persistent stores into the container
        container.loadPersistentStores { storeDescription, error in
            if let error = error { fatalError("Core Data container error: \(error)") }
        }
    }
    
    /// Returns the count of items that would be returned by a fetch request.
    /// - Parameter request: The fetch request to be counted.
    /// - Returns: A positive integer if there are any items and the request is valid, otherwise 0.
    func count<T>(for request: NSFetchRequest<T>) -> Int {
        (try? viewContext.count(for: request)) ?? 0
    }
    
    /// Returns a managed object to store the current sync state of the app with the homeserver.
    /// This should be the only method used to get a SyncState object.
    /// - Returns: A `SyncState` object retrieved from the database, otherwise a newly created one
    func syncState() -> SyncState {
        let request: NSFetchRequest<SyncState> = SyncState.fetchRequest()
        let state = try? viewContext.fetch(request).first
        return state ?? SyncState(context: viewContext)
    }
    
    /// Checks for any unsaved changes in the view context, and saves them if there are.
    func save() {
        guard container.viewContext.hasChanges else { return }
        try? container.viewContext.save()
    }
    
    
    // MARK: Create Objects
    /// Creates a new room with the specified ID from a Matrix `JoinedRoom`.
    /// The room is created on the view context.
    func createRoom(id: String, joinedRoom: JoinedRoom) -> Room {
        let room = Room(context: viewContext)
        room.id = id
        
        process(events: joinedRoom.timeline.events, in: room)
        room.previousBatch = joinedRoom.timeline.previousBatch
        
        return room
    }
    
    /// Creates an empty message with the specified ID that can be updated at a later date
    /// when it's content is received from the server. The message is created on the view context.
    func createMessage(id: String) -> Message {
        let message = Message(context: viewContext)
        message.id = id
        
        return message
    }
    
    /// Creates a message from a Matrix `RoomEvent`. If the message already exists
    /// the store's merge policy will overwrite it's properties to match the `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent`of type `m.room.message`.
    /// - Returns: The `Message` object that was created, or `nil` if the event was invalid.
    ///
    /// The message is created on the view context.
    func createMessage(roomEvent: RoomEvent) -> Message? {
        guard let body = roomEvent.content.body else { return nil }
        
        let message = Message(context: viewContext)
        message.body = body
        message.id = roomEvent.eventID
        message.sender = user(id: roomEvent.sender) ?? createUser(id: roomEvent.sender)
        message.date = roomEvent.date
        
        return message
    }
    
    /// Creates an empty user with the specified ID that can be updated at a later date
    /// when their properties are received from the server. The user is created on the view context.
    func createUser(id: String) -> User {
        let user = User(context: viewContext)
        user.id = id
        return user
    }
    
    /// Creates a user from a Matrix `RoomEvent`. If the user already exists
    /// store's merge policy will overwrite it's properties to match the `RoomEvent`.
    /// - Parameter event: A `RoomEvent` of type `m.room.member`.
    /// - Returns: The `User` object that was just created, or `nil` if the event was invalid.
    ///
    /// The user is created on the view context.
    func createUser(event: RoomEvent) -> User? {
        guard let userID = event.stateKey else { return nil }
        
        let user = createUser(id: userID)
        updateUser(user, from: event)
        
        return user
    }
    
    /// Updates an existing user from a Matrix `RoomEvent`.
    func updateUser(_ user: User, from event: RoomEvent) {
        user.displayName = event.content.displayName
        
        if let urlString = event.content.avatarURL, var components = URLComponents(string: urlString) {
            components.scheme = "https"
            user.avatarURL = components.url
        } else {
            user.avatarURL = nil
        }
    }
    
    /// Creates a reaction from a Matrix `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent` of type `m.reaction`.
    /// - Returns: The `Reaction` object if successful or `nil` if the event was invalid.
    ///
    /// The reaction is created on the view context.
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
    
    /// Creates a message edit from a Matrix `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent` with a `replace` relationship.
    /// - Returns: The `Edit` object if successful or `nil` if the event was invalid.
    ///
    /// The message edit is created on the view context.
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
    
    /// Created a redaction from a Matrix `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent` of type `m.room.redaction`.
    /// - Returns: The `Redaction` object if successful or `nil` if the event was invalid.
    ///
    /// The redaction is created on the view context.
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
    /// Process any room events in the provided array for the specified room.
    /// The following event types are currently processed:
    /// - Messages
    /// - Message Edits
    /// - Reactions
    /// - Redactions
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
    
    /// Processes any state events in the provided array for the specified room.
    /// NOTE: Calling this while paginating backwards will incorrectly update the room's current state.
    /// The following event types are currently processed:
    /// - Room Name
    /// - Membership Changes
    func processState(events: [RoomEvent], in room: Room) {
        let roomName = events
            .filter { $0.type == "m.room.name" }
            .sorted { $0.date > $1.date }
            .first
        
        if let name = roomName?.content.name {
            room.name = name.isEmpty ? nil : name
        }
        
        // members
        events.filter { $0.type == "m.room.member" }.forEach {
            guard let userID = $0.stateKey, let membership = $0.content.membership else { return }
            
            if membership == .join {
                let user = self.user(id: userID) ?? createUser(id: userID)
                updateUser(user, from: $0)
                room.addToMembers(user)             // this can be called even if the relationship already exists
            } else {
                if let user = self.user(id: userID) {
                    room.removeFromMembers(user)    // this can be called even if the user isn't a member
                }
            }
        }
    }
    
    
    // MARK: Get Objects
    /// Fetch the room with the matching ID from the data store.
    func room(id: String) -> Room? {
        let request: NSFetchRequest<Room> = Room.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    /// Fetch the message with the matching ID from the data store.
    func message(id: String) -> Message? {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    /// Fetch the user with the matching ID from the data store.
    func user(id: String) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
}
