import Foundation
import CoreData
import Matrix

/// A class that handles persistence and updates to core data objects.
class DataController {
    /// A version number that is incremented when breaking changes are made
    /// to the data model, processing or storage logic to force a resync.
    private let version = 6
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
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            #if DEBUG
            // delete the database from disk when the app is launched with a specific argument
            if CommandLine.arguments.contains("--delete-persistent-store"), let url = container.persistentStoreDescriptions.first?.url {
                try! FileManager.default.removeItem(at: url)
            }
            #endif
            
            // delete the database from disk if the version number has been incremented
            if UserDefaults.standard.integer(forKey: "DataControllerVersion") != version, let url = container.persistentStoreDescriptions.first?.url {
                try? FileManager.default.removeItem(at: url)
                UserDefaults.standard.set(version, forKey: "DataControllerVersion")
            }
        }
        
        // finally load the persistent stores into the container
        container.loadPersistentStores { storeDescription, error in
            if let error = error { fatalError("Core Data container error: \(error)") }
        }
        
        #warning("This works for properties, but may not be suitable for relationships.")
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
    
    /// Deletes the specified room along with all of it's members and message contents.
    func delete(_ room: Room) {
        viewContext.delete(room)
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
        batchDelete(entity: Member.self)
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
        
        joinedRoom.state?.events?.forEach { processStateEvent($0, in: room) }
        process(events: joinedRoom.timeline?.events, in: room, paginating: .forwards)
        room.previousBatch = joinedRoom.timeline?.previousBatch
        
        return room
    }
    
    /// Creates an empty message with the specified ID that can be updated at a later date
    /// when it's content is received from the server. The message is created on the view context.
    ///
    /// The message isn't assigned to a room so that it isn't shown until its content has been filled
    /// in from the server.
    func createMessage(id: String) -> Message {
        let message = Message(context: viewContext)
        message.id = id
        
        return message
    }
    
    /// Creates a message from a Matrix `RoomMessageEvent`. If the message already exists
    /// the store's merge policy will overwrite it's properties to match the `RoomMessageEvent`.
    /// - Parameter event: A Matrix event of type `RoomMessageEvent`.
    /// - Parameter room: The room that the message belongs to.
    /// - Returns: The `Message` object that was created, or `nil` if the event was invalid.
    ///
    /// The message is created on the view context and will be added to the room.
    func updateMessage(_ message: Message, from event: RoomMessageEvent, in room: Room) {
        guard
            let body = event.content.body,
            let type = event.content.type
        else { return }
        
        message.id = event.eventID
        message.body = body
        message.typeString = type.rawValue
        message.date = event.date
        message.sender = member(id: event.sender, in: room) ?? createMember(id: event.sender, in: room)
        message.room = room
        
        if event.content.format == .html {
            message.htmlBody = event.content.formattedBody
        }
        
        // media related properties
        message.mediaURL = event.content.mediaURL
        if let mediaWidth = event.content.mediaInfo?.width {
            message.mediaWidth = Double(mediaWidth)
        }
        if let mediaHeight = event.content.mediaInfo?.height {
            message.mediaHeight = Double(mediaHeight)
        }
        
        // reply handling
        if let relationship = event.content.relationship, relationship.type == .reply {
            message.repliesToEventID = relationship.eventID
            message.formatAsReply()
        }
    }
    
    /// Creates an empty member with the specified ID that can be updated at a later date
    /// when their properties are received from the server. The member is created on the view context.
    func createMember(id: String, in room: Room) -> Member {
        let member = Member(context: viewContext)
        member.id = id
        member.room = room
        return member
    }
    
    /// Creates a member from a Matrix `RoomMemberEvent`. If the member already exists
    /// store's merge policy will overwrite it's properties to match the `RoomMemberEvent`.
    /// - Parameter event: A Matrix event of type `RoomMemberEvent`.
    /// - Parameter room: The room that the member belongs to.
    /// - Returns: The `Member` object that was just created, or `nil` if the event was invalid.
    ///
    /// The member is created on the view context.
    func createMember(event: RoomMemberEvent, in room: Room) -> Member? {
        guard let userID = event.stateKey else { return nil }
        
        let member = createMember(id: userID, in: room)
        updateMember(member, from: event)
        
        return member
    }
    
    /// Updates an existing member from a Matrix `RoomMemberEvent`.
    func updateMember(_ member: Member, from event: RoomMemberEvent) {
        if let name = event.content.displayName {
            member.displayName = name.isEmpty ? nil : name
        }
        
        if let urlString = event.content.avatarURL {
            member.avatarURL = urlString.isEmpty ? nil : URL(string: urlString)
        }
    }
    
    /// Creates a reaction from a Matrix `RoomReactionEvent`.
    /// - Parameter event: A Matrix event of type `RoomReactionEvent`.
    /// - Parameter room: The room that the message being reacted to belongs in.
    /// - Returns: The `Reaction` object if successful or `nil` if the event was invalid.
    ///
    /// The reaction is created on the view context.
    func createReaction(event: RoomReactionEvent, in room: Room) {
        guard
            let relationship = event.content.relationship,
            let key = relationship.key,
            let messageID = relationship.eventID
        else { return }
        
        let reaction = Reaction(context: viewContext)
        reaction.key = key
        reaction.id = event.eventID
        reaction.message = message(id: messageID) ?? createMessage(id: messageID)
        reaction.sender = member(id: event.sender, in: room) ?? createMember(id: event.sender, in: room)
        reaction.date = event.date
    }
    
    /// Creates a message edit from a Matrix `RoomMessageEvent`.
    /// - Parameter event: A Matrix `RoomMessageEvent` with a `replace` relationship.
    /// - Returns: The `Edit` object if successful or `nil` if the event was invalid.
    ///
    /// The message edit is created on the view context.
    func createEdit(event: RoomMessageEvent) {
        guard
            let relationship = event.content.relationship,
            let body = event.content.newContent?.body,
            let messageID = relationship.eventID
        else { return }
        
        let edit = Edit(context: viewContext)
        edit.body = body
        edit.id = event.eventID
        edit.date = event.date
        edit.message = message(id: messageID) ?? createMessage(id: messageID)
    }
    
    
    // MARK: Process Responses
    #warning("Move to the Matrix package.")
    enum PaginationDirection {
        case forwards
        case backwards
    }
    /// Process any room events in the provided array for the specified room.
    /// The following event types are currently processed:
    /// - Messages
    /// - Message Edits
    /// - Reactions
    /// - Redactions
    /// - State if `paginating` is `.forwards`
    func process(events: [RoomEvent]?, in room: Room, paginating: PaginationDirection) {
        guard let events = events else { return }
        
        var messages = [Message]()
        var redactionEvents = [RoomRedactionEvent]()
            
        events.forEach {
            if let messageEvent = $0 as? RoomMessageEvent {
                if messageEvent.content.relationship?.type != .replace {
                    let message = message(id: messageEvent.eventID) ?? createMessage(id: messageEvent.eventID)
                    updateMessage(message, from: messageEvent, in: room)
                    messages.append(message)
                    
                    // if the event has a transaction id, remove its local echo
                    if let transactionID = messageEvent.unsigned?.transactionID {
                        room.transactionStore.removeTransaction(with: transactionID)
                    }
                } else {
                    createEdit(event: messageEvent)
                }
            } else if let reactionEvent = $0 as? RoomReactionEvent {
                createReaction(event: reactionEvent, in: room)
            } else if let redactionEvent = $0 as? RoomRedactionEvent {
                // batch redactions together to process later when paginating
                // backwards as the related events might not be processed yet
                if paginating == .backwards {
                    redactionEvents.append(redactionEvent)
                } else {
                    processRedaction(event: redactionEvent, in: room)
                }
            } else if paginating == .forwards {
                processStateEvent($0, in: room)
            }
        }
        
        // process all redactions together after paginating backwards
        if paginating == .backwards {
            redactionEvents.forEach { redactionEvent in
                processRedaction(event: redactionEvent, in: room)
            }
            
            if let pendingRedactions = try? viewContext.fetch(room.pendingRedactionsRequest) {
                pendingRedactions.forEach { redaction in
                    guard let eventID = redaction.eventID else { return }
                    
                    if let message = message(id: eventID) {
                        message.isRedacted = true
                        viewContext.delete(redaction)
                    } else if let reaction = reaction(id: eventID) {
                        viewContext.delete(reaction)
                        viewContext.delete(redaction)
                    }
                }
            }
        }
    }
    
    /// Processes an event for state in the specified room.
    /// NOTE: Calling this while paginating backwards will incorrectly update the room's current state.
    /// The following event types are currently processed:
    /// - Room Name
    /// - Membership Changes
    func processStateEvent(_ event: RoomEvent, in room: Room) {
        if let nameEvent = event as? RoomNameEvent, let name = nameEvent.content.name {
            room.name = name.isEmpty ? nil : name
        } else if let memberEvent = event as? RoomMemberEvent {
            if let userID = memberEvent.stateKey, let membership = memberEvent.content.membership {
                if membership == .join {
                    let member = self.member(id: userID, in: room) ?? createMember(id: userID, in: room)
                    updateMember(member, from: memberEvent)
                } else {
                    if let member = self.member(id: userID, in: room) {
                        room.removeFromMembers(member)    // this can be called even if the relationship doesn't exist
                    }
                }
            }
        } else if event is RoomEncryptionEvent {
            room.isEncrypted = true
        }
    }
    
    /// Processes `RoomRedactionEvent` events, redacting messages or events if
    /// they are already synced. If no matching event can be found a `Reaction` object
    /// will be created to perform the redaction later.
    /// - Parameter event: A Matrix event of type `RoomRedactionEvent`.
    /// - Parameter room: The room that the redaction is in.
    ///
    /// The view context is used to create/delete objects.
    func processRedaction(event: RoomRedactionEvent, in room: Room) {
        guard let eventID = event.redacts else { return }
        
        if let message = message(id: eventID) {
            message.isRedacted = true
        } else if let reaction = reaction(id: eventID) {
            viewContext.delete(reaction)
        } else {
            let redaction = Redaction(context: viewContext)
            redaction.id = event.eventID
            redaction.eventID = eventID
            redaction.date = event.date
            redaction.sender = member(id: event.sender, in: room) ?? createMember(id: event.sender, in: room)
        }
    }
    
    
    // MARK: Get Objects
    /// Fetch the room with the matching ID from the data store.
    func room(id: String) -> Room? {
        let request = Room.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    /// Fetch the message with the matching ID from the data store.
    func message(id: String) -> Message? {
        let request = Message.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
    
    /// Fetch the member with the matching ID from the data store.
    func member(id: String, in room: Room) -> Member? {
        let request = Member.fetchRequest()
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "id == %@", id),
            NSPredicate(format: "room == %@", room)
        ])
        return try? viewContext.fetch(request).first
    }
    
    /// Fetch the reaction with the matching ID from the data store.
    func reaction(id: String) -> Reaction? {
        let request = Reaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? viewContext.fetch(request).first
    }
}
