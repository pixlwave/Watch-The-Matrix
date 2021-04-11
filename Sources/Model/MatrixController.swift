import Foundation
import Matrix
import Combine
import KeychainAccess

/// A class that calls the Matrix Client to make requests and hands the appropriate responses back to it's DataController.
class MatrixController: ObservableObject {
    
    /// The Matrix client object used to interact with the homeserver
    var client = Client()
    
    enum State { case signedOut, initialSync, syncing, syncError(error: MatrixError) }
    
    /// The current state of the Matrix stack.
    @Published private(set) var state: State = .signedOut
    
    @Published private(set) var userID: String?
    @Published private(set) var deviceID: String?
    
    /// An object that represents the current sync state to the Matrix homeserver.
    private var syncState: SyncState
    
    /// The data controller used to format and persist synced data.
    let dataController: DataController
    
    /// The keychain used to save and load user credentials from.
    private let keychain = Keychain(service: "uk.pixlwave.Matrix")
    
    /// Initialises the controller and starts communication with the homeserver if user credentials are found.
    /// - Parameter inMemory: Whether to keep the data store in memory or persist it to disk.
    init(inMemory: Bool = false) {
        dataController = DataController(inMemory: inMemory)
        
        // get the sync state from the data store and load any saved credentials
        syncState = dataController.syncState()
        loadCredentials()
        
        // resumes syncing if an access token was loaded
        resumeSync()
    }
    
    /// Loads the user's access token, ID, device ID and homeserver information from the keychain
    private func loadCredentials() {
        client.accessToken = keychain["accessToken"]
        userID = keychain["userID"]
        deviceID = keychain["deviceID"]
        
        if let homeserverData = keychain[data: "homeserver"],
           let homeserver = Homeserver(data: homeserverData) {
            client.homeserver = homeserver
        }
    }
    
    /// Saves the user's access token, ID, device ID and homeserver information to the keychain
    private func saveCredentials() {
        keychain["accessToken"] = client.accessToken
        keychain["userID"] = userID
        keychain["deviceID"] = deviceID
        keychain[data: "homeserver"] = client.homeserver.data()
    }
    
    /// Long poll the homeserver's sync endpoint, displaying an indefinite progress view if an initial sync needs to take place
    /// This will only take place if the client has an access token.
    func resumeSync() {
        guard client.accessToken != nil else { return }
        
        // shows an indefinite progress view for an initial sync otherwise shows the rooms list
        if syncState.nextBatch == nil {
            state = .initialSync
            sync(isInitial: true)
        } else {
            state = .syncing
            sync()
        }
    }
    
    /// Cancel the long poll on the homeserver's sync endpoint.
    func pauseSync() {
        syncCancellable?.cancel()
    }
    
    /// A cancellation token used for login, register and logout operations.
    private var authCancellable: AnyCancellable?
    
    /// Register a new account on the homeserver with the supplied username and password.
    /// If successful the user's credentials will be saved to the keychain and an initial sync will begin.
    func register(username: String, password: String) {
        authCancellable = client.register(username: username, password: password, displayName: "Watch")
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
                self.deviceID = response.deviceID
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.resumeSync()
            }
    }
    
    /// Login to the homeserver using the supplied username and password.
    /// If successful the user's credentials will be saved to the keychain and an initial sync will begin.
    func login(username: String, password: String) {
        authCancellable = client.login(username: username, password: password, displayName: "Watch")
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
                self.deviceID = response.deviceID
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.resumeSync()
            }
    }
    
    /// Logout of the homeserver. If successful the user's credentials will be reset and the state
    /// will be updated triggering LoginView to be shown.
    func logout() {
        authCancellable = client.logout()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { success in
                guard success else { return }
                
                // cancel the long poll
                self.pauseSync()
                
                // reset access credentials
                self.userID = nil
                self.deviceID = nil
                self.client.accessToken = nil
                self.client.homeserver = .default
                self.saveCredentials()
                
                // clear all synced data
                self.dataController.deleteAll()
                
                // create a fresh sync state object
                self.syncState = self.dataController.syncState()
                
                // update the ui state
                self.state = .signedOut
            }
    }
    
    /// A cancellation token used for sync operations.
    private var syncCancellable: AnyCancellable?
    
    /// A filter that lazy loads members and only a single event for a fast initial sync.
    private let initialSyncFilter = """
    {"room":{"state":{"lazy_load_members":true},"timeline":{"limit":1}}}
    """
    
    /// A filter that lazy loads members.
    private let lazyLoadMembersFilter = """
    {"room":{"state":{"lazy_load_members":true}}}
    """
    
    /// Long poll the sync endpoint on the homeserver and process the response automatically. As soon as a response
    /// has been processed, this method calls itself to create a request loop.
    func sync(isInitial: Bool = false) {
        let filter = isInitial ? initialSyncFilter : lazyLoadMembersFilter
        
        syncCancellable = client.sync(filter: filter, since: syncState.nextBatch, timeout: 5000)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                    self.state = .syncError(error: error)
                }
            } receiveValue: { response in
                self.process(response.rooms.joined)
                self.process(response.rooms.left)
                
                self.dataController.save()
                
                self.state = .syncing
                self.syncState.nextBatch = response.nextBatch
                self.sync()
            }
    }
    
    /// Process the joined rooms from a sync response, creating new `Room` instances and updating
    /// any existing instances as appropriate.
    private func process(_ joinedRooms: [String: JoinedRoom]) {
        joinedRooms.keys.forEach { roomID in
            let joinedRoom = joinedRooms[roomID]!
            
            if let room = dataController.room(id: roomID) {
                // delete existing messages when the timeline is limited and reset the pagination token
                if joinedRoom.timeline.isLimited {
                    room.deleteAllMessages()
                    room.previousBatch = joinedRoom.timeline.previousBatch
                }
                
                joinedRoom.state.events.forEach { dataController.processStateEvent($0, in: room) }
                dataController.process(events: joinedRoom.timeline.events, in: room, includeState: true)
                room.unreadCount = Int32(joinedRoom.unreadNotifications.notificationCount)
            } else {
                let room = dataController.createRoom(id: roomID, joinedRoom: joinedRoom)
                getName(of: room)
                loadMoreMessages(in: room)
                room.unreadCount = Int32(joinedRoom.unreadNotifications.notificationCount)
            }
        }
    }
    
    /// Process the left rooms from a sync response, deleting `Room` instances to match.
    private func process(_ leftRooms: [String: LeftRoom]) {
        leftRooms.keys.forEach { roomID in
            if let room = dataController.room(id: roomID) {
                dataController.delete(room)
            }
        }
    }
    
    /// Requests the name of the room object passed in and updates it when a response is received.
    private func getName(of room: Room) {
        guard let roomID = room.id else { return }
        
        client.getName(of: roomID)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                }
            } receiveValue: { response in
                room.name = response.name.isEmpty ? nil : response.name
                self.dataController.save()
            })
    }
    
    /// Requests the membership list of the room passed in at a point in time defined by a pagination token.
    /// When a response is received the room's members property will be automatically updated.
    private func getMembers(of room: Room, at paginationToken: String) {
        guard let roomID = room.id else { return }
        
        client.getMembers(of: roomID, at: paginationToken)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                let members = response.members.filter { $0.type == "m.room.member" && $0.content.membership == .join }
                                              .compactMap { self.dataController.createMember(event: $0, in: room) }
                
                room.members = NSSet(array: members)
                self.dataController.save()
            })
    }
    
    /// Loads 20 more events at the start of the specified room.
    func loadMoreMessages(in room: Room) {
        guard let roomID = room.id, let previousBatch = room.previousBatch else { return }
        
        client.getMessages(in: roomID, from: previousBatch, limit: 20)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                guard let events = response.events else { return }
                
                // the events are reversed to prevent a template message being created for a
                // relationship and then being created again from if it's event is in the response.
                self.dataController.process(events: events.reversed(), in: room, includeState: false)
                room.previousBatch = response.endToken
                
                self.dataController.save()
            })
    }
    
    /// Sends a reaction to the event in the specified room.
    func sendReaction(_ reaction: String, to event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReaction(reaction, to: eventID, in: roomID)
            .print()
            .subscribe(Subscribers.Sink { _ in } receiveValue: { _ in })
    }
    
    /// Sends a message to the specified room.
    func sendMessage(_ message: String, in room: Room) {
        guard let roomID = room.id else { return }
        
        client.sendMessage(message, in: roomID)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    /// Creates a new room with the specified name.
    func createRoom(name: String) {
        client.createRoom(name: name)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    /// Indicates to the homeserver that a message has been read. If the message has edits,
    /// the receipt will be sent for the most recent edit.
    func sendReadReceipt(for event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReadReceipt(for: event.lastEdit?.id ?? eventID, in: roomID)
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
}
