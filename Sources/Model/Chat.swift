import Foundation
import Matrix
import Combine
import KeychainAccess

public class Chat: ObservableObject {
    
    var client = Client()
    
    enum Status { case signedOut, syncing, idle, syncError }
    
    @Published private(set) var status: Status = .signedOut
    
    @Published private(set) var userID = UserDefaults.standard.string(forKey: "userID") {
        didSet { UserDefaults.standard.set(userID, forKey: "userID")}
    }
    
    private var nextBatch: String?
    
    let dataController = DataController(inMemory: true)    // in memory for now
    private let keychain = Keychain(service: "uk.pixlwave.Matrix")
    
    init() {
        loadCredentials()
        
        if client.accessToken != nil { initialSync() }
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
    
    func createRoom(name: String) {
        client.createRoom(name: name)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    func sendMessage(body: String, room: Room) {
        guard let roomID = room.id else { return }
        
        client.sendMessage(body: body, roomID: roomID)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    func sendReaction(text: String, to event: Message, in room: Room) {
        guard let eventID = event.id, let roomID = room.id else { return }
        
        client.sendReaction(text: text, to: eventID, in: roomID)
            .print()
            .subscribe(Subscribers.Sink { _ in } receiveValue: { _ in })
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
    
    private func getMembers(in room: Room) {
        guard let roomID = room.id else { return }
        
        client.getMembers(in: roomID)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                let members = response.members.filter { $0.type == "m.room.member" && $0.content.membership == .join }
                    .map { Member(event: $0, context: self.dataController.viewContext) }
                
                room.members = NSSet(array: members)
                self.dataController.save()
            })
    }
    
    private var syncCancellable: AnyCancellable?
    
    func initialSync() {
        status = .syncing
        
        syncCancellable = client.sync()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                    self.status = .syncError
                }
            } receiveValue: { response in
                let joinedRooms = response.rooms.joined
                let rooms: [Room] = joinedRooms.keys.map { key in
                    Room(id: key, joinedRoom: joinedRooms[key]!, context: self.dataController.viewContext)
                }
                
                self.dataController.save()
                
                self.status = .idle
                self.nextBatch = response.nextBatch
                self.longPoll()
                
                rooms.forEach {
                    self.getMembers(in: $0)
                    self.getName(of: $0)
                    self.loadMoreMessages(in: $0)
                }
            }
    }
    
    func longPoll() {
        syncCancellable = client.sync(since: nextBatch, timeout: 5000)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                let joinedRooms = response.rooms.joined
                joinedRooms.keys.forEach { key in
                    if let room = self.dataController.room(id: key) {
                        let messages = joinedRooms[key]!.timeline.events.filter { $0.type == "m.room.message" }
                                                                        .compactMap { Message(roomEvent: $0, context: self.dataController.viewContext) }
                        room.addToMessages(NSSet(array: messages))
                    } else {
                        let room = Room(id: key, joinedRoom: joinedRooms[key]!, context: self.dataController.viewContext)
                        self.getMembers(in: room)
                        self.getName(of: room)
                        self.loadMoreMessages(in: room)
                    }
                }
                
                self.dataController.save()
                
                self.nextBatch = response.nextBatch
                self.longPoll()
            }
    }
    
    func loadMoreMessages(in room: Room) {
        guard let roomID = room.id, let previousBatch = room.previousBatch else { return }
        
        client.loadMessages(in: roomID, from: previousBatch)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                let messages = response.events?.filter { $0.type == "m.room.message" }
                                               .compactMap { Message(roomEvent: $0, context: self.dataController.viewContext) }
                
                if let messages = messages {
                    room.addToMessages(NSSet(array: messages))
                }
                
                room.previousBatch = response.endToken
                
                self.dataController.save()
            })
    }
}
