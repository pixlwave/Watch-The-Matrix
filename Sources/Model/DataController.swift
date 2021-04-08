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
        // create the persistent container and set the merge policy to allow for external property updates
        container = NSPersistentContainer(name: "Matrix", managedObjectModel: Self.model)
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
    
    /// A cached copy of the core data model, preventing any class conflicts between multiple data controllers.
    static let model: NSManagedObjectModel = {
        guard
            let modelURL = Bundle.main.url(forResource: "Matrix", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Unable to find Core Data Model") }
        
        return managedObjectModel
    }()
    
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
    
    /// Execute a batch delete request for all of objects of the specified type.
    /// - Parameter entity: The type of `NSManagedObject` to delete.
    ///
    /// The request is executed on the view context.
    func batchDelete<T>(entity: T.Type) where T: NSManagedObject {
        let request = T.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        _ = try? viewContext.execute(batchDeleteRequest)
    }
    
    /// Deletes all data in the persistent store and saves the changes.
    func deleteAll() {
        batchDelete(entity: Room.self)
        batchDelete(entity: User.self)
        batchDelete(entity: Message.self)
        batchDelete(entity: Reaction.self)
        batchDelete(entity: Edit.self)
        batchDelete(entity: Redaction.self)
        batchDelete(entity: SyncState.self)
         
        save()      // save here to ensure all data is completely deleted
    }
    
    
    // MARK: Create Objects
    /// Creates a new room with the specified ID from a Matrix `JoinedRoom`.
    /// The room is created on the view context.
    func createRoom(id: String, joinedRoom: JoinedRoom) -> Room {
        let room = Room(context: viewContext)
        room.id = id
        
        joinedRoom.state.events.forEach { processStateEvent($0, in: room) }
        process(events: joinedRoom.timeline.events, in: room, includeState: true)
        room.previousBatch = joinedRoom.timeline.previousBatch
        
        return room
    }
    
    /// Creates an empty message with the specified ID that can be updated at a later date
    /// when it's content is received from the server. The message is created on the view context.
    ///
    /// The message isn't assigned to a room so that it isn't shown until it's content has been filled
    /// in from the server.
    func createMessage(id: String) -> Message {
        let message = Message(context: viewContext)
        message.id = id
        
        return message
    }
    
    /// Creates a message from a Matrix `RoomEvent`. If the message already exists
    /// the store's merge policy will overwrite it's properties to match the `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent`of type `m.room.message`.
    /// - Parameter room: The room that the message belongs to.
    /// - Returns: The `Message` object that was created, or `nil` if the event was invalid.
    ///
    /// The message is created on the view context.
    func createMessage(roomEvent: RoomEvent, in room: Room) -> Message? {
        guard let body = roomEvent.content.body else { return nil }
        
        let message = Message(context: viewContext)
        message.body = body
        message.id = roomEvent.eventID
        message.sender = user(id: roomEvent.sender, in: room) ?? createUser(id: roomEvent.sender, in: room)
        message.date = roomEvent.date
        
        return message
    }
    
    /// Creates an empty user with the specified ID that can be updated at a later date
    /// when their properties are received from the server. The user is created on the view context.
    func createUser(id: String, in room: Room) -> User {
        let user = User(context: viewContext)
        user.id = id
        user.room = room
        return user
    }
    
    /// Creates a user from a Matrix `RoomEvent`. If the user already exists
    /// store's merge policy will overwrite it's properties to match the `RoomEvent`.
    /// - Parameter event: A `RoomEvent` of type `m.room.member`.
    /// - Parameter room: The room that the user belongs too.
    /// - Returns: The `User` object that was just created, or `nil` if the event was invalid.
    ///
    /// The user is created on the view context.
    func createUser(event: RoomEvent, in room: Room) -> User? {
        guard let userID = event.stateKey else { return nil }
        
        let user = createUser(id: userID, in: room)
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
    /// - Parameter room: The room that the message being reacted to belongs in.
    /// - Returns: The `Reaction` object if successful or `nil` if the event was invalid.
    ///
    /// The reaction is created on the view context.
    func createReaction(roomEvent: RoomEvent, in room: Room) {
        guard
            let relationship = roomEvent.content.relationship,
            let key = relationship.key,
            let messageID = relationship.eventID
        else { return }
        
        let reaction = Reaction(context: viewContext)
        reaction.key = key
        reaction.id = roomEvent.eventID
        reaction.message = message(id: messageID) ?? createMessage(id: messageID)
        reaction.sender = user(id: roomEvent.sender, in: room) ?? createUser(id: roomEvent.sender, in: room)
        reaction.date = roomEvent.date
    }
    
    /// Creates a message edit from a Matrix `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent` with a `replace` relationship.
    /// - Returns: The `Edit` object if successful or `nil` if the event was invalid.
    ///
    /// The message edit is created on the view context.
    func createEdit(roomEvent: RoomEvent) {
        guard
            let relationship = roomEvent.content.relationship,
            let body = roomEvent.content.newContent?.body,
            let messageID = relationship.eventID
        else { return }
        
        let edit = Edit(context: viewContext)
        edit.body = body
        edit.id = roomEvent.eventID
        edit.date = roomEvent.date
        edit.message = message(id: messageID) ?? createMessage(id: messageID)
    }
    
    /// Created a redaction from a Matrix `RoomEvent`.
    /// - Parameter roomEvent: A Matrix `RoomEvent` of type `m.room.redaction`.
    /// - Parameter room: The room that the message being redacted belongs to.
    /// - Returns: The `Redaction` object if successful or `nil` if the event was invalid.
    ///
    /// The redaction is created on the view context.
    func createRedaction(roomEvent: RoomEvent, in room: Room) {
        guard let messageID = roomEvent.redacts else { return }
        
        let redaction = Redaction(context: viewContext)
        redaction.id = roomEvent.eventID
        redaction.date = roomEvent.date
        redaction.sender = user(id: roomEvent.sender, in: room) ?? createUser(id: roomEvent.sender, in: room)
        redaction.message = message(id: messageID) ?? createMessage(id: messageID)
    }
    
    
    // MARK: Process Responses
    /// Process any room events in the provided array for the specified room.
    /// The following event types are currently processed:
    /// - Messages
    /// - Message Edits
    /// - Reactions
    /// - Redactions
    /// - State if `includeState` is true
    func process(events: [RoomEvent], in room: Room, includeState: Bool) {
        var messages = [Message]()
            
        events.forEach {
            if $0.type == "m.room.message" {
                if $0.content.relationship?.type != .replace {
                    if let message = createMessage(roomEvent: $0, in: room) {
                        messages.append(message)
                    }
                } else {
                    createEdit(roomEvent: $0)
                }
            } else if $0.type == "m.reaction" {
                createReaction(roomEvent: $0, in: room)
            } else if $0.type == "m.room.redaction" {
                createRedaction(roomEvent: $0, in: room)
            } else if includeState {
                processStateEvent($0, in: room)
            }
        }
        
        room.addToMessages(NSSet(array: messages))
    }
    
    /// Processes an event for state in the specified room.
    /// NOTE: Calling this while paginating backwards will incorrectly update the room's current state.
    /// The following event types are currently processed:
    /// - Room Name
    /// - Membership Changes
    func processStateEvent(_ event: RoomEvent, in room: Room) {
        if event.type == "m.room.name", let name = event.content.name {
            room.name = name.isEmpty ? nil : name
        } else if event.type == "m.room.member" {
            if let userID = event.stateKey, let membership = event.content.membership {
                if membership == .join {
                    let user = self.user(id: userID, in: room) ?? createUser(id: userID, in: room)
                    updateUser(user, from: event)
                } else {
                    if let user = self.user(id: userID, in: room) {
                        room.removeFromMembers(user)    // this can be called even if the user isn't a member
                    }
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
    func user(id: String, in room: Room) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "id == %@", id),
            NSPredicate(format: "room == %@", room)
        ])
        return try? viewContext.fetch(request).first
    }
}
