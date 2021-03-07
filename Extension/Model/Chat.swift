import Matrix
import Combine
import CoreData

public class Chat: ObservableObject {
    
    public var client = Client()
    
    public enum Status { case signedOut, syncing, idle, syncError }
    
    @Published public private(set) var status: Status = .signedOut
    
    @Published public private(set) var userID = UserDefaults.standard.string(forKey: "userID") {
        didSet { UserDefaults.standard.set(userID, forKey: "userID")}
    }
    
    private var nextBatch: String?
    
    public var container: NSPersistentContainer
    
    public init() {
        guard
            let modelURL = Bundle.main.url(forResource: "Matrix", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Unable to find Core Data Model") }
        
        container = NSPersistentContainer(name: "Matrix", managedObjectModel: managedObjectModel)
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")    // in memory for now
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error { fatalError("Core Data container error: \(error)") }
        }
        
        if client.accessToken != nil { initialSync() }
    }
    
    private func save() {
        guard container.viewContext.hasChanges else { return }
        try? container.viewContext.save()
    }
    
    private var authCancellable: AnyCancellable?
    
    public func register(username: String, password: String) {
        authCancellable = client.register(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
//                self.homeserver = response.homeServer
                self.client.accessToken = response.accessToken;  #warning("Should this be in the client?!")
            }
    }
    
    public func login(username: String, password: String) {
        authCancellable = client.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                self.userID = response.userID
//                self.homeserver = response.homeServer
                self.client.accessToken = response.accessToken;  #warning("Should this be in the client?!")
                self.initialSync()
            }
    }
    
    public func logout() {
        authCancellable = client.logout()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { success in
                guard success else { return }
                self.client.accessToken = nil
                self.status = .signedOut
            }
    }
    
    public func createRoom(name: String) {
        client.createRoom(name: name)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    public func sendMessage(body: String, room: Room) {
        guard let roomID = room.id else { return }
        
        client.sendMessage(body: body, roomID: roomID)
            .print()
            .subscribe(Subscribers.Sink { completion in } receiveValue: { _ in })
    }
    
    public func sendReaction(text: String, to event: Message, in room: Room) {
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
                    room.objectWillChange.send()
                    room.name = room.members.filter { $0.id != self.userID }.compactMap { $0.displayName ?? $0.id }.joined(separator: ", ")
                    self.save()
                }
            } receiveValue: { response in
                room.objectWillChange.send()
                room.name = response.name
                self.save()
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
                    .map { Member(event: $0, context: self.container.viewContext) }
                
                room.roomMembers = NSSet(array: members)
                self.save()
            })
    }
    
    private var syncCancellable: AnyCancellable?
    
    public func initialSync() {
        status = .syncing
        
        syncCancellable = client.sync()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                    DispatchQueue.main.async {
                        self.status = .syncError
                    }
                }
            } receiveValue: { response in
                let joinedRooms = response.rooms.joined
                let rooms: [Room] = joinedRooms.keys.map { key in
                    Room(id: key, joinedRoom: joinedRooms[key]!, context: self.container.viewContext)
                }
                
                self.save()
                
                DispatchQueue.main.async {
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
    }
    
    public func longPoll() {
        syncCancellable = client.sync(since: nextBatch, timeout: 5000)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                //
            } receiveValue: { response in
                let joinedRooms = response.rooms.joined
                joinedRooms.keys.forEach { key in
                    Room(id: key, joinedRoom: joinedRooms[key]!, context: self.container.viewContext)
                }
                
                self.save()
                
    //            rooms.forEach { room in
    //                if let index = self.rooms.firstIndex(where: { room.id == $0.id }) {
    //                    self.rooms[index].events.append(contentsOf: room.events)
    //                } else {
    //                    self.rooms.append(room)
    //                    self.getName(of: room)
    //                }
    //            }
                
                self.nextBatch = response.nextBatch
                self.longPoll()
            }
    }
    
    public func loadMoreMessages(in room: Room) {
        guard let roomID = room.id, let previousBatch = room.previousBatch else { return }
        
        client.loadMessages(in: roomID, from: previousBatch)
            .receive(on: DispatchQueue.main)
            .subscribe(Subscribers.Sink { completion in
                //
            } receiveValue: { response in
                let messages = response.events?.filter { $0.type == "m.room.message" }
                                               .compactMap { Message(roomEvent: $0, context: self.container.viewContext) }
                
                if let messages = messages {
                    room.addToRoomMessages(NSSet(array: messages))
                }
                
                room.previousBatch = response.endToken
                
                self.save()
            })
    }
}
