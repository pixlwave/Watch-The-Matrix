import Foundation
import Matrix
import Combine
import KeychainAccess

/// A class that calls the Matrix Client to make requests and hands the appropriate responses back to it's DataController.
class MatrixController: ObservableObject {
    
    /// The Matrix client object used to interact with the homeserver
    var client = Client()
    
    enum State { case signedOut, syncing, idle, syncError(error: MatrixError) }
    
    /// The current state of the Matrix stack.
    @Published private(set) var state: State = .signedOut
    
    @Published private(set) var userID: String?
    @Published private(set) var deviceID: String?
    
    /// An object that represents the current sync state to the Matrix homeserver.
    private var syncState: SyncState
    
    /// The data controller used to format and persist synced data.
    let dataController = DataController()
    
    /// The keychain used to save and load user credentials from.
    private let keychain = Keychain(service: "uk.pixlwave.Matrix")
    
    /// Initialises the controller and starts communication with the homeserver if user credentials are found.
    init() {
        syncState = dataController.syncState()      // get the sync state from the data store
        
        loadCredentials()
        
        if client.accessToken != nil {
            if syncState.nextBatch == nil {         // if the persistent store has been deleted
                initialSync()
            } else {
                state = .idle                       // show the rooms list immediately
                longPoll()
            }
        }
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
    
    /// A cancellable instance used for login, register and logout operations.
    private var authCancellable: AnyCancellable?
    
    /// Register a new account on the homeserver with the supplied username and password.
    /// If successful the user's credentials will be saved to the keychain and an initial sync will begin.
    func register(username: String, password: String) {
        authCancellable = client.register(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
                self.deviceID = response.deviceID
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.initialSync()
            }
    }
    
    /// Login to the homeserver using the supplied username and password.
    /// If successful the user's credentials will be saved to the keychain and an initial sync will begin.
    func login(username: String, password: String) {
        authCancellable = client.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
                self.deviceID = response.deviceID
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.initialSync()
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
                self.syncCancellable?.cancel()
                
                // reset access credentials
                self.userID = nil
                self.deviceID = nil
                self.client.accessToken = nil
                self.client.homeserver = .default
                self.saveCredentials()
                
                // update the ui state
                self.state = .signedOut
            }
    }
    
    /// A cancellable instance used for sync operations.
    private var syncCancellable: AnyCancellable?
    
    /// Begins an initial sync. This will show an indefinite progress view until this completes successfully.
    func initialSync() {
        state = .syncing
        longPoll()
    }
    
    /// Long poll the sync endpoint on the homeserver and process the response automatically. As soon as a response
    /// has been processed, this method calls itself to create a request loop.
    func longPoll() {
        syncCancellable = client.sync(since: syncState.nextBatch, timeout: 5000)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                    self.state = .syncError(error: error)
                }
            } receiveValue: { response in
                let joinedRooms = response.rooms.joined
                joinedRooms.keys.forEach { key in
                    let joinedRoom = joinedRooms[key]!
                    
                    if let room = self.dataController.room(id: key) {
                        #warning("Deleting old messages needs testing.")
                        // delete existing messages when the timeline is limited and process state events from the sync gap
                        if joinedRoom.timeline.isLimited {
                            room.deleteAllMessages()
                            self.dataController.processState(events: joinedRoom.state.events, in: room)
                            room.previousBatch = joinedRoom.timeline.previousBatch
                        }
                        
                        let events = joinedRoom.timeline.events
                        self.dataController.process(events: events, in: room)
                        self.dataController.processState(events: events, in: room)
                        room.unreadCount = Int32(joinedRoom.unreadNotifications.notificationCount)
                    } else {
                        let room = self.dataController.createRoom(id: key, joinedRoom: joinedRoom)
                        self.getMembers(of: room, at: response.nextBatch)
                        self.getName(of: room)
                        self.loadMoreMessages(in: room)
                        room.unreadCount = Int32(joinedRoom.unreadNotifications.notificationCount)
                    }
                }
                
                self.dataController.save()
                
                self.state = .idle
                self.syncState.nextBatch = response.nextBatch
                self.longPoll()
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
                                              .compactMap { self.dataController.createUser(event: $0) }
                
                room.members = NSSet(array: members)
                self.dataController.save()
            })
    }
    
    /// Loads 10 more events at the start of the specified room.
    func loadMoreMessages(in room: Room) {
        guard let roomID = room.id, let previousBatch = room.previousBatch else { return }
        
        client.loadMessages(in: roomID, from: previousBatch)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                guard let events = response.events else { return }
                
                self.dataController.process(events: events, in: room)
                room.previousBatch = response.endToken
                
                self.dataController.save()
            })
    }
    
    /// Sends a reaction to the event in the specified room.
    /// - Parameters:
    ///   - text: The reaction string to send.
    func sendReaction(text: String, to event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReaction(text: text, to: eventID, in: roomID)
            .print()
            .subscribe(Subscribers.Sink { _ in } receiveValue: { _ in })
    }
    
    /// Sends a message to the specified room.
    func sendMessage(body: String, room: Room) {
        guard let roomID = room.id else { return }
        
        client.sendMessage(body: body, roomID: roomID)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    /// Creates a new room with the specified name.
    func createRoom(name: String) {
        client.createRoom(name: name)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    /// Indicates to the homeserver that a message has been read.
    func sendReadReceipt(for event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReadReceipt(for: eventID, in: roomID)
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
}
