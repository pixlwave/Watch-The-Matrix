import Foundation
import Matrix
import Combine
import KeychainAccess

public class MatrixController: ObservableObject {
    
    var client = Client()
    
    enum Status { case signedOut, syncing, idle, syncError(error: MatrixError) }
    
    @Published private(set) var status: Status = .signedOut
    
    @Published private(set) var userID = UserDefaults.standard.string(forKey: "userID") {
        didSet { UserDefaults.standard.set(userID, forKey: "userID")}
    }
    
    private var syncState: SyncState
    
    let dataController = DataController()
    private let keychain = Keychain(service: "uk.pixlwave.Matrix")
    
    init() {
        syncState = dataController.syncState()      // get the sync state from the data store
        
        loadCredentials()
        
        if client.accessToken != nil {
            if syncState.nextBatch == nil {         // if the persistent store has been deleted
                initialSync()
            } else {
                longPoll()
            }
        }
    }
    
    private func loadCredentials() {
        if let accessToken = keychain["accessToken"] {
            client.accessToken = accessToken
        }
        
        if let homeserverData = keychain[data: "homeserver"],
           let homeserver = Homeserver(data: homeserverData) {
            client.homeserver = homeserver
        }
    }
    
    private func saveCredentials() {
        keychain["accessToken"] = client.accessToken
        keychain[data: "homeserver"] = client.homeserver.data()
    }
    
    private var authCancellable: AnyCancellable?
    
    func register(username: String, password: String) {
        authCancellable = client.register(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
//                self.homeserver = response.homeServer
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.initialSync()
            }
    }
    
    func login(username: String, password: String) {
        authCancellable = client.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
//                self.homeserver = response.homeServer
                self.client.accessToken = response.accessToken
                self.saveCredentials()
                self.initialSync()
            }
    }
    
    func logout() {
        authCancellable = client.logout()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { success in
                guard success else { return }
                self.client.accessToken = nil
                self.status = .signedOut
                self.saveCredentials()
            }
    }
    
    private var syncCancellable: AnyCancellable?
    
    func initialSync() {
        status = .syncing
        longPoll()
    }
    
    func longPoll() {
        syncCancellable = client.sync(since: syncState.nextBatch, timeout: 5000)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                    self.status = .syncError(error: error)
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
                
                self.status = .idle
                self.syncState.nextBatch = response.nextBatch
                self.longPoll()
            }
    }
    
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
    
    func sendReaction(text: String, to event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReaction(text: text, to: eventID, in: roomID)
            .print()
            .subscribe(Subscribers.Sink { _ in } receiveValue: { _ in })
    }
    
    func sendMessage(body: String, room: Room) {
        guard let roomID = room.id else { return }
        
        client.sendMessage(body: body, roomID: roomID)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    func createRoom(name: String) {
        client.createRoom(name: name)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
}
